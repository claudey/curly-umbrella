class FeatureFlagService
  include Singleton
  
  # Cache feature flags for performance
  CACHE_EXPIRY = 5.minutes
  
  def initialize
    @cache = {}
    @cache_timestamps = {}
  end
  
  # Main method to check if a feature is enabled
  def enabled?(key, user = nil, context = {})
    flag = get_feature_flag(key)
    return false unless flag
    
    # If no user provided, just check if flag is globally enabled
    return flag.enabled? if user.nil?
    
    # Check if enabled for specific user with context
    flag.enabled_for?(user, context)
  end
  
  # Check if feature is enabled with fallback to default
  def enabled_with_default?(key, default = false, user = nil, context = {})
    flag = get_feature_flag(key)
    return default unless flag
    
    return flag.enabled? if user.nil?
    flag.enabled_for?(user, context)
  end
  
  # Get feature flag percentage for gradual rollouts
  def rollout_percentage(key)
    flag = get_feature_flag(key)
    return 0 unless flag
    flag.enabled_percentage
  end
  
  # Create or update a feature flag
  def create_or_update_flag(key, attributes = {})
    clear_cache_for_key(key)
    FeatureFlag.create_or_update_flag(key, attributes)
  end
  
  # Toggle a feature flag
  def toggle_flag(key)
    flag = get_feature_flag(key)
    return false unless flag
    
    clear_cache_for_key(key)
    flag.toggle!
    flag.enabled?
  end
  
  # Enable a flag for specific percentage of users
  def set_percentage_rollout(key, percentage, user_groups = [])
    clear_cache_for_key(key)
    create_or_update_flag(key, {
      enabled: true,
      percentage: percentage,
      user_groups: user_groups
    })
  end
  
  # Enable flag for specific user groups
  def enable_for_groups(key, groups)
    clear_cache_for_key(key)
    create_or_update_flag(key, {
      enabled: true,
      user_groups: groups
    })
  end
  
  # Enable flag with custom conditions
  def enable_with_conditions(key, conditions)
    clear_cache_for_key(key)
    create_or_update_flag(key, {
      enabled: true,
      conditions: conditions
    })
  end
  
  # Get all feature flags for administration
  def all_flags
    FeatureFlag.includes(:created_by, :updated_by).order(:name)
  end
  
  # Get flags grouped by status
  def flags_by_status
    {
      enabled: FeatureFlag.enabled.count,
      disabled: FeatureFlag.disabled.count,
      percentage_rollout: FeatureFlag.where.not(percentage: nil).count,
      group_based: FeatureFlag.where.not(user_groups: []).count
    }
  end
  
  # Bulk operations for deployment
  def enable_flags(keys)
    return if keys.empty?
    
    keys.each { |key| clear_cache_for_key(key) }
    FeatureFlag.where(key: keys).update_all(enabled: true, updated_at: Time.current)
  end
  
  def disable_flags(keys)
    return if keys.empty?
    
    keys.each { |key| clear_cache_for_key(key) }
    FeatureFlag.where(key: keys).update_all(enabled: false, updated_at: Time.current)
  end
  
  # Export/import for deployment coordination
  def export_flags
    FeatureFlag.all.map do |flag|
      {
        key: flag.key,
        name: flag.name,
        description: flag.description,
        enabled: flag.enabled,
        percentage: flag.percentage,
        user_groups: flag.user_groups,
        conditions: flag.conditions,
        metadata: flag.metadata
      }
    end
  end
  
  def import_flags(flags_data)
    flags_data.each do |flag_data|
      create_or_update_flag(flag_data[:key], flag_data.except(:key))
    end
  end
  
  # Clear all caches
  def clear_cache
    @cache.clear
    @cache_timestamps.clear
  end
  
  # Health check for feature flag system
  def health_check
    {
      total_flags: FeatureFlag.count,
      enabled_flags: FeatureFlag.enabled.count,
      cache_size: @cache.size,
      last_updated: FeatureFlag.maximum(:updated_at),
      system_healthy: FeatureFlag.connection.active?
    }
  end
  
  private
  
  def get_feature_flag(key)
    return @cache[key] if cache_valid?(key)
    
    flag = FeatureFlag.find_by(key: key)
    cache_flag(key, flag) if flag
    flag
  end
  
  def cache_valid?(key)
    return false unless @cache.key?(key)
    return false unless @cache_timestamps.key?(key)
    
    Time.current - @cache_timestamps[key] < CACHE_EXPIRY
  end
  
  def cache_flag(key, flag)
    @cache[key] = flag
    @cache_timestamps[key] = Time.current
  end
  
  def clear_cache_for_key(key)
    @cache.delete(key)
    @cache_timestamps.delete(key)
  end
end

