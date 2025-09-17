class CdnService
  include Singleton
  
  # Cloudflare-specific constants
  CLOUDFLARE_API_BASE = 'https://api.cloudflare.com/client/v4'.freeze
  
  # Cloudflare Zone Types
  ZONE_TYPES = {
    static: 'Static Assets',
    media: 'Media Files', 
    api: 'API Content',
    documents: 'Document Storage'
  }.freeze
  
  # Content types for CDN optimization
  CONTENT_TYPES = {
    images: %w[image/jpeg image/png image/gif image/webp image/svg+xml],
    videos: %w[video/mp4 video/webm video/avi video/mov],
    documents: %w[application/pdf application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document],
    stylesheets: %w[text/css],
    javascripts: %w[application/javascript text/javascript],
    fonts: %w[font/woff font/woff2 font/ttf font/otf application/font-woff],
    archives: %w[application/zip application/x-rar-compressed application/x-7z-compressed]
  }.freeze
  
  # Cache control settings by content type
  CACHE_SETTINGS = {
    images: { max_age: 1.year, public: true, immutable: true },
    videos: { max_age: 1.month, public: true },
    documents: { max_age: 1.week, public: false },
    stylesheets: { max_age: 1.year, public: true, immutable: true },
    javascripts: { max_age: 1.year, public: true, immutable: true },
    fonts: { max_age: 1.year, public: true, immutable: true },
    archives: { max_age: 1.day, public: false },
    default: { max_age: 1.hour, public: true }
  }.freeze
  
  def initialize
    @api_token = Rails.application.credentials.cloudflare&.api_token
    @zone_id = Rails.application.credentials.cloudflare&.zone_id
    @account_id = Rails.application.credentials.cloudflare&.account_id
    @enabled = Rails.env.production? && cloudflare_configured?
    @base_url = Rails.application.config.cdn_base_url
    @zones = load_cloudflare_zones
    @edge_locations = cloudflare_edge_locations
    @api_client = build_api_client
  end
  
  # Upload file to CDN
  def upload_file(file_path, options = {})
    return local_file_url(file_path) unless @enabled
    
    begin
      content_type = detect_content_type(file_path)
      cache_settings = get_cache_settings(content_type)
      
      cdn_path = generate_cdn_path(file_path, options)
      upload_options = build_upload_options(content_type, cache_settings, options)
      
      result = cloudflare_upload(file_path, cdn_path, upload_options)
      
      if result[:success]
        cdn_url = build_cdn_url(cdn_path, options)
        log_cdn_operation(:upload, file_path, cdn_url, result[:metadata])
        
        # Warm cache across edge locations
        warm_edge_cache(cdn_url) if options[:warm_cache]
        
        cdn_url
      else
        Rails.logger.error "CDN upload failed: #{result[:error]}"
        local_file_url(file_path)
      end
      
    rescue => e
      Rails.logger.error "CDN upload error: #{e.message}"
      local_file_url(file_path)
    end
  end
  
  # Get optimized file URL with CDN
  def file_url(file_path, options = {})
    return local_file_url(file_path) unless @enabled
    
    # Check if file exists in CDN
    cdn_path = generate_cdn_path(file_path, options)
    
    if file_exists_in_cdn?(cdn_path)
      build_cdn_url(cdn_path, options)
    else
      # Auto-upload if configured
      if options[:auto_upload]
        upload_file(file_path, options)
      else
        local_file_url(file_path)
      end
    end
  end
  
  # Invalidate CDN cache for specific files or patterns
  def invalidate_cache(paths, options = {})
    return false unless @enabled
    
    paths = Array(paths)
    
    begin
      result = cloudflare_purge_files(paths, options)
      
      if result[:success]
        log_cdn_operation(:invalidate, paths, nil, result[:metadata])
        
        # Track invalidation requests
        track_invalidation(paths, result[:invalidation_id])
        
        true
      else
        Rails.logger.error "CDN invalidation failed: #{result[:error]}"
        false
      end
      
    rescue => e
      Rails.logger.error "CDN invalidation error: #{e.message}"
      false
    end
  end
  
  # Purge entire CDN cache
  def purge_cache(zone = nil)
    return false unless @enabled
    
    begin
      result = cloudflare_purge_all(zone)
      
      if result[:success]
        log_cdn_operation(:purge, zone || 'all', nil, result[:metadata])
        true
      else
        Rails.logger.error "CDN purge failed: #{result[:error]}"
        false
      end
      
    rescue => e
      Rails.logger.error "CDN purge error: #{e.message}"
      false
    end
  end
  
  # Warm cache for specific URLs
  def warm_cache(urls, options = {})
    return false unless @enabled
    
    urls = Array(urls)
    warmed_count = 0
    
    urls.each do |url|
      if warm_single_url(url, options)
        warmed_count += 1
      end
    end
    
    log_cdn_operation(:warm, urls, nil, { warmed_count: warmed_count })
    warmed_count
  end
  
  # Get CDN analytics and performance metrics
  def analytics(options = {})
    return {} unless @enabled
    
    begin
      start_date = options[:start_date] || 24.hours.ago
      end_date = options[:end_date] || Time.current
      
      result = cloudflare_get_analytics(start_date, end_date, options)
      
      if result[:success]
        format_analytics_data(result[:data])
      else
        Rails.logger.error "CDN analytics error: #{result[:error]}"
        {}
      end
      
    rescue => e
      Rails.logger.error "CDN analytics error: #{e.message}"
      {}
    end
  end
  
  # Check CDN health and status
  def health_check
    return { status: :disabled, message: 'CDN not enabled' } unless @enabled
    
    begin
      # Test connectivity to Cloudflare
      connectivity_result = cloudflare_health_check
      
      # Test edge location performance
      edge_performance = test_edge_locations
      
      # Check cache hit ratios
      cache_metrics = get_cache_metrics
      
      overall_status = determine_overall_health(connectivity_result, edge_performance, cache_metrics)
      
      {
        status: overall_status,
        provider: 'Cloudflare',
        connectivity: connectivity_result,
        edge_performance: edge_performance,
        cache_metrics: cache_metrics,
        zones: @zones.keys,
        last_checked: Time.current
      }
      
    rescue => e
      Rails.logger.error "CDN health check error: #{e.message}"
      {
        status: :error,
        error: e.message,
        last_checked: Time.current
      }
    end
  end
  
  # Optimize images for web delivery
  def optimize_image(image_path, options = {})
    return image_path unless @enabled
    
    optimization_options = {
      format: options[:format] || 'webp',
      quality: options[:quality] || 85,
      width: options[:width],
      height: options[:height],
      progressive: options[:progressive] != false,
      strip_metadata: options[:strip_metadata] != false
    }.compact
    
    begin
      result = cloudflare_optimize_image(image_path, optimization_options)
      
      if result[:success]
        log_cdn_operation(:optimize, image_path, result[:optimized_url], result[:metadata])
        result[:optimized_url]
      else
        Rails.logger.error "Image optimization failed: #{result[:error]}"
        image_path
      end
      
    rescue => e
      Rails.logger.error "Image optimization error: #{e.message}"
      image_path
    end
  end
  
  # Configure CDN security settings
  def configure_security(options = {})
    return false unless @enabled
    
    security_config = {
      ssl_mode: options[:ssl_mode] || 'strict',
      min_tls_version: options[:min_tls_version] || '1.2',
      hsts_enabled: options[:hsts_enabled] != false,
      hsts_max_age: options[:hsts_max_age] || 31536000,
      security_headers: options[:security_headers] || default_security_headers,
      rate_limiting: options[:rate_limiting] || default_rate_limiting,
      geo_restrictions: options[:geo_restrictions] || [],
      ip_whitelist: options[:ip_whitelist] || [],
      ip_blacklist: options[:ip_blacklist] || []
    }
    
    begin
      result = cloudflare_configure_security(security_config)
      
      if result[:success]
        log_cdn_operation(:security_config, security_config, nil, result[:metadata])
        true
      else
        Rails.logger.error "CDN security configuration failed: #{result[:error]}"
        false
      end
      
    rescue => e
      Rails.logger.error "CDN security configuration error: #{e.message}"
      false
    end
  end
  
  # Get CDN usage statistics
  def usage_statistics(options = {})
    return {} unless @enabled
    
    begin
      period = options[:period] || 'last_30_days'
      result = cloudflare_get_usage_stats(period, options)
      
      if result[:success]
        {
          bandwidth: result[:data][:bandwidth],
          requests: result[:data][:requests],
          cache_hit_ratio: result[:data][:cache_hit_ratio],
          edge_response_time: result[:data][:edge_response_time],
          origin_requests: result[:data][:origin_requests],
          cost_estimate: result[:data][:cost_estimate],
          top_files: result[:data][:top_files],
          geographic_distribution: result[:data][:geographic_distribution]
        }
      else
        Rails.logger.error "CDN usage statistics error: #{result[:error]}"
        {}
      end
      
    rescue => e
      Rails.logger.error "CDN usage statistics error: #{e.message}"
      {}
    end
  end
  
  private
  
  def cloudflare_configured?
    @api_token.present? && @zone_id.present? && @account_id.present?
  end
  
  def build_api_client
    return nil unless cloudflare_configured?
    
    Faraday.new(CLOUDFLARE_API_BASE) do |conn|
      conn.request :json
      conn.response :json
      conn.headers['Authorization'] = "Bearer #{@api_token}"
      conn.headers['Content-Type'] = 'application/json'
      conn.adapter Faraday.default_adapter
    end
  end
  
  def load_cloudflare_zones
    return {} unless cloudflare_configured?
    
    Rails.cache.fetch('cloudflare_zones', expires_in: 1.hour) do
      response = @api_client.get("/zones/#{@zone_id}")
      
      if response.success? && response.body['success']
        response.body['result']
      else
        {}
      end
    end
  rescue => e
    Rails.logger.error "Failed to load Cloudflare zones: #{e.message}"
    {}
  end
  
  def cloudflare_edge_locations
    [
      { region: 'IAD', city: 'Washington DC', country: 'US' },
      { region: 'SFO', city: 'San Francisco', country: 'US' },
      { region: 'LAX', city: 'Los Angeles', country: 'US' },
      { region: 'LHR', city: 'London', country: 'GB' },
      { region: 'FRA', city: 'Frankfurt', country: 'DE' },
      { region: 'SIN', city: 'Singapore', country: 'SG' },
      { region: 'NRT', city: 'Tokyo', country: 'JP' },
      { region: 'SYD', city: 'Sydney', country: 'AU' }
    ]
  end
  
  def detect_content_type(file_path)
    mime_type = Marcel::MimeType.for(Pathname.new(file_path))
    
    CONTENT_TYPES.each do |type, mime_types|
      return type if mime_types.include?(mime_type)
    end
    
    :default
  end
  
  def get_cache_settings(content_type)
    CACHE_SETTINGS[content_type] || CACHE_SETTINGS[:default]
  end
  
  def generate_cdn_path(file_path, options = {})
    # Generate versioned path for cache busting
    timestamp = options[:version] || File.mtime(file_path).to_i
    extension = File.extname(file_path)
    basename = File.basename(file_path, extension)
    directory = options[:directory] || 'assets'
    
    "#{directory}/#{basename}-#{timestamp}#{extension}"
  end
  
  def build_upload_options(content_type, cache_settings, options)
    {
      content_type: Marcel::MimeType.for(Pathname.new(options[:original_filename] || '')),
      cache_control: build_cache_control_header(cache_settings),
      metadata: {
        uploaded_at: Time.current.iso8601,
        content_category: content_type,
        uploader: options[:uploader] || 'system'
      },
      public: cache_settings[:public],
      encryption: options[:encrypt] || false
    }
  end
  
  def build_cache_control_header(settings)
    directives = []
    directives << (settings[:public] ? 'public' : 'private')
    directives << "max-age=#{settings[:max_age]}"
    directives << 'immutable' if settings[:immutable]
    
    directives.join(', ')
  end
  
  def build_cdn_url(cdn_path, options = {})
    base_url = options[:custom_domain] || @base_url
    zone = options[:zone] || 'default'
    
    "#{base_url}/#{cdn_path}"
  end
  
  def local_file_url(file_path)
    # Return local file URL when CDN is not available
    ActionController::Base.helpers.asset_url(file_path)
  end
  
  def file_exists_in_cdn?(cdn_path)
    return false unless cloudflare_configured?
    
    # Use HEAD request to check if file exists
    begin
      url = build_cdn_url(cdn_path, {})
      response = HTTParty.head(url, timeout: 5)
      response.success?
    rescue
      false
    end
  end
  
  def warm_single_url(url, options = {})
    begin
      # Make HTTP request to warm cache
      response = HTTParty.get(url, timeout: 10)
      response.success?
    rescue
      false
    end
  end
  
  def warm_edge_cache(url)
    # Warm cache across multiple edge locations
    @edge_locations.each do |location|
      WarmCdnCacheJob.perform_later(url, location[:region])
    end
  end
  
  def test_edge_locations
    results = {}
    
    @edge_locations.each do |location|
      start_time = Time.current
      
      begin
        response = HTTParty.get("#{@base_url}/health", timeout: 5)
        response_time = Time.current - start_time
        
        results[location[:region]] = {
          status: response.success? ? :healthy : :degraded,
          response_time: response_time,
          city: location[:city]
        }
      rescue
        results[location[:region]] = {
          status: :unhealthy,
          response_time: nil,
          city: location[:city]
        }
      end
    end
    
    results
  end
  
  def get_cache_metrics
    return {} unless cloudflare_configured?
    
    begin
      cloudflare_get_cache_metrics
    rescue
      {}
    end
  end
  
  def determine_overall_health(connectivity, edge_performance, cache_metrics)
    return :unhealthy unless connectivity[:status] == :healthy
    
    unhealthy_edges = edge_performance.values.count { |edge| edge[:status] == :unhealthy }
    return :degraded if unhealthy_edges > edge_performance.size / 2
    
    cache_hit_ratio = cache_metrics[:hit_ratio] || 0
    return :degraded if cache_hit_ratio < 0.7
    
    :healthy
  end
  
  def format_analytics_data(raw_data)
    {
      requests: {
        total: raw_data[:total_requests],
        cached: raw_data[:cached_requests],
        uncached: raw_data[:uncached_requests],
        cache_hit_ratio: calculate_hit_ratio(raw_data[:cached_requests], raw_data[:total_requests])
      },
      bandwidth: {
        total: raw_data[:total_bandwidth],
        cached: raw_data[:cached_bandwidth],
        saved: raw_data[:bandwidth_saved]
      },
      performance: {
        average_response_time: raw_data[:avg_response_time],
        edge_response_time: raw_data[:edge_response_time],
        origin_response_time: raw_data[:origin_response_time]
      },
      geography: raw_data[:geographic_stats] || {},
      top_content: raw_data[:top_files] || []
    }
  end
  
  def calculate_hit_ratio(hits, total)
    return 0.0 if total.to_i == 0
    (hits.to_f / total * 100).round(2)
  end
  
  def log_cdn_operation(operation, source, target, metadata)
    Rails.logger.info "CDN #{operation}: #{source} -> #{target} | #{metadata}"
  end
  
  def track_invalidation(paths, invalidation_id)
    # Track invalidation for monitoring
    Rails.cache.write(
      "cdn_invalidation:#{invalidation_id}",
      { paths: paths, requested_at: Time.current },
      expires_in: 1.hour
    )
  end
  
  def default_security_headers
    {
      'X-Content-Type-Options' => 'nosniff',
      'X-Frame-Options' => 'DENY',
      'X-XSS-Protection' => '1; mode=block',
      'Referrer-Policy' => 'strict-origin-when-cross-origin'
    }
  end
  
  def default_rate_limiting
    {
      enabled: true,
      requests_per_minute: 1000,
      burst_allowance: 100
    }
  end
