class AdvancedCachingService
  include Singleton

  # Cache layer priorities (fastest to slowest)
  CACHE_LAYERS = {
    memory: :memory_cache,      # Application memory (fastest)
    redis: :redis_cache,        # Redis (fast, persistent)
    memcached: :memcached_cache, # Memcached (fast, distributed)
    database: :database_cache    # Database query cache (slowest)
  }.freeze

  # Cache TTL configurations by data type
  CACHE_TTLS = {
    user_session: 30.minutes,
    user_preferences: 1.hour,
    organization_data: 2.hours,
    application_data: 15.minutes,
    quote_data: 10.minutes,
    static_content: 24.hours,
    analytics_data: 5.minutes,
    feature_flags: 5.minutes,
    api_responses: 2.minutes,
    search_results: 30.minutes
  }.freeze

  # Cache size limits (in MB)
  CACHE_LIMITS = {
    memory: 128,      # 128MB application memory
    redis: 512,       # 512MB Redis
    memcached: 256    # 256MB Memcached
  }.freeze

  def initialize
    @memory_cache = ActiveSupport::Cache::MemoryStore.new(size: CACHE_LIMITS[:memory].megabytes)
    @redis_cache = setup_redis_cache
    @memcached_cache = setup_memcached_cache
    @cache_stats = CacheStatistics.new
    @cache_warming_enabled = Rails.env.production?
  end

  # Multi-layer cache read with fallback
  def read(key, options = {})
    cache_type = options[:type] || :application_data
    layers = options[:layers] || [ :memory, :redis, :memcached ]

    start_time = Time.current

    layers.each do |layer|
      cache = get_cache_instance(layer)
      next unless cache

      begin
        value = cache.read(normalize_key(key, layer))
        if value
          @cache_stats.record_hit(layer, cache_type, Time.current - start_time)

          # Promote to faster layers
          promote_to_faster_layers(key, value, layer, layers)

          return deserialize_value(value)
        end
      rescue => e
        Rails.logger.warn "Cache read error on #{layer}: #{e.message}"
        @cache_stats.record_error(layer, :read, e.message)
      end
    end

    @cache_stats.record_miss(cache_type, Time.current - start_time)
    nil
  end

  # Multi-layer cache write
  def write(key, value, options = {})
    cache_type = options[:type] || :application_data
    ttl = options[:ttl] || CACHE_TTLS[cache_type] || 1.hour
    layers = options[:layers] || [ :memory, :redis, :memcached ]

    serialized_value = serialize_value(value, options)

    layers.each do |layer|
      cache = get_cache_instance(layer)
      next unless cache

      begin
        cache_options = build_cache_options(layer, ttl, options)
        cache.write(normalize_key(key, layer), serialized_value, cache_options)
        @cache_stats.record_write(layer, cache_type)
      rescue => e
        Rails.logger.warn "Cache write error on #{layer}: #{e.message}"
        @cache_stats.record_error(layer, :write, e.message)
      end
    end

    true
  end

  # Fetch with multi-layer caching and block execution
  def fetch(key, options = {}, &block)
    value = read(key, options)
    return value if value

    # Execute block and cache result
    start_time = Time.current
    result = block.call
    execution_time = Time.current - start_time

    # Cache the result
    write(key, result, options)

    @cache_stats.record_generation(options[:type] || :application_data, execution_time)
    result
  end

  # Delete from all cache layers
  def delete(key, options = {})
    layers = options[:layers] || [ :memory, :redis, :memcached ]

    layers.each do |layer|
      cache = get_cache_instance(layer)
      next unless cache

      begin
        cache.delete(normalize_key(key, layer))
        @cache_stats.record_deletion(layer)
      rescue => e
        Rails.logger.warn "Cache delete error on #{layer}: #{e.message}"
      end
    end

    true
  end

  # Cache warming for frequently accessed data
  def warm_cache(data_type, options = {})
    return unless @cache_warming_enabled

    start_time = Time.current
    warmed_count = 0

    case data_type
    when :user_sessions
      warmed_count = warm_user_sessions(options)
    when :organization_data
      warmed_count = warm_organization_data(options)
    when :application_data
      warmed_count = warm_application_data(options)
    when :feature_flags
      warmed_count = warm_feature_flags(options)
    when :static_content
      warmed_count = warm_static_content(options)
    else
      Rails.logger.warn "Unknown cache warming type: #{data_type}"
      return false
    end

    warming_time = Time.current - start_time
    @cache_stats.record_warming(data_type, warmed_count, warming_time)

    Rails.logger.info "Cache warming completed: #{data_type} (#{warmed_count} items in #{warming_time.round(2)}s)"
    true
  end

  # Intelligent cache preloading based on usage patterns
  def intelligent_preload(user_id = nil, organization_id = nil)
    return unless @cache_warming_enabled

    start_time = Time.current
    preloaded_items = []

    # User-specific preloading
    if user_id
      user = User.find_by(id: user_id)
      if user
        preloaded_items.concat(preload_user_data(user))
      end
    end

    # Organization-specific preloading
    if organization_id
      organization = Organization.find_by(id: organization_id)
      if organization
        preloaded_items.concat(preload_organization_data(organization))
      end
    end

    # Global preloading based on popular content
    preloaded_items.concat(preload_popular_content)

    preload_time = Time.current - start_time
    @cache_stats.record_preload(preloaded_items.size, preload_time)

    Rails.logger.info "Intelligent preload completed: #{preloaded_items.size} items in #{preload_time.round(2)}s"
    preloaded_items
  end

  # Cache statistics and monitoring
  def cache_statistics
    {
      memory: @memory_cache.stats,
      redis: redis_stats,
      memcached: memcached_stats,
      application: @cache_stats.to_hash,
      health: cache_health_check
    }
  end

  # Cache health monitoring
  def cache_health_check
    health = {
      overall_status: :healthy,
      layer_status: {},
      performance_metrics: {},
      recommendations: []
    }

    CACHE_LAYERS.each do |layer_name, _|
      layer_health = check_layer_health(layer_name)
      health[:layer_status][layer_name] = layer_health[:status]
      health[:performance_metrics][layer_name] = layer_health[:metrics]

      if layer_health[:status] != :healthy
        health[:overall_status] = :degraded
        health[:recommendations].concat(layer_health[:recommendations])
      end
    end

    # Overall performance recommendations
    if @cache_stats.hit_ratio < 0.8
      health[:recommendations] << "Consider increasing cache TTLs or warming more data"
    end

    if @cache_stats.average_response_time > 50.milliseconds
      health[:recommendations] << "Cache response times are high, consider optimizing cache keys or data structure"
    end

    health
  end

  # Clear all caches
  def clear_all_caches(confirm: false)
    return false unless confirm

    CACHE_LAYERS.keys.each do |layer|
      clear_cache_layer(layer)
    end

    @cache_stats.reset!
    Rails.logger.info "All cache layers cleared"
    true
  end

  # Cache invalidation patterns
  def invalidate_pattern(pattern, options = {})
    layers = options[:layers] || [ :memory, :redis, :memcached ]
    invalidated_count = 0

    layers.each do |layer|
      count = invalidate_layer_pattern(layer, pattern)
      invalidated_count += count
    end

    Rails.logger.info "Invalidated #{invalidated_count} cache keys matching pattern: #{pattern}"
    invalidated_count
  end

  private

  def setup_redis_cache
    return nil unless Rails.cache.is_a?(ActiveSupport::Cache::RedisCacheStore)
    Rails.cache
  end

  def setup_memcached_cache
    return nil unless defined?(Dalli)

    begin
      dalli_client = Dalli::Client.new([ "localhost:11211" ], {
        expires_in: 1.hour,
        compress: true,
        compression_min_size: 1024,
        serializer: JSON
      })
      ActiveSupport::Cache::MemCacheStore.new(dalli_client)
    rescue => e
      Rails.logger.warn "Memcached setup failed: #{e.message}"
      nil
    end
  end

  def get_cache_instance(layer)
    case layer
    when :memory
      @memory_cache
    when :redis
      @redis_cache
    when :memcached
      @memcached_cache
    else
      nil
    end
  end

  def normalize_key(key, layer)
    prefix = "brokersync:#{Rails.env}:#{layer}"
    "#{prefix}:#{key.to_s.parameterize}"
  end

  def serialize_value(value, options = {})
    return value if value.is_a?(String) && !options[:force_serialize]

    {
      data: value,
      serialized_at: Time.current.to_f,
      type: value.class.name,
      version: options[:version] || 1
    }.to_json
  end

  def deserialize_value(value)
    return value unless value.is_a?(String) && value.start_with?("{")

    begin
      parsed = JSON.parse(value)
      return value unless parsed.is_a?(Hash) && parsed["data"]

      parsed["data"]
    rescue JSON::ParserError
      value
    end
  end

  def build_cache_options(layer, ttl, options)
    base_options = { expires_in: ttl }

    case layer
    when :redis
      base_options.merge({
        compress: true,
        compress_threshold: 1.kilobyte
      })
    when :memcached
      base_options.merge({
        compress: true,
        expires_in: [ ttl, 30.days ].min # Memcached max TTL
      })
    else
      base_options
    end
  end

  def promote_to_faster_layers(key, value, found_layer, available_layers)
    return unless available_layers.size > 1

    faster_layers = available_layers.take_while { |layer| layer != found_layer }
    return if faster_layers.empty?

    # Promote to faster layers asynchronously
    PromoteCacheJob.perform_later(key, value, faster_layers)
  end

  def warm_user_sessions(options = {})
    limit = options[:limit] || 1000
    warmed = 0

    User.active.limit(limit).find_each do |user|
      key = "user_session:#{user.id}"
      write(key, user.session_data, type: :user_session)
      warmed += 1
    end

    warmed
  end

  def warm_organization_data(options = {})
    warmed = 0

    Organization.active.find_each do |org|
      key = "organization:#{org.id}"
      write(key, org.cache_data, type: :organization_data)
      warmed += 1
    end

    warmed
  end

  def warm_application_data(options = {})
    limit = options[:limit] || 500
    warmed = 0

    InsuranceApplication.recent.limit(limit).find_each do |app|
      key = "application:#{app.id}"
      write(key, app.cache_data, type: :application_data)
      warmed += 1
    end

    warmed
  end

  def warm_feature_flags(options = {})
    warmed = 0

    FeatureFlag.enabled.find_each do |flag|
      key = "feature_flag:#{flag.key}"
      write(key, flag, type: :feature_flags)
      warmed += 1
    end

    warmed
  end

  def warm_static_content(options = {})
    static_content = {
      insurance_types: InsuranceApplication::INSURANCE_TYPES,
      application_statuses: InsuranceApplication::STATUSES,
      quote_statuses: Quote::STATUSES,
      user_roles: User::ROLES
    }

    static_content.each do |key, content|
      write("static:#{key}", content, type: :static_content)
    end

    static_content.size
  end

  def preload_user_data(user)
    preloaded = []

    # User's recent applications
    applications = user.insurance_applications.recent.limit(10)
    applications.each do |app|
      key = "application:#{app.id}"
      write(key, app.cache_data, type: :application_data)
      preloaded << key
    end

    # User's organization data
    if user.organization
      org_key = "organization:#{user.organization.id}"
      write(org_key, user.organization.cache_data, type: :organization_data)
      preloaded << org_key
    end

    preloaded
  end

  def preload_organization_data(organization)
    preloaded = []

    # Recent applications for organization
    applications = organization.insurance_applications.recent.limit(50)
    applications.each do |app|
      key = "application:#{app.id}"
      write(key, app.cache_data, type: :application_data)
      preloaded << key
    end

    preloaded
  end

  def preload_popular_content
    preloaded = []

    # Most accessed applications (implement popularity tracking)
    popular_apps = InsuranceApplication.popular.limit(20)
    popular_apps.each do |app|
      key = "application:#{app.id}"
      write(key, app.cache_data, type: :application_data)
      preloaded << key
    end

    preloaded
  end

  def redis_stats
    return {} unless @redis_cache

    begin
      info = @redis_cache.redis.info
      {
        used_memory: info["used_memory_human"],
        connected_clients: info["connected_clients"],
        hits: info["keyspace_hits"],
        misses: info["keyspace_misses"],
        hit_ratio: calculate_hit_ratio(info["keyspace_hits"], info["keyspace_misses"])
      }
    rescue => e
      { error: e.message }
    end
  end

  def memcached_stats
    return {} unless @memcached_cache

    begin
      # Implementation depends on memcached client
      {}
    rescue => e
      { error: e.message }
    end
  end

  def check_layer_health(layer)
    cache = get_cache_instance(layer)
    return { status: :unavailable, metrics: {}, recommendations: [] } unless cache

    health = {
      status: :healthy,
      metrics: {},
      recommendations: []
    }

    begin
      # Test basic operations
      test_key = "health_check:#{layer}:#{Time.current.to_i}"
      test_value = "health_check_value"

      start_time = Time.current
      cache.write(test_key, test_value, expires_in: 1.minute)
      write_time = Time.current - start_time

      start_time = Time.current
      retrieved_value = cache.read(test_key)
      read_time = Time.current - start_time

      cache.delete(test_key)

      health[:metrics] = {
        write_time: write_time,
        read_time: read_time,
        operation_success: retrieved_value == test_value
      }

      # Performance thresholds
      if write_time > 100.milliseconds
        health[:status] = :degraded
        health[:recommendations] << "#{layer} write performance is slow"
      end

      if read_time > 50.milliseconds
        health[:status] = :degraded
        health[:recommendations] << "#{layer} read performance is slow"
      end

      unless retrieved_value == test_value
        health[:status] = :unhealthy
        health[:recommendations] << "#{layer} data integrity issue detected"
      end

    rescue => e
      health[:status] = :unhealthy
      health[:metrics][:error] = e.message
      health[:recommendations] << "#{layer} cache layer is not responding"
    end

    health
  end

  def clear_cache_layer(layer)
    cache = get_cache_instance(layer)
    return unless cache

    begin
      case layer
      when :memory
        @memory_cache.clear
      when :redis
        @redis_cache.clear if @redis_cache
      when :memcached
        @memcached_cache.clear if @memcached_cache
      end

      Rails.logger.info "Cleared #{layer} cache layer"
    rescue => e
      Rails.logger.error "Failed to clear #{layer} cache: #{e.message}"
    end
  end

  def invalidate_layer_pattern(layer, pattern)
    # Implementation varies by cache type
    # Redis supports pattern matching, others may need enumeration
    0
  end

  def calculate_hit_ratio(hits, misses)
    total = hits.to_i + misses.to_i
    return 0.0 if total == 0
    (hits.to_f / total * 100).round(2)
  end
