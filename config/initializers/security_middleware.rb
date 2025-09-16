# frozen_string_literal: true

# SecurityMiddleware temporarily disabled due to Rails 8 frozen middleware stack issue
# TODO: Implement security features using alternative approaches:
# - Before/after filters for rate limiting and IP blocking
# - Application-level security controls
# - Background job-based monitoring

# Rails.application.config.after_initialize do
#   # Only add if not already present (avoid duplicates)
#   unless Rails.application.middleware.middlewares.any? { |m| m.is_a?(Class) && m.name == 'SecurityMiddleware' }
#     Rails.application.middleware.use SecurityMiddleware
#   end
# end