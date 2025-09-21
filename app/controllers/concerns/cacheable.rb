# frozen_string_literal: true

# Cacheable concern for controllers
# Provides intelligent caching capabilities for frequently accessed data
module Cacheable
  extend ActiveSupport::Concern

  included do
    before_action :set_cache_headers
    after_action :cache_frequently_accessed_data
  end

  private

  def set_cache_headers
    # Set cache headers for static-like content
    if should_cache_response?
      expires_in 30.minutes, public: false
      response.headers["Vary"] = "Accept"
    else
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"
    end
  end

  def cache_frequently_accessed_data
    return unless user_signed_in? && ActsAsTenant.current_tenant

    # Cache organization data in background
    CacheOrganizationDataJob.perform_later(ActsAsTenant.current_tenant.id)
  end

  def should_cache_response?
    # Cache static pages and dashboard data
    %w[home dashboard].include?(controller_name) ||
    (action_name == "index" && %w[documents quotes applications].include?(controller_name))
  end

  # Cached dashboard data
  def cached_dashboard_stats
    return @cached_dashboard_stats if defined?(@cached_dashboard_stats)

    @cached_dashboard_stats = CachingService.fetch(
      "dashboard:#{ActsAsTenant.current_tenant.id}:stats",
      expires_in: :short
    ) do
      calculate_dashboard_stats
    end
  end

  def cached_organization_metrics
    return @cached_organization_metrics if defined?(@cached_organization_metrics)

    @cached_organization_metrics = CachingService.fetch(
      "org:#{ActsAsTenant.current_tenant.id}:metrics",
      expires_in: :medium
    ) do
      calculate_organization_metrics
    end
  end

  def cached_user_permissions
    return @cached_user_permissions if defined?(@cached_user_permissions)

    @cached_user_permissions = CachingService.fetch(
      "user:#{current_user.id}:permissions",
      expires_in: :long
    ) do
      current_user.permissions_cache_data
    end
  end

  def cached_recent_activities
    return @cached_recent_activities if defined?(@cached_recent_activities)

    @cached_recent_activities = CachingService.fetch(
      "activities:#{ActsAsTenant.current_tenant.id}:recent",
      expires_in: :short
    ) do
      fetch_recent_activities
    end
  end

  # Cache invalidation helpers
  def invalidate_dashboard_cache
    CachingService.delete_matched("dashboard:#{ActsAsTenant.current_tenant.id}:*")
  end

  def invalidate_organization_cache
    CachingService.invalidate_organization_cache(ActsAsTenant.current_tenant.id)
  end

  def invalidate_user_cache
    CachingService.invalidate_user_cache(current_user.id)
  end

  # Helper methods to be implemented by including controllers
  def calculate_dashboard_stats
    # Override in including controllers
    {}
  end

  def calculate_organization_metrics
    # Override in including controllers
    {}
  end

  def fetch_recent_activities
    # Override in including controllers
    []
  end
end
