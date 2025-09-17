# BrokerSync Technical Documentation

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Technology Stack](#technology-stack)
3. [Database Schema](#database-schema)
4. [API Documentation](#api-documentation)
5. [Security Architecture](#security-architecture)
6. [Deployment Guide](#deployment-guide)
7. [Development Setup](#development-setup)
8. [Performance Optimization](#performance-optimization)
9. [Monitoring & Observability](#monitoring--observability)
10. [Troubleshooting](#troubleshooting)

---

## System Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │    │   Mobile App    │    │  Third-party    │
│                 │    │                 │    │  Integrations   │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │     Load Balancer         │
                    │     (nginx/HAProxy)       │
                    └─────────────┬─────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │   Rails Application       │
                    │   - Controllers           │
                    │   - Services              │
                    │   - Background Jobs       │
                    └─────────────┬─────────────┘
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
    ┌───────────┴───────────┐    │    ┌───────────┴───────────┐
    │    PostgreSQL         │    │    │      Redis            │
    │    - Primary DB       │    │    │    - Cache            │
    │    - Read Replicas    │    │    │    - Sessions         │
    └───────────────────────┘    │    │    - Job Queue        │
                                 │    └───────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │   External Services       │
                    │   - Cloudflare R2        │
                    │   - New Relic            │
                    │   - Email/SMS            │
                    └───────────────────────────┘
```

### Application Architecture

**Multi-Tenant SaaS Architecture:**
- Tenant isolation using `acts_as_tenant` gem
- Shared database with tenant-scoped queries
- Organization-level data segregation
- Cross-tenant access prevention

**Modular Service Architecture:**
- Business logic encapsulated in service objects
- Clear separation of concerns
- Testable and maintainable code structure
- Dependency injection patterns

**Event-Driven Components:**
- Background job processing with Solid Queue
- Real-time notifications
- Audit logging for all operations
- Webhook integration for external systems

---

## Technology Stack

### Core Framework
- **Ruby 3.4.1** - Programming language
- **Rails 8.0.2** - Web application framework
- **PostgreSQL 15+** - Primary database
- **Redis 7+** - Caching and session storage

### Frontend
- **Turbo/Stimulus** - Modern Rails frontend
- **Tailwind CSS 4.3** - Utility-first CSS framework
- **DaisyUI** - Component library
- **Lexxy** - Rich text editing

### Infrastructure
- **Cloudflare R2** - File storage
- **New Relic** - Application performance monitoring
- **Brevo** - Email delivery service
- **Twilio** - SMS and communication

### Development & Testing
- **RSpec** - Testing framework
- **FactoryBot** - Test data generation
- **Capybara** - Integration testing
- **Brakeman** - Security scanning

### Background Processing
- **Solid Queue** - Job processing
- **Solid Cache** - Caching layer
- **Solid Cable** - WebSocket connections

---

## Database Schema

### Core Tables

**Organizations**
```sql
Table: organizations
- id (bigint, primary key)
- name (varchar, not null)
- subscription_tier (varchar)
- status (varchar, default: 'active')
- tenant_id (bigint, unique)
- created_at/updated_at (timestamp)
```

**Users**
```sql
Table: users
- id (bigint, primary key)
- organization_id (bigint, foreign key)
- email (varchar, unique)
- first_name/last_name (varchar)
- role (varchar)
- mfa_enabled (boolean, default: false)
- mfa_secret (varchar, encrypted)
- current_session_token (varchar)
- last_sign_in_at (timestamp)
- created_at/updated_at (timestamp)
```

**Insurance Applications**
```sql
Table: insurance_applications
- id (bigint, primary key)
- organization_id (bigint, foreign key)
- user_id (bigint, foreign key)
- client_id (bigint, foreign key)
- application_number (varchar, unique)
- application_type (varchar)
- status (varchar, default: 'draft')
- [personal information fields]
- [vehicle/property specific fields]
- submitted_at/approved_at/rejected_at (timestamp)
- created_at/updated_at (timestamp)
- discarded_at (timestamp)
```

**Quotes**
```sql
Table: quotes
- id (bigint, primary key)
- organization_id (bigint, foreign key)
- insurance_application_id (bigint, foreign key)
- insurance_company_id (bigint, foreign key)
- quote_number (varchar, unique)
- status (varchar, default: 'pending')
- base_premium/taxes/fees/total_premium (decimal)
- coverage_limits (json)
- quoted_at/expires_at (timestamp)
- created_at/updated_at (timestamp)
- discarded_at (timestamp)
```

### Indexing Strategy

**Performance Indexes:**
```sql
-- Tenant isolation
CREATE INDEX idx_insurance_applications_organization_id 
ON insurance_applications(organization_id);

-- Status queries
CREATE INDEX idx_insurance_applications_status_org 
ON insurance_applications(organization_id, status);

-- Time-based queries
CREATE INDEX idx_quotes_created_at_org 
ON quotes(organization_id, created_at);

-- Search indexes
CREATE INDEX idx_insurance_applications_search 
ON insurance_applications USING gin(to_tsvector('english', 
   first_name || ' ' || last_name || ' ' || email));
```

**Unique Constraints:**
```sql
-- Application numbers unique per organization
ALTER TABLE insurance_applications 
ADD CONSTRAINT unique_application_number_per_org 
UNIQUE (organization_id, application_number);

-- Quote numbers unique per organization
ALTER TABLE quotes 
ADD CONSTRAINT unique_quote_number_per_org 
UNIQUE (organization_id, quote_number);
```

---

## API Documentation

### Authentication

**API Key Authentication:**
```http
Authorization: Bearer your_api_key_here
Content-Type: application/json
```

**JWT Token Authentication:**
```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

### API Endpoints

**Applications API:**
```http
GET    /api/v1/applications           # List applications
POST   /api/v1/applications           # Create application
GET    /api/v1/applications/:id       # Get application
PUT    /api/v1/applications/:id       # Update application
DELETE /api/v1/applications/:id       # Delete application
POST   /api/v1/applications/:id/submit # Submit for review
```

**Quotes API:**
```http
GET    /api/v1/quotes                 # List quotes
POST   /api/v1/quotes                 # Create quote
GET    /api/v1/quotes/:id             # Get quote
PUT    /api/v1/quotes/:id             # Update quote
POST   /api/v1/quotes/:id/accept      # Accept quote
```

### Request/Response Format

**Standard Response Format:**
```json
{
  "success": true,
  "data": {
    "application": {
      "id": 123,
      "application_number": "APP000001",
      "status": "submitted",
      "created_at": "2025-01-16T10:00:00Z"
    }
  },
  "meta": {
    "total": 1,
    "page": 1,
    "per_page": 20
  }
}
```

**Error Response Format:**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": {
      "first_name": ["can't be blank"],
      "email": ["is not a valid email"]
    }
  }
}
```

### Rate Limiting

**Rate Limit Headers:**
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642334400
Retry-After: 60
```

**Rate Limit Tiers:**
- **Basic**: 100 requests/hour
- **Professional**: 1,000 requests/hour  
- **Enterprise**: 10,000 requests/hour

---

## Security Architecture

### Authentication & Authorization

**Multi-Factor Authentication:**
- TOTP-based MFA using ROTP gem
- Backup codes for recovery
- MFA enforcement policies
- Session management

**Role-Based Access Control:**
```ruby
# User roles and permissions
ROLES = {
  admin: [:manage_all],
  executive: [:view_analytics, :view_applications],
  agent: [:create_applications, :manage_quotes]
}
```

**Session Security:**
- Secure session tokens
- Session timeout policies
- Multiple session management
- Device tracking

### Data Protection

**Encryption at Rest:**
- Database field encryption using Rails 8 encryption
- Sensitive PII data encrypted with separate keys
- Document encryption in storage
- Backup encryption

**Encryption in Transit:**
- TLS 1.3 for all connections
- Certificate pinning
- HSTS headers
- Secure cookie flags

**Data Masking:**
```ruby
# PII masking for logs and exports
def mask_sensitive_data(value)
  return nil if value.nil?
  value[0..1] + '*' * (value.length - 4) + value[-2..-1]
end
```

### Security Headers

```ruby
# config/application.rb
config.force_ssl = true
config.ssl_options = {
  hsts: { expires: 1.year, subdomains: true }
}

# Security headers
response.headers['X-Frame-Options'] = 'DENY'
response.headers['X-Content-Type-Options'] = 'nosniff'
response.headers['X-XSS-Protection'] = '1; mode=block'
response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
```

---

## Deployment Guide

### Prerequisites

**System Requirements:**
- Ruby 3.4.1+
- PostgreSQL 15+
- Redis 7+
- Node.js 18+ (for asset compilation)
- 4GB+ RAM (production)
- 2+ CPU cores (production)

**Environment Variables:**
```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost/brokersync_production

# Rails
RAILS_ENV=production
SECRET_KEY_BASE=your_secret_key_here

# External Services
CLOUDFLARE_R2_ACCESS_KEY_ID=your_access_key
CLOUDFLARE_R2_SECRET_ACCESS_KEY=your_secret_key
NEW_RELIC_LICENSE_KEY=your_license_key

# Email/SMS
BREVO_API_KEY=your_brevo_key
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token
```

### Docker Deployment

**Dockerfile:**
```dockerfile
FROM ruby:3.4.1-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
  build-essential \
  postgresql-client \
  nodejs \
  npm \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# Install node modules
COPY package.json package-lock.json ./
RUN npm install

# Copy application
COPY . .

# Precompile assets
RUN RAILS_ENV=production rails assets:precompile

# Expose port
EXPOSE 3000

# Start application
CMD ["rails", "server", "-b", "0.0.0.0"]
```

**docker-compose.yml:**
```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/brokersync_production
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: brokersync_production
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    
  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

### Production Deployment

**1. Server Setup:**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Ruby via rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
rbenv install 3.4.1
rbenv global 3.4.1

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib

# Install Redis
sudo apt install redis-server

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs
```

**2. Application Deployment:**
```bash
# Clone repository
git clone https://github.com/your-org/brokersync.git
cd brokersync

# Install dependencies
bundle install --deployment --without development test
npm install

# Setup database
RAILS_ENV=production rails db:create
RAILS_ENV=production rails db:migrate

# Precompile assets
RAILS_ENV=production rails assets:precompile

# Start services
sudo systemctl enable redis-server
sudo systemctl start redis-server
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

**3. Process Management (systemd):**
```ini
# /etc/systemd/system/brokersync.service
[Unit]
Description=BrokerSync Rails Application
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/brokersync
ExecStart=/home/deploy/.rbenv/shims/bundle exec rails server -e production
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Load Balancer Configuration (nginx)

```nginx
upstream brokersync {
  server 127.0.0.1:3000;
  server 127.0.0.1:3001;
}

server {
  listen 80;
  server_name yourdomain.com;
  return 301 https://$server_name$request_uri;
}

server {
  listen 443 ssl http2;
  server_name yourdomain.com;

  ssl_certificate /path/to/certificate.crt;
  ssl_certificate_key /path/to/private.key;
  
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
  
  client_max_body_size 100M;
  
  location / {
    proxy_pass http://brokersync;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
  
  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }
}
```

---

## Development Setup

### Local Environment Setup

**1. Prerequisites:**
```bash
# Install Ruby via rbenv
rbenv install 3.4.1
rbenv local 3.4.1

# Install PostgreSQL (macOS)
brew install postgresql
brew services start postgresql

# Install Redis (macOS)
brew install redis
brew services start redis

# Install Node.js
brew install node
```

**2. Application Setup:**
```bash
# Clone and setup
git clone https://github.com/your-org/brokersync.git
cd brokersync

# Install dependencies
bundle install
npm install

# Setup database
rails db:create
rails db:migrate
rails db:seed

# Start development server
bin/dev
```

**3. Environment Configuration:**
```bash
# .env.development
DATABASE_URL=postgresql://localhost/brokersync_development
REDIS_URL=redis://localhost:6379/0
SECRET_KEY_BASE=development_secret_key

# External service keys (optional for development)
CLOUDFLARE_R2_ACCESS_KEY_ID=your_dev_key
NEW_RELIC_LICENSE_KEY=your_dev_key
```

### Development Tools

**Code Quality:**
```bash
# Run linting
bundle exec rubocop

# Run security scan
bundle exec brakeman

# Run tests
bundle exec rspec
bin/test --all

# Performance profiling
bundle exec rails console
require 'memory_profiler'
MemoryProfiler.report { your_code }.pretty_print
```

**Database Tools:**
```bash
# Database console
rails db

# Reset database
rails db:drop db:create db:migrate db:seed

# Generate migration
rails generate migration AddFieldToModel field:type

# Check migration status
rails db:migrate:status
```

---

## Performance Optimization

### Database Optimization

**Query Optimization:**
```ruby
# Use includes to avoid N+1 queries
applications = InsuranceApplication.includes(:quotes, :user, :client)

# Use select to limit columns
applications = InsuranceApplication.select(:id, :application_number, :status)

# Use find_each for large datasets
InsuranceApplication.find_each(batch_size: 1000) do |application|
  # Process application
end
```

**Indexing Strategy:**
```sql
-- Composite indexes for common queries
CREATE INDEX idx_applications_org_status_created 
ON insurance_applications(organization_id, status, created_at);

-- Partial indexes for filtered queries
CREATE INDEX idx_quotes_active 
ON quotes(organization_id, created_at) 
WHERE status IN ('pending', 'approved');
```

**Connection Pooling:**
```ruby
# config/database.yml
production:
  adapter: postgresql
  pool: 25
  checkout_timeout: 5
  reaping_frequency: 10
  dead_connection_timeout: 5
```

### Caching Strategy

**Application-Level Caching:**
```ruby
# Fragment caching
<% cache ["applications_list", current_organization, @applications.maximum(:updated_at)] do %>
  <%= render @applications %>
<% end %>

# Method caching
def expensive_calculation
  Rails.cache.fetch("expensive_calc_#{id}", expires_in: 1.hour) do
    # Expensive operation
  end
end
```

**Redis Configuration:**
```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV['REDIS_URL'],
  pool_size: 10,
  pool_timeout: 5,
  expire_in: 1.hour
}
```

### Background Job Optimization

**Job Performance:**
```ruby
class ApplicationProcessingJob < ApplicationJob
  queue_as :high_priority
  
  # Retry configuration
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(application_id)
    # Efficient processing
    Application.find(application_id).process!
  end
end
```

**Queue Management:**
```ruby
# config/environments/production.rb
config.active_job.queue_adapter = :solid_queue

# Queue priorities
Solid::Queue.configure do |config|
  config.queues = {
    high_priority: 10,
    default: 5,
    low_priority: 1
  }
end
```

---

## Monitoring & Observability

### Application Monitoring

**New Relic Configuration:**
```ruby
# config/newrelic.yml
production:
  license_key: <%= ENV['NEW_RELIC_LICENSE_KEY'] %>
  app_name: BrokerSync Production
  monitor_mode: true
  log_level: info
  
  application_logging:
    enabled: true
    forwarding:
      enabled: true
    metrics:
      enabled: true
```

**Custom Metrics:**
```ruby
# Record business metrics
NewRelic::Agent.record_metric('Applications/Processed', processed_count)
NewRelic::Agent.record_metric('Quotes/Conversion_Rate', conversion_rate)

# Custom events
NewRelic::Agent.record_custom_event('ApplicationSubmitted', {
  organization_id: org.id,
  application_type: app.application_type,
  processing_time: time_taken
})
```

### Logging Strategy

**Structured Logging:**
```ruby
# config/environments/production.rb
config.log_formatter = proc do |severity, datetime, progname, msg|
  {
    timestamp: datetime.iso8601,
    level: severity,
    message: msg,
    organization_id: Current.organization&.id,
    user_id: Current.user&.id
  }.to_json + "\n"
end
```

**Security Logging:**
```ruby
class SecurityLogger
  def self.log_event(event_type, details = {})
    Rails.logger.warn({
      event: 'security_event',
      type: event_type,
      details: details,
      timestamp: Time.current.iso8601,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    }.to_json)
  end
end
```

### Health Checks

**Application Health:**
```ruby
# config/routes.rb
get '/health', to: 'health#check'

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def check
    checks = {
      database: database_healthy?,
      redis: redis_healthy?,
      external_services: external_services_healthy?
    }
    
    status = checks.values.all? ? :ok : :service_unavailable
    render json: { status: status, checks: checks }, status: status
  end
  
  private
  
  def database_healthy?
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue => e
    false
  end
  
  def redis_healthy?
    Rails.cache.redis.ping == 'PONG'
  rescue => e
    false
  end
end
```

---

## Troubleshooting

### Common Issues

**Database Connection Issues:**
```bash
# Check database status
sudo systemctl status postgresql

# Check connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"

# Reset connections
sudo systemctl restart postgresql
```

**Memory Issues:**
```bash
# Check memory usage
free -h
ps aux --sort=-%mem | head

# Ruby memory profiling
require 'memory_profiler'
report = MemoryProfiler.report do
  # Your code here
end
report.pretty_print
```

**Performance Issues:**
```bash
# Check slow queries
sudo -u postgres psql brokersync_production -c "
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;"

# Rails performance console
rails console
Benchmark.measure { YourCode.perform }
```

### Debugging Tools

**Rails Console Debugging:**
```ruby
# Production console (read-only)
rails console -e production --sandbox

# Debug specific issues
application = InsuranceApplication.find(123)
application.debug_processing_state

# Check associations
application.association(:quotes).loaded?
```

**Log Analysis:**
```bash
# Tail logs
tail -f log/production.log

# Filter specific events
grep "ERROR" log/production.log | tail -20

# Analyze performance
grep "Completed.*in.*ms" log/production.log | \
  awk '{print $(NF-1)}' | sort -n | tail -10
```

### Emergency Procedures

**Database Recovery:**
```bash
# Create backup
pg_dump -U postgres brokersync_production > backup.sql

# Restore from backup
psql -U postgres brokersync_production < backup.sql

# Point-in-time recovery (if WAL enabled)
pg_basebackup -D /backup/location -Ft -z -P
```

**Application Recovery:**
```bash
# Restart application
sudo systemctl restart brokersync

# Clear cache
rails runner "Rails.cache.clear"

# Reset job queues
rails runner "Solid::Queue::Job.where(status: 'running').update_all(status: 'pending')"
```

---

*This technical documentation is maintained by the development team and updated with each major release.*