end

# Cache statistics tracking
class CacheStatistics
  def initialize
    reset!
  end

  def record_hit(layer, type, time)
    @hits += 1
    @hit_times << time
    @layer_stats[layer][:hits] += 1
    @type_stats[type][:hits] += 1
  end

  def record_miss(type, time)
    @misses += 1
    @miss_times << time
    @type_stats[type][:misses] += 1
  end

  def record_write(layer, type)
    @writes += 1
    @layer_stats[layer][:writes] += 1
    @type_stats[type][:writes] += 1
  end

  def record_deletion(layer)
    @deletions += 1
    @layer_stats[layer][:deletions] += 1
  end

  def record_error(layer, operation, message)
    @errors += 1
    @layer_stats[layer][:errors] += 1
    @error_log << { layer: layer, operation: operation, message: message, time: Time.current }
  end

  def record_generation(type, time)
    @generations += 1
    @generation_times << time
    @type_stats[type][:generations] += 1
  end

  def record_warming(type, count, time)
    @warming_operations += 1
    @warming_items += count
    @warming_times << time
  end

  def record_preload(count, time)
    @preload_operations += 1
    @preload_items += count
    @preload_times << time
  end

  def hit_ratio
    total = @hits + @misses
    return 0.0 if total == 0
    (@hits.to_f / total * 100).round(2)
  end

  def average_response_time
    return 0.0 if @hit_times.empty?
    (@hit_times.sum / @hit_times.size * 1000).round(2) # in milliseconds
  end

  def to_hash
    {
      hits: @hits,
      misses: @misses,
      writes: @writes,
      deletions: @deletions,
      errors: @errors,
      generations: @generations,
      hit_ratio: hit_ratio,
      average_response_time: average_response_time,
      layer_stats: @layer_stats,
      type_stats: @type_stats,
      warming: {
        operations: @warming_operations,
        items: @warming_items,
        average_time: @warming_times.empty? ? 0 : @warming_times.sum / @warming_times.size
      },
      preload: {
        operations: @preload_operations,
        items: @preload_items,
        average_time: @preload_times.empty? ? 0 : @preload_times.sum / @preload_times.size
      }
    }
  end

  def reset!
    @hits = 0
    @misses = 0
    @writes = 0
    @deletions = 0
    @errors = 0
    @generations = 0
    @warming_operations = 0
    @warming_items = 0
    @preload_operations = 0
    @preload_items = 0

    @hit_times = []
    @miss_times = []
    @generation_times = []
    @warming_times = []
    @preload_times = []
    @error_log = []

    @layer_stats = Hash.new { |h, k| h[k] = { hits: 0, writes: 0, deletions: 0, errors: 0 } }
    @type_stats = Hash.new { |h, k| h[k] = { hits: 0, misses: 0, writes: 0, generations: 0 } }
  end
end