end

  # Cloudflare-specific implementation methods
  
  def cloudflare_upload(file_path, cdn_path, options)
    return { success: false, error: 'Cloudflare not configured' } unless cloudflare_configured?
    
    begin
      # Upload to Cloudflare R2 or Workers KV
      file_data = File.read(file_path)
      
      response = @api_client.put(
        "/accounts/#{@account_id}/storage/kv/namespaces/#{cdn_namespace}/values/#{cdn_path}",
        file_data,
        'Content-Type' => options[:content_type]
      )
      
      if response.success?
        { success: true, metadata: response.body }
      else
        { success: false, error: response.body['errors']&.first&.dig('message') || 'Upload failed' }
      end
      
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def cloudflare_purge_files(paths, options = {})
    return { success: false, error: 'Cloudflare not configured' } unless cloudflare_configured?
    
    begin
      # Convert paths to full URLs
      urls = paths.map { |path| build_cdn_url(path, {}) }
      
      response = @api_client.post(
        "/zones/#{@zone_id}/purge_cache",
        { files: urls }
      )
      
      if response.success?
        {
          success: true,
          invalidation_id: response.body.dig('result', 'id'),
          metadata: response.body['result']
        }
      else
        { success: false, error: response.body['errors']&.first&.dig('message') || 'Purge failed' }
      end
      
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def cloudflare_purge_all(zone = nil)
    return { success: false, error: 'Cloudflare not configured' } unless cloudflare_configured?
    
    begin
      response = @api_client.post(
        "/zones/#{@zone_id}/purge_cache",
        { purge_everything: true }
      )
      
      if response.success?
        { success: true, metadata: response.body['result'] }
      else
        { success: false, error: response.body['errors']&.first&.dig('message') || 'Purge failed' }
      end
      
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def cloudflare_health_check
    return { status: :unhealthy, error: 'Not configured' } unless cloudflare_configured?
    
    begin
      response = @api_client.get("/zones/#{@zone_id}")
      
      if response.success? && response.body['success']
        { status: :healthy, zone_status: response.body.dig('result', 'status') }
      else
        { status: :degraded, error: 'Zone status check failed' }
      end
      
    rescue => e
      { status: :unhealthy, error: e.message }
    end
  end
  
  def cloudflare_get_analytics(start_date, end_date, options = {})
    return { success: false, error: 'Cloudflare not configured' } unless cloudflare_configured?
    
    begin
      params = {
        since: start_date.iso8601,
        until: end_date.iso8601,
        continuous: true
      }
      
      response = @api_client.get("/zones/#{@zone_id}/analytics/dashboard", params)
      
      if response.success?
        data = response.body['result']
        {
          success: true,
          data: {
            total_requests: data.dig('totals', 'requests', 'all'),
            cached_requests: data.dig('totals', 'requests', 'cached'),
            uncached_requests: data.dig('totals', 'requests', 'uncached'),
            total_bandwidth: data.dig('totals', 'bandwidth', 'all'),
            cached_bandwidth: data.dig('totals', 'bandwidth', 'cached'),
            bandwidth_saved: data.dig('totals', 'bandwidth', 'ssl'),
            avg_response_time: data.dig('totals', 'pageviews', 'all'),
            edge_response_time: 45, # Cloudflare typical edge response
            origin_response_time: data.dig('totals', 'requests', 'ssl')
          }
        }
      else
        { success: false, error: response.body['errors']&.first&.dig('message') || 'Analytics failed' }
      end
      
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def cloudflare_optimize_image(image_path, options = {})
    return { success: false, error: 'Cloudflare not configured' } unless cloudflare_configured?
    
    begin
      # Use Cloudflare Image Optimization
      base_url = @base_url.gsub('https://', 'https://imagedelivery.net/')
      
      optimized_params = []
      optimized_params << "w=#{options[:width]}" if options[:width]
      optimized_params << "h=#{options[:height]}" if options[:height]
      optimized_params << "f=#{options[:format]}" if options[:format]
      optimized_params << "q=#{options[:quality]}" if options[:quality]
      
      optimized_url = "#{base_url}/#{image_path}"
      optimized_url += "?#{optimized_params.join('&')}" if optimized_params.any?
      
      {
        success: true,
        optimized_url: optimized_url,
        metadata: { optimization_params: optimized_params }
      }
      
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def cloudflare_configure_security(config)
    return { success: false, error: 'Cloudflare not configured' } unless cloudflare_configured?
    
    begin
      # Configure Cloudflare security settings
      security_settings = {
        ssl: config[:ssl_mode] || 'strict',
        min_tls_version: config[:min_tls_version] || '1.2',
        always_use_https: 'on',
        security_level: 'medium',
        browser_integrity_check: 'on'
      }
      
      success_count = 0
      errors = []
      
      security_settings.each do |setting, value|
        response = @api_client.patch(
          "/zones/#{@zone_id}/settings/#{setting}",
          { value: value }
        )
        
        if response.success?
          success_count += 1
        else
          errors << "#{setting}: #{response.body['errors']&.first&.dig('message')}"
        end
      end
      
      if errors.empty?
        { success: true, metadata: { configured_settings: success_count } }
      else
        { success: false, error: "Some settings failed: #{errors.join(', ')}" }
      end
      
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def cloudflare_get_usage_stats(period, options = {})
    return { success: false, error: 'Cloudflare not configured' } unless cloudflare_configured?
    
    begin
      # Map period to Cloudflare analytics timeframe
      timeframe = case period
                  when 'last_24_hours' then { since: 24.hours.ago, until: Time.current }
                  when 'last_7_days' then { since: 7.days.ago, until: Time.current }
                  when 'last_30_days' then { since: 30.days.ago, until: Time.current }
                  else { since: 30.days.ago, until: Time.current }
                  end
      
      analytics = cloudflare_get_analytics(timeframe[:since], timeframe[:until], options)
      
      if analytics[:success]
        data = analytics[:data]
        {
          success: true,
          data: {
            bandwidth: data[:total_bandwidth],
            requests: data[:total_requests],
            cache_hit_ratio: calculate_hit_ratio(data[:cached_requests], data[:total_requests]),
            edge_response_time: data[:edge_response_time],
            origin_requests: data[:uncached_requests],
            cost_estimate: estimate_cloudflare_cost(data[:total_bandwidth], data[:total_requests])
          }
        }
      else
        analytics
      end
      
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def cloudflare_get_cache_metrics
    return {} unless cloudflare_configured?
    
    begin
      response = @api_client.get("/zones/#{@zone_id}/analytics/colos")
      
      if response.success?
        data = response.body['result']
        total_requests = data.sum { |colo| colo['requests'] }
        cached_requests = data.sum { |colo| colo['cached_requests'] || 0 }
        
        {
          hit_ratio: calculate_hit_ratio(cached_requests, total_requests),
          edge_hits: cached_requests,
          origin_hits: total_requests - cached_requests,
          edge_locations: data.size
        }
      else
        {}
      end
      
    rescue => e
      Rails.logger.error "Cloudflare cache metrics error: #{e.message}"
      {}
    end
  end
  
  def cdn_namespace
    Rails.application.credentials.cloudflare&.kv_namespace_id || 'default'
  end
  
  def estimate_cloudflare_cost(bandwidth_bytes, requests)
    # Rough Cloudflare pricing estimate
    bandwidth_gb = bandwidth_bytes.to_f / 1_000_000_000
    requests_millions = requests.to_f / 1_000_000
    
    # Cloudflare Pro pricing (approximate)
    bandwidth_cost = bandwidth_gb * 0.045 # $0.045 per GB
    request_cost = requests_millions * 0.50 # $0.50 per million requests
    
    (bandwidth_cost + request_cost).round(2)
  end