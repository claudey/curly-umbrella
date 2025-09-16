source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  
  # Testing framework
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.5"
  gem "shoulda-matchers", "~> 6.4"
  gem "database_cleaner-active_record", "~> 2.2"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  # N+1 query detection [https://github.com/flyerhzm/bullet]
  gem "bullet"
end

gem "tailwindcss-rails", "~> 4.3"

gem "lexxy", "~> 0.1.6.beta"

gem "aws-sdk-s3", "~> 1.199"

gem "acts_as_tenant", "~> 1.0"

gem "devise", "~> 4.9"
gem "discard", "~> 1.3"
gem "phosphor_icons", "~> 0.3"
gem "view_component", "~> 3.0"

# PDF generation
gem "wicked_pdf", "~> 2.8"
gem "wkhtmltopdf-binary", "~> 0.12"

# Email delivery
gem "brevo", "~> 2.0"
gem "enum_help", "~> 0.0.17"

# Multi-factor authentication
gem "rotp", "~> 6.3"
gem "rqrcode", "~> 2.2"

# SMS and communication
gem "twilio-ruby", "~> 7.3"
gem "httparty", "~> 0.22"

# Audit logging (using audited instead of paper_trail for Rails 8 compatibility)
gem "audited", "~> 5.8"

# Pagination
gem "kaminari", "~> 1.2"

# Performance optimization
gem "redis", "~> 5.0"

# Application Performance Monitoring
gem "newrelic_rpm", "~> 9.19"

# API Development
gem "jwt", "~> 2.9"
gem "rack-cors", "~> 2.0"
gem "rack-attack", "~> 6.7"
gem "grape", "~> 2.1"
gem "grape-entity", "~> 1.0"
gem "grape-swagger", "~> 2.1"
gem "grape-swagger-rails", "~> 0.4"
