# frozen_string_literal: true

Audited.config do |config|
  # Store the current user in audits
  config.current_user_method = :current_user

  # Track changes to these attributes by default
  config.max_audits = 100 # Limit audits per record to prevent bloat
end
