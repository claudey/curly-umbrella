class CacheWarmingJob < ApplicationJob
  queue_as :caching
  
  def perform(data_type, options = {})
    cache_service = AdvancedCachingService.instance
    
    begin
      start_time = Time.current
      result = cache_service.warm_cache(data_type.to_sym, options)
      warming_time = Time.current - start_time
      
      if result
        Rails.logger.info "Cache warming completed for #{data_type} in #{warming_time.round(2)}s"
      else
        Rails.logger.warn "Cache warming failed for #{data_type}"
      end
      
      # Schedule next warming if configured
      if options[:recurring]
        schedule_next_warming(data_type, options)
      end
      
    rescue => e
      Rails.logger.error "Cache warming job failed for #{data_type}: #{e.message}"
      raise
    end
  end
  
  private
  
  def schedule_next_warming(data_type, options)
    interval = options[:interval] || 1.hour
    self.class.set(wait: interval).perform_later(data_type, options)
  end
end