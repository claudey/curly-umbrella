module ApplicationHelper
  include FeatureFlagHelper
  
  def format_file_size(size_in_bytes)
    return '0 B' if size_in_bytes.nil? || size_in_bytes.zero?
    
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    size = size_in_bytes.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(1)} #{units[unit_index]}"
  end
  
  # Feature flag conditional rendering helper
  def if_feature_enabled(key, user = current_user, context = {}, &block)
    yield if feature_enabled?(key, user, context)
  end
  
  def if_feature_disabled(key, user = current_user, context = {}, &block)
    yield if feature_disabled?(key, user, context)
  end
  
  # Feature flag CSS class helper
  def feature_class(key, enabled_class = '', disabled_class = '', user = current_user)
    feature_enabled?(key, user) ? enabled_class : disabled_class
  end
  
  # Feature flag data attributes for JavaScript
  def feature_data_attrs(keys, user = current_user)
    attrs = {}
    Array(keys).each do |key|
      attrs["data-feature-#{key.to_s.underscore.dasherize}"] = feature_enabled?(key, user)
    end
    attrs
  end
end
