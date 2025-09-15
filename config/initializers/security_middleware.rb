# frozen_string_literal: true

# Temporarily commented out due to Rails 8 middleware stack freezing issue
# Rails.application.config.to_prepare do
#   Rails.application.config.middleware.insert_before Rack::Runtime, SecurityMiddleware
# end