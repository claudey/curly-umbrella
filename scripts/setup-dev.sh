#!/bin/bash

# BrokerSync Development Setup Script
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🛠️  Setting up BrokerSync development environment${NC}"

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

# Check if Ruby is installed
check_ruby() {
    if command -v ruby &> /dev/null; then
        ruby_version=$(ruby -v | cut -d' ' -f2)
        echo "Ruby $ruby_version is installed"
        print_status "Ruby check passed"
    else
        print_error "Ruby is not installed. Please install Ruby 3.4.1"
        exit 1
    fi
}

# Check if Bundler is installed
check_bundler() {
    if command -v bundle &> /dev/null; then
        print_status "Bundler is installed"
    else
        echo "Installing Bundler..."
        gem install bundler
        print_status "Bundler installed"
    fi
}

# Install gems
install_gems() {
    echo "Installing Ruby gems..."
    bundle install
    print_status "Gems installed"
}

# Check if Node.js is installed
check_node() {
    if command -v node &> /dev/null; then
        node_version=$(node -v)
        echo "Node.js $node_version is installed"
        print_status "Node.js check passed"
    else
        print_warning "Node.js is not installed. Some features may not work."
    fi
}

# Setup database
setup_database() {
    echo "Setting up database..."
    
    # Check if PostgreSQL is running
    if ! bundle exec rails runner "ActiveRecord::Base.connection" &> /dev/null; then
        print_warning "PostgreSQL may not be running. Starting with Docker..."
        docker-compose up -d db redis
        sleep 10
    fi
    
    # Create and migrate database
    bundle exec rails db:create
    bundle exec rails db:migrate
    
    # Seed database
    bundle exec rails db:seed
    
    print_status "Database setup completed"
}

# Create master key if it doesn't exist
setup_credentials() {
    if [ ! -f "config/master.key" ]; then
        echo "Creating master key..."
        bundle exec rails credentials:edit
        print_status "Master key created"
    else
        print_status "Master key already exists"
    fi
}

# Setup environment variables
setup_env() {
    if [ ! -f ".env" ]; then
        echo "Creating .env file..."
        cat > .env << EOF
# Development environment variables
RAILS_ENV=development
DATABASE_URL=postgresql://postgres:password@localhost:5432/brokersync_development
REDIS_URL=redis://localhost:6379/0

# API Keys (development)
NEW_RELIC_LICENSE_KEY=your_newrelic_key_here
SENDGRID_API_KEY=your_sendgrid_key_here

# Security
SECRET_KEY_BASE=\$(bundle exec rails secret)
JWT_SECRET=\$(bundle exec rails secret)

# File storage
STORAGE_BUCKET=brokersync-dev-storage
EOF
        print_status ".env file created"
    else
        print_status ".env file already exists"
    fi
}

# Install git hooks
setup_git_hooks() {
    if [ -d ".git" ]; then
        echo "Setting up git hooks..."
        
        # Pre-commit hook
        cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Running pre-commit checks..."

# Run RuboCop
if ! bundle exec rubocop --format=quiet; then
    echo "RuboCop failed. Please fix the issues and try again."
    exit 1
fi

# Run tests
if ! bundle exec rails test:units; then
    echo "Unit tests failed. Please fix the issues and try again."
    exit 1
fi

echo "Pre-commit checks passed!"
EOF
        
        chmod +x .git/hooks/pre-commit
        print_status "Git hooks installed"
    fi
}

# Verify setup
verify_setup() {
    echo "Verifying setup..."
    
    # Test database connection
    if bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').to_a" &> /dev/null; then
        print_status "Database connection test passed"
    else
        print_error "Database connection test failed"
        exit 1
    fi
    
    # Test Rails server startup
    echo "Testing Rails server startup..."
    timeout 10s bundle exec rails server -p 3001 -d &> /dev/null || true
    sleep 2
    
    if curl -f http://localhost:3001/health &> /dev/null; then
        print_status "Rails server test passed"
        # Stop the test server
        pkill -f "rails server -p 3001" || true
    else
        print_warning "Rails server test failed - this may be normal"
        # Stop any hanging processes
        pkill -f "rails server -p 3001" || true
    fi
    
    print_status "Setup verification completed"
}

# Main setup function
main() {
    echo "🚀 Starting development setup..."
    
    check_ruby
    check_bundler
    check_node
    install_gems
    setup_credentials
    setup_env
    setup_database
    setup_git_hooks
    verify_setup
    
    echo -e "${GREEN}🎉 Development setup completed successfully!${NC}"
    echo -e "${GREEN}💡 Run 'bin/dev' to start the development server${NC}"
    echo -e "${GREEN}💡 Run 'bundle exec rails console' to access the Rails console${NC}"
    echo -e "${GREEN}💡 Run 'bundle exec rails test' to run the test suite${NC}"
}

# Run main function
main