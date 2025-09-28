class WarmCdnCacheJob < ApplicationJob
  queue_as :caching

  def perform(urls, options = {})
    cdn_service = CdnService.instance

    return unless cdn_service.respond_to?(:enabled?) && cdn_service.enabled?

    urls = Array(urls)
    cache_type = options[:cache_type] || :general
    priority = options[:priority] || :medium

    begin
      start_time = Time.current
      warmed_count = 0
      failed_count = 0

      Rails.logger.info "Starting CDN cache warming for #{urls.size} URLs (#{cache_type})"

      urls.each_with_index do |url, index|
        begin
          success = warm_single_cdn_url(url, options)

          if success
            warmed_count += 1
            Rails.logger.debug "CDN cache warmed: #{url}"
          else
            failed_count += 1
            Rails.logger.warn "CDN cache warming failed: #{url}"
          end

          # Rate limiting to prevent overwhelming CDN
          sleep(calculate_warming_delay(priority, index)) if should_rate_limit?(priority)

        rescue => e
          failed_count += 1
          Rails.logger.error "CDN cache warming error for #{url}: #{e.message}"
        end
      end

      warming_time = Time.current - start_time
      success_rate = (warmed_count.to_f / urls.size * 100).round(2)

      Rails.logger.info "CDN cache warming completed: #{warmed_count}/#{urls.size} URLs warmed (#{success_rate}%) in #{warming_time.round(2)}s"

      # Record warming statistics
      record_warming_statistics(cache_type, warmed_count, failed_count, warming_time)

      # Schedule follow-up warming if needed
      schedule_follow_up_warming(urls, options) if should_schedule_follow_up?(failed_count, options)

    rescue => e
      Rails.logger.error "CDN cache warming job failed: #{e.message}"
      raise
    end
  end

  private

  def warm_single_cdn_url(url, options)
    # Multiple warming strategies
    strategies = [ :head_request, :get_request, :cloudflare_api_warm ]

    strategies.each do |strategy|
      success = send("warm_with_#{strategy}", url, options)
      return true if success
    end

    false
  end

  def warm_with_head_request(url, options)
    # Use HEAD request to warm cache without transferring body
    begin
      response = HTTParty.head(url, {
        timeout: 10,
        headers: build_warming_headers(options),
        follow_redirects: true
      })

      response.success? && cache_hit_detected?(response)
    rescue
      false
    end
  end

  def warm_with_get_request(url, options)
    # Use GET request for more thorough warming
    begin
      response = HTTParty.get(url, {
        timeout: 15,
        headers: build_warming_headers(options),
        follow_redirects: true,
        stream_body: true # Stream to avoid loading large files into memory
      })

      response.success? && response.code == 200
    rescue
      false
    end
  end

  def warm_with_cloudflare_api_warm(url, options)
    # Use Cloudflare API to explicitly warm cache
    return false unless cloudflare_configured?

    begin
      cdn_service = CdnService.instance
      result = cdn_service.warm_cache([ url ], {
        method: :api,
        priority: options[:priority]
      })

      result > 0
    rescue
      false
    end
  end

  def build_warming_headers(options)
    headers = {
      "User-Agent" => "BrokerSync-CDN-Warmer/1.0",
      "Accept" => "*/*",
      "Accept-Encoding" => "gzip, deflate",
      "Connection" => "keep-alive"
    }

    # Add cache-friendly headers
    headers["Cache-Control"] = "max-age=0" if options[:force_origin]
    headers["Pragma"] = "no-cache" if options[:force_origin]

    # Add edge location hint for Cloudflare
    if options[:edge_location]
      headers["CF-IPCountry"] = options[:edge_location]
    end

    headers
  end

  def cache_hit_detected?(response)
    # Detect if response came from cache
    cf_cache_status = response.headers["cf-cache-status"]

    case cf_cache_status&.downcase
    when "hit", "stale"
      true
    when "miss", "expired"
      true # Still counts as successful warming
    else
      # Check other cache indicators
      response.headers["x-cache"]&.include?("HIT") ||
        response.headers["x-served-by"]&.present? ||
        response.code == 200
    end
  end

  def calculate_warming_delay(priority, index)
    base_delay = case priority
    when :critical, :immediate
                   0.1
    when :high
                   0.2
    when :medium
                   0.5
    when :low
                   1.0
    else
                   0.3
    end

    # Progressive delay to prevent overwhelming
    progression_factor = (index / 10.0) * 0.1
    base_delay + progression_factor
  end

  def should_rate_limit?(priority)
    # Only rate limit for non-critical priorities
    priority != :critical && priority != :immediate
  end

  def record_warming_statistics(cache_type, warmed_count, failed_count, warming_time)
    stats_key = "cdn_warming_stats:#{cache_type}:#{Date.current}"

    current_stats = Rails.cache.read(stats_key) || {
      total_urls: 0,
      warmed_count: 0,
      failed_count: 0,
      total_time: 0,
      warming_sessions: 0
    }

    current_stats[:total_urls] += (warmed_count + failed_count)
    current_stats[:warmed_count] += warmed_count
    current_stats[:failed_count] += failed_count
    current_stats[:total_time] += warming_time
    current_stats[:warming_sessions] += 1

    Rails.cache.write(stats_key, current_stats, expires_in: 7.days)

    Rails.logger.info "CDN warming stats updated: #{cache_type} - #{warmed_count}/#{warmed_count + failed_count} success"
  end

  def should_schedule_follow_up?(failed_count, options)
    # Schedule follow-up if there were failures and retries are enabled
    failed_count > 0 &&
      options[:retry_failures] &&
      (options[:retry_count] || 0) < 3
  end

  def schedule_follow_up_warming(urls, options)
    # Extract failed URLs (simplified - in production, track actual failures)
    retry_delay = (options[:retry_count] || 0) * 5.minutes + 5.minutes

    self.class.set(wait: retry_delay).perform_later(
      urls,
      options.merge(
        retry_count: (options[:retry_count] || 0) + 1,
        priority: :low
      )
    )

    Rails.logger.info "Scheduled CDN warming retry in #{retry_delay.inspect}"
  end

  def cloudflare_configured?
    ENV['CLOUDFLARE_API_TOKEN'].present? &&
      ENV['CLOUDFLARE_ZONE_ID'].present?
  end
end
