# frozen_string_literal: true

# Current context model for storing request-scoped data
# This provides a clean way to access user and request context throughout the application
class Current < ActiveSupport::CurrentAttributes
  # User context
  attribute :user
  attribute :organization

  # Request context
  attribute :ip_address
  attribute :user_agent
  attribute :request_id
  attribute :controller
  attribute :action
  attribute :request_path
  attribute :request_method

  # Security context
  attribute :session_id
  attribute :last_activity_at

  # Performance context
  attribute :request_start_time
  attribute :database_query_count

  # Resets the context
  def self.reset_all
    reset
  end

  # Helper methods
  def self.user_id
    user&.id
  end

  def self.user_email
    user&.email
  end

  def self.organization_id
    organization&.id || user&.organization_id
  end

  def self.organization_name
    organization&.name || user&.organization&.name
  end

  def self.request_duration
    return nil unless request_start_time
    ((Time.current - request_start_time) * 1000).round(2) # milliseconds
  end

  def self.increment_query_count
    self.database_query_count = (database_query_count || 0) + 1
  end

  def self.context_hash
    {
      user_id: user_id,
      user_email: user_email,
      organization_id: organization_id,
      organization_name: organization_name,
      ip_address: ip_address,
      user_agent: user_agent,
      request_id: request_id,
      controller: controller,
      action: action,
      request_path: request_path,
      request_method: request_method,
      session_id: session_id,
      last_activity_at: last_activity_at,
      request_start_time: request_start_time,
      database_query_count: database_query_count
    }.compact
  end

  def self.audit_context
    {
      user_id: user_id,
      organization_id: organization_id,
      ip_address: ip_address,
      user_agent: user_agent,
      request_id: request_id,
      controller: controller,
      action: action
    }.compact
  end

  def self.to_s
    context_hash.to_s
  end

  # Callbacks to set organization automatically
  def user=(user_record)
    super(user_record)
    self.organization = user_record&.organization if user_record&.respond_to?(:organization)
  end

  # Set defaults when request starts
  def self.start_request(user: nil, ip: nil, user_agent: nil, request_id: nil)
    self.user = user
    self.ip_address = ip
    self.user_agent = user_agent
    self.request_id = request_id
    self.request_start_time = Time.current
    self.database_query_count = 0
    self.last_activity_at = Time.current
  end
end
