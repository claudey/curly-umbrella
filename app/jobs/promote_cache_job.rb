class PromoteCacheJob < ApplicationJob
  queue_as :caching
  
  def perform(key, value, target_layers)
    cache_service = AdvancedCachingService.instance
    
    target_layers.each do |layer|
      begin
        cache_instance = cache_service.send(:get_cache_instance, layer)
        next unless cache_instance
        
        normalized_key = cache_service.send(:normalize_key, key, layer)
        cache_instance.write(normalized_key, value, expires_in: 1.hour)
        
        Rails.logger.debug "Promoted cache key #{key} to #{layer} layer"
      rescue => e
        Rails.logger.warn "Cache promotion failed for #{layer}: #{e.message}"
      end
    end
  end
end