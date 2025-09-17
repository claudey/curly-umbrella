#!/bin/bash

# BrokerSync Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-production}
DOCKER_COMPOSE_FILE="docker-compose.yml"
BACKUP_DIR="./backups"

echo -e "${GREEN}🚀 Starting BrokerSync deployment for ${ENVIRONMENT} environment${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        print_error "docker-compose.yml not found"
        exit 1
    fi
    
    if [ ! -f "config/master.key" ]; then
        print_error "config/master.key not found. This is required for production deployment."
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Create backup
create_backup() {
    if [ "$ENVIRONMENT" = "production" ]; then
        echo "Creating backup before deployment..."
        mkdir -p "$BACKUP_DIR"
        
        # Backup database
        docker-compose exec -T db pg_dump -U postgres brokersync_production > "$BACKUP_DIR/db_backup_$(date +%Y%m%d_%H%M%S).sql"
        
        # Backup uploaded files
        docker-compose exec -T app tar -czf - /rails/storage > "$BACKUP_DIR/storage_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        
        print_status "Backup created successfully"
    fi
}

# Pull latest images
pull_images() {
    echo "Pulling latest Docker images..."
    docker-compose pull
    print_status "Images pulled successfully"
}

# Build application
build_application() {
    echo "Building application..."
    docker-compose build --no-cache app
    print_status "Application built successfully"
}

# Run migrations
run_migrations() {
    echo "Running database migrations..."
    docker-compose exec -T app bundle exec rails db:migrate
    print_status "Migrations completed successfully"
}

# Deploy services
deploy_services() {
    echo "Deploying services..."
    
    # Stop services gracefully
    docker-compose down --timeout 30
    
    # Start services
    docker-compose up -d
    
    # Wait for services to be healthy
    echo "Waiting for services to be healthy..."
    sleep 30
    
    # Check health
    for service in app db redis nginx; do
        if docker-compose ps $service | grep -q "Up (healthy)"; then
            print_status "$service is healthy"
        else
            print_warning "$service may not be healthy yet"
        fi
    done
    
    print_status "Services deployed successfully"
}

# Run post-deployment tasks
post_deployment() {
    echo "Running post-deployment tasks..."
    
    # Clear cache
    docker-compose exec -T app bundle exec rails cache:clear
    
    # Warm up application
    docker-compose exec -T app curl -f http://localhost/health
    
    # Run any pending jobs
    docker-compose exec -T app bundle exec rails runner "Sidekiq::Queue.new.clear"
    
    print_status "Post-deployment tasks completed"
}

# Verify deployment
verify_deployment() {
    echo "Verifying deployment..."
    
    # Check application health
    if curl -f http://localhost/health > /dev/null 2>&1; then
        print_status "Application health check passed"
    else
        print_error "Application health check failed"
        exit 1
    fi
    
    # Check database connectivity
    if docker-compose exec -T app bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" > /dev/null 2>&1; then
        print_status "Database connectivity check passed"
    else
        print_error "Database connectivity check failed"
        exit 1
    fi
    
    print_status "Deployment verification completed"
}

# Rollback function
rollback() {
    print_warning "Rolling back deployment..."
    
    # Stop current services
    docker-compose down
    
    # Restore from backup if available
    if [ -d "$BACKUP_DIR" ]; then
        latest_db_backup=$(ls -t "$BACKUP_DIR"/db_backup_*.sql | head -1)
        latest_storage_backup=$(ls -t "$BACKUP_DIR"/storage_backup_*.tar.gz | head -1)
        
        if [ -f "$latest_db_backup" ]; then
            print_warning "Restoring database from $latest_db_backup"
            docker-compose up -d db
            sleep 10
            docker-compose exec -T db psql -U postgres -c "DROP DATABASE IF EXISTS brokersync_production;"
            docker-compose exec -T db psql -U postgres -c "CREATE DATABASE brokersync_production;"
            docker-compose exec -T db psql -U postgres brokersync_production < "$latest_db_backup"
        fi
        
        if [ -f "$latest_storage_backup" ]; then
            print_warning "Restoring storage from $latest_storage_backup"
            docker-compose exec -T app tar -xzf - -C / < "$latest_storage_backup"
        fi
    fi
    
    print_status "Rollback completed"
}

# Trap errors and rollback
trap 'rollback' ERR

# Main deployment flow
main() {
    check_prerequisites
    
    if [ "$ENVIRONMENT" = "production" ]; then
        create_backup
    fi
    
    pull_images
    build_application
    deploy_services
    run_migrations
    post_deployment
    verify_deployment
    
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo -e "${GREEN}📊 Application is running at: http://localhost${NC}"
    echo -e "${GREEN}📈 Nginx proxy is running at: http://localhost:80 and https://localhost:443${NC}"
}

# Run main function
main