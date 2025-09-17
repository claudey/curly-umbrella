module Cacheable
  extend ActiveSupport::Concern
  
  included do
    after_save :invalidate_cache
    after_destroy :invalidate_cache
    
    # Add scopes for popular/recent items
    scope :popular, -> { order(access_count: :desc) if column_names.include?('access_count') }
    scope :recent, -> { order(created_at: :desc) }
    
    # Virtual attributes for caching
    attr_accessor :cache_hit, :cache_source
  end
  
  class_methods do
    def cached_find(id, options = {})
      cache_service = AdvancedCachingService.instance
      cache_key = "#{model_name.param_key}:#{id}"
      
      # Try to get from cache first
      cached_data = cache_service.read(cache_key, options.merge(type: cache_type))
      
      if cached_data
        instance = new(cached_data[:attributes])
        instance.cache_hit = true
        instance.cache_source = cached_data[:source] || 'unknown'
        return instance
      end
      
      # Load from database and cache
      record = find_by(id: id)
      if record
        record.cache_data!
        record.cache_hit = false
        record.cache_source = 'database'
      end
      
      record
    end
    
    def cached_where(conditions, options = {})
      cache_key = "#{model_name.param_key}:query:#{generate_query_hash(conditions)}"
      cache_service = AdvancedCachingService.instance
      
      # Try cache first
      cached_results = cache_service.read(cache_key, options.merge(type: cache_type))
      
      if cached_results
        return cached_results.map do |cached_data|
          instance = new(cached_data[:attributes])
          instance.cache_hit = true
          instance.cache_source = 'cache'
          instance
        end
      end
      
      # Load from database and cache
      records = where(conditions).to_a
      cache_data = records.map(&:cache_data)
      
      cache_service.write(cache_key, cache_data, options.merge(type: cache_type))
      
      records.each do |record|
        record.cache_hit = false
        record.cache_source = 'database'
      end
      
      records
    end
    
    def warm_cache(limit: 100)
      cache_service = AdvancedCachingService.instance
      warmed_count = 0
      
      limit(limit).find_each do |record|
        record.cache_data!
        warmed_count += 1
      end
      
      Rails.logger.info "Warmed cache for #{warmed_count} #{model_name.human.pluralize}"
      warmed_count
    end
    
    def cache_type
      model_name.param_key.to_sym
    end
    
    private
    
    def generate_query_hash(conditions)
      Digest::SHA256.hexdigest(conditions.to_json)[0..8]
    end
  end
  
  # Instance methods
  def cache_data
    {
      attributes: cacheable_attributes,
      relationships: cacheable_relationships,
      computed_fields: cacheable_computed_fields,
      cached_at: Time.current,
      version: cache_version
    }
  end
  
  def cache_data!
    cache_service = AdvancedCachingService.instance
    cache_key = cache_key_for_instance
    
    cache_service.write(
      cache_key, 
      cache_data, 
      type: self.class.cache_type,
      ttl: cache_ttl
    )
    
    # Also cache individual field lookups
    cache_individual_fields!
    
    true
  end
  
  def invalidate_cache
    cache_service = AdvancedCachingService.instance
    
    # Invalidate main cache
    cache_service.delete(cache_key_for_instance)
    
    # Invalidate related query caches
    invalidate_related_query_caches
    
    # Invalidate individual field caches
    invalidate_individual_field_caches
    
    Rails.logger.debug "Invalidated cache for #{self.class.name}:#{id}"
  end
  
  def touch_access
    return unless respond_to?(:access_count)
    
    # Increment access count for popularity tracking
    increment(:access_count)
    update_column(:last_accessed_at, Time.current) if respond_to?(:last_accessed_at)
  end
  
  def cache_key_for_instance
    "#{self.class.model_name.param_key}:#{id}"
  end
  
  def cache_version
    # Use updated_at timestamp as version
    updated_at&.to_i || created_at&.to_i || 1
  end
  
  def cache_ttl
    # Default TTL based on model type
    case self.class.name
    when 'User'
      AdvancedCachingService::CACHE_TTLS[:user_session]
    when 'Organization'
      AdvancedCachingService::CACHE_TTLS[:organization_data]
    when 'InsuranceApplication'
      AdvancedCachingService::CACHE_TTLS[:application_data]
    when 'Quote'
      AdvancedCachingService::CACHE_TTLS[:quote_data]
    else
      1.hour
    end
  end
  
  private
  
  def cacheable_attributes
    # Exclude sensitive or frequently changing attributes
    excluded_attrs = ['password_digest', 'remember_token', 'reset_token', 'updated_at']
    attributes.except(*excluded_attrs)
  end
  
  def cacheable_relationships
    # Cache important relationship data
    relationships = {}
    
    # Add organization data for tenant-scoped models
    if respond_to?(:organization) && organization
      relationships[:organization] = {
        id: organization.id,
        name: organization.name,
        domain: organization.domain
      }
    end
    
    # Add user data for user-owned models
    if respond_to?(:user) && user
      relationships[:user] = {
        id: user.id,
        name: user.name,
        email: user.email
      }
    end
    
    relationships
  end
  
  def cacheable_computed_fields
    # Cache expensive computed fields
    computed = {}
    
    # Risk score for applications
    if respond_to?(:calculate_risk_score)
      computed[:risk_score] = calculate_risk_score
    end
    
    # Status display for various models
    if respond_to?(:status_display)
      computed[:status_display] = status_display
    end
    
    # Progress percentage for workflows
    if respond_to?(:progress_percentage)
      computed[:progress_percentage] = progress_percentage
    end
    
    computed
  end
  
  def cache_individual_fields!
    cache_service = AdvancedCachingService.instance
    
    # Cache frequently accessed individual fields
    if respond_to?(:status)
      cache_service.write(
        "#{cache_key_for_instance}:status",
        status,
        type: :field_cache,
        ttl: 30.minutes
      )
    end
    
    if respond_to?(:name)
      cache_service.write(
        "#{cache_key_for_instance}:name",
        name,
        type: :field_cache,
        ttl: 2.hours
      )
    end
  end
  
  def invalidate_related_query_caches
    cache_service = AdvancedCachingService.instance
    
    # Invalidate query caches that might include this record
    patterns = [
      "#{self.class.model_name.param_key}:query:*",
      "#{self.class.model_name.param_key}:list:*"
    ]
    
    patterns.each do |pattern|
      cache_service.invalidate_pattern(pattern)
    end
  end
  
  def invalidate_individual_field_caches
    cache_service = AdvancedCachingService.instance
    
    # Clear individual field caches
    field_keys = [
      "#{cache_key_for_instance}:status",
      "#{cache_key_for_instance}:name"
    ]
    
    field_keys.each do |key|
      cache_service.delete(key)
    end
  end
end