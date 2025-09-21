class CacheWarmingScheduler
  include Singleton

  # Warming strategies and their priorities
  WARMING_STRATEGIES = {
    critical: { priority: 1, interval: 15.minutes },
    business_hours: { priority: 2, interval: 30.minutes },
    predictive: { priority: 3, interval: 1.hour },
    user_behavior: { priority: 4, interval: 45.minutes },
    seasonal: { priority: 5, interval: 4.hours }
  }.freeze

  # System load thresholds
  LOAD_THRESHOLDS = {
    low: 0.3,
    medium: 0.6,
    high: 0.8
  }.freeze

  def initialize
    @running_jobs = Set.new
    @last_system_check = Time.current
    @warming_statistics = CacheWarmingStatistics.new
  end

  # Start the warming scheduler
  def start_scheduler
    Rails.logger.info "Starting Cache Warming Scheduler"

    schedule_initial_warmups
    schedule_intelligent_preloading
    schedule_cdn_cache_warming
    schedule_maintenance_tasks

    true
  end

  # Schedule cache warming based on current system state
  def schedule_warming(strategy, options = {})
    return false unless should_schedule_warming?(strategy)

    system_load = current_system_load
    priority = calculate_priority(strategy, system_load, options)

    job_options = build_job_options(strategy, priority, options)

    case strategy
    when :critical
      schedule_critical_warming(job_options)
    when :business_hours
      schedule_business_hours_warming(job_options)
    when :predictive
      schedule_predictive_warming(job_options)
    when :user_behavior
      schedule_user_behavior_warming(job_options)
    when :seasonal
      schedule_seasonal_warming(job_options)
    else
      schedule_general_warming(job_options)
    end

    track_scheduled_job(strategy, job_options)

    true
  end

  # Force immediate cache warming for critical data
  def force_warm_critical_data
    Rails.logger.info "Force warming critical data"

    CacheWarmingJob.perform_now(:critical_system_data, {
      priority: :immediate,
      force: true
    })

    @warming_statistics.record_force_warming(:critical)
  end

  # Adaptive warming based on current usage patterns
  def adaptive_warming
    current_load = current_system_load
    time_context = current_time_context
    usage_patterns = analyze_current_usage

    Rails.logger.info "Adaptive warming: load=#{current_load}, context=#{time_context}, patterns=#{usage_patterns.size}"

    # Adjust warming strategy based on context
    strategy = determine_optimal_strategy(current_load, time_context, usage_patterns)

    schedule_warming(strategy, {
      adaptive: true,
      context: time_context,
      usage_patterns: usage_patterns
    })
  end

  # Check and optimize current warming jobs
  def optimize_warming_jobs
    cleanup_completed_jobs
    rebalance_job_priorities
    adjust_intervals_based_on_performance

    Rails.logger.info "Warming job optimization completed"
  end

  # Get warming statistics and performance metrics
  def warming_statistics
    {
      active_jobs: @running_jobs.size,
      completed_jobs: @warming_statistics.completed_jobs,
      success_rate: @warming_statistics.success_rate,
      average_warming_time: @warming_statistics.average_warming_time,
      cache_hit_improvement: @warming_statistics.cache_hit_improvement,
      last_optimization: @warming_statistics.last_optimization,
      system_load_impact: calculate_system_load_impact
    }
  end

  private

  def schedule_initial_warmups
    # Schedule critical system data warming
    CacheWarmingJob.set(wait: 30.seconds).perform_later(
      :critical_system_data,
      { priority: :high, initial: true }
    )

    # Schedule user session preloading
    CacheWarmingJob.set(wait: 1.minute).perform_later(
      :user_sessions,
      { priority: :medium, initial: true }
    )
  end

  def schedule_intelligent_preloading
    # Start intelligent preloader with predictive strategy
    IntelligentCachePreloaderJob.set(wait: 2.minutes).perform_later({
      strategy: "predictive",
      recurring: true,
      initial: true
    })

    # Schedule user behavior analysis
    IntelligentCachePreloaderJob.set(wait: 5.minutes).perform_later({
      strategy: "user_behavior",
      recurring: true
    })
  end

  def schedule_cdn_cache_warming
    return unless cdn_enabled?

    # Warm CDN cache for static assets
    WarmCdnCacheJob.set(wait: 3.minutes).perform_later(
      static_asset_urls,
      { priority: :medium, cache_type: :static }
    )

    # Warm CDN cache for frequently accessed media
    WarmCdnCacheJob.set(wait: 10.minutes).perform_later(
      popular_media_urls,
      { priority: :low, cache_type: :media }
    )
  end

  def schedule_maintenance_tasks
    # Schedule daily cache cleanup
    CacheCleanupJob.set(wait: next_maintenance_window).perform_later({
      cleanup_type: :expired_entries,
      aggressive: false
    })

    # Schedule weekly cache optimization
    CacheOptimizationJob.set(wait: next_weekly_optimization).perform_later({
      optimization_type: :full,
      rebalance_layers: true
    })
  end

  def should_schedule_warming?(strategy)
    return false if system_overloaded?
    return false if strategy_recently_executed?(strategy)
    return false if max_concurrent_jobs_reached?

    true
  end

  def current_system_load
    # Calculate system load based on various metrics
    cpu_load = get_cpu_load
    memory_usage = get_memory_usage
    cache_performance = get_cache_performance

    # Weighted average of different load indicators
    (cpu_load * 0.4 + memory_usage * 0.3 + cache_performance * 0.3).round(2)
  end

  def calculate_priority(strategy, system_load, options)
    base_priority = WARMING_STRATEGIES[strategy][:priority]

    # Adjust priority based on system load
    if system_load < LOAD_THRESHOLDS[:low]
      base_priority - 1
    elsif system_load > LOAD_THRESHOLDS[:high]
      base_priority + 2
    else
      base_priority
    end
  end

  def build_job_options(strategy, priority, options)
    {
      strategy: strategy,
      priority: priority,
      system_load: current_system_load,
      scheduled_at: Time.current,
      options: options
    }
  end

  def schedule_critical_warming(job_options)
    CacheWarmingJob.set(priority: 0).perform_later(
      :critical_system_data,
      job_options
    )
  end

  def schedule_business_hours_warming(job_options)
    IntelligentCachePreloaderJob.set(priority: 5).perform_later(
      job_options.merge(strategy: "business_hours")
    )
  end

  def schedule_predictive_warming(job_options)
    IntelligentCachePreloaderJob.set(priority: 10).perform_later(
      job_options.merge(strategy: "predictive")
    )
  end

  def schedule_user_behavior_warming(job_options)
    IntelligentCachePreloaderJob.set(priority: 15).perform_later(
      job_options.merge(strategy: "user_behavior")
    )
  end

  def schedule_seasonal_warming(job_options)
    IntelligentCachePreloaderJob.set(priority: 20).perform_later(
      job_options.merge(strategy: "seasonal")
    )
  end

  def schedule_general_warming(job_options)
    CacheWarmingJob.set(priority: 25).perform_later(
      :general_data,
      job_options
    )
  end

  def track_scheduled_job(strategy, job_options)
    job_id = SecureRandom.uuid
    @running_jobs.add({
      id: job_id,
      strategy: strategy,
      scheduled_at: job_options[:scheduled_at],
      priority: job_options[:priority]
    })

    @warming_statistics.record_scheduled_job(strategy, job_options)
  end

  def current_time_context
    hour = Time.current.hour
    day_of_week = Time.current.wday

    if weekend?(day_of_week)
      :weekend
    elsif business_hours?(hour)
      :business_hours
    elsif after_hours?(hour)
      :after_hours
    else
      :early_morning
    end
  end

  def analyze_current_usage
    Rails.cache.fetch("current_usage_analysis", expires_in: 10.minutes) do
      {
        active_users: User.active_within(30.minutes).count,
        recent_requests: AuditLog.where(created_at: 15.minutes.ago..).count,
        cache_hit_ratio: AdvancedCachingService.instance.current_hit_ratio,
        popular_resources: get_popular_resources_last_hour
      }
    end
  end

  def determine_optimal_strategy(load, context, patterns)
    # Determine the best warming strategy based on current conditions
    if load > LOAD_THRESHOLDS[:high]
      :critical
    elsif context == :business_hours && patterns[:active_users] > 50
      :user_behavior
    elsif context == :early_morning
      :business_hours
    elsif patterns[:cache_hit_ratio] < 0.7
      :predictive
    else
      :seasonal
    end
  end

  def cleanup_completed_jobs
    @running_jobs.delete_if { |job| job_completed?(job[:id]) }
  end

  def rebalance_job_priorities
    # Rebalance job priorities based on current system state
    return if @running_jobs.empty?

    current_load = current_system_load

    @running_jobs.each do |job|
      new_priority = calculate_priority(job[:strategy], current_load, {})
      update_job_priority(job[:id], new_priority) if new_priority != job[:priority]
    end
  end

  def adjust_intervals_based_on_performance
    # Adjust warming intervals based on cache performance
    hit_ratio = AdvancedCachingService.instance.current_hit_ratio

    if hit_ratio < 0.6
      # Increase warming frequency
      decrease_warming_intervals
    elsif hit_ratio > 0.9
      # Decrease warming frequency
      increase_warming_intervals
    end
  end

  def calculate_system_load_impact
    # Calculate how much warming jobs are impacting system performance
    base_load = get_baseline_system_load
    current_load = current_system_load

    ((current_load - base_load) / base_load * 100).round(2)
  end

  def system_overloaded?
    current_system_load > LOAD_THRESHOLDS[:high]
  end

  def strategy_recently_executed?(strategy)
    last_execution = @warming_statistics.last_execution(strategy)
    return false unless last_execution

    min_interval = WARMING_STRATEGIES[strategy][:interval]
    Time.current - last_execution < min_interval
  end

  def max_concurrent_jobs_reached?
    @running_jobs.size >= max_concurrent_warming_jobs
  end

  def max_concurrent_warming_jobs
    # Adjust based on system resources
    case current_system_load
    when 0..LOAD_THRESHOLDS[:low]
      8
    when LOAD_THRESHOLDS[:low]..LOAD_THRESHOLDS[:medium]
      5
    when LOAD_THRESHOLDS[:medium]..LOAD_THRESHOLDS[:high]
      3
    else
      1
    end
  end

  def get_cpu_load
    # Simplified CPU load calculation (would use system metrics in production)
    Rails.cache.fetch("cpu_load", expires_in: 30.seconds) do
      # Mock calculation - in production, use system metrics
      rand(0.1..0.9)
    end
  end

  def get_memory_usage
    # Simplified memory usage calculation
    Rails.cache.fetch("memory_usage", expires_in: 30.seconds) do
      # Mock calculation - in production, use system metrics
      rand(0.2..0.8)
    end
  end

  def get_cache_performance
    # Cache performance metric (miss ratio affects system load)
    hit_ratio = AdvancedCachingService.instance.current_hit_ratio
    1.0 - hit_ratio # Convert hit ratio to load indicator
  end

  def cdn_enabled?
    CdnService.instance.respond_to?(:enabled?) && CdnService.instance.enabled?
  end

  def static_asset_urls
    # Get URLs for static assets that should be CDN cached
    %w[
      /assets/application.css
      /assets/application.js
      /assets/logo.png
      /assets/favicon.ico
    ]
  end

  def popular_media_urls
    # Get URLs for popular media files
    Rails.cache.fetch("popular_media_urls", expires_in: 1.hour) do
      # In production, this would query actual popular media
      Document.where(content_type: [ "image/", "video/" ]).popular.limit(20).pluck(:url)
    end
  end

  def next_maintenance_window
    # Calculate next maintenance window (typically early morning)
    tomorrow_4am = Time.current.beginning_of_day + 1.day + 4.hours
    tomorrow_4am > Time.current ? tomorrow_4am - Time.current : tomorrow_4am + 1.day - Time.current
  end

  def next_weekly_optimization
    # Schedule weekly optimization for Sunday 2 AM
    next_sunday = Time.current.beginning_of_week + 1.week + 2.hours
    next_sunday - Time.current
  end

  def weekend?(day_of_week)
    day_of_week == 0 || day_of_week == 6 # Sunday or Saturday
  end

  def business_hours?(hour)
    hour >= 9 && hour <= 17
  end

  def after_hours?(hour)
    hour >= 18 && hour <= 23
  end

  def get_popular_resources_last_hour
    Rails.cache.fetch("popular_resources_last_hour", expires_in: 15.minutes) do
      AuditLog
        .where(created_at: 1.hour.ago..)
        .group(:auditable_type, :auditable_id)
        .order("COUNT(*) DESC")
        .limit(10)
        .pluck(:auditable_type, :auditable_id, "COUNT(*)")
    end
  end

  def job_completed?(job_id)
    # Check if job is completed (simplified implementation)
    !ActiveJob::Base.queue_adapter.queues.any? { |queue| queue.include?(job_id) }
  end

  def update_job_priority(job_id, new_priority)
    # Update job priority in queue (implementation depends on queue adapter)
    Rails.logger.debug "Updating job #{job_id} priority to #{new_priority}"
  end

  def decrease_warming_intervals
    # Temporarily decrease warming intervals to improve cache hit ratio
    Rails.logger.info "Decreasing cache warming intervals due to low hit ratio"
  end

  def increase_warming_intervals
    # Increase warming intervals to reduce system load
    Rails.logger.info "Increasing cache warming intervals due to high hit ratio"
  end

  def get_baseline_system_load
    # Get baseline system load without warming jobs
    Rails.cache.fetch("baseline_system_load", expires_in: 1.hour) do
      0.3 # Mock baseline - in production, measure actual baseline
    end
  end
end

# Statistics tracking for cache warming performance
class CacheWarmingStatistics
  def initialize
    @job_history = []
    @performance_metrics = {}
    @last_optimization = Time.current
  end

  def record_scheduled_job(strategy, options)
    @job_history << {
      strategy: strategy,
      scheduled_at: options[:scheduled_at],
      priority: options[:priority],
      system_load: options[:system_load]
    }

    # Keep only last 1000 entries
    @job_history = @job_history.last(1000) if @job_history.size > 1000
  end

  def record_force_warming(strategy)
    @performance_metrics[:force_warmings] ||= {}
    @performance_metrics[:force_warmings][strategy] ||= 0
    @performance_metrics[:force_warmings][strategy] += 1
  end

  def completed_jobs
    @job_history.count { |job| job[:completed_at] }
  end

  def success_rate
    return 0.0 if completed_jobs == 0

    successful_jobs = @job_history.count { |job| job[:success] }
    (successful_jobs.to_f / completed_jobs * 100).round(2)
  end

  def average_warming_time
    completed_with_time = @job_history.select { |job| job[:warming_time] }
    return 0.0 if completed_with_time.empty?

    total_time = completed_with_time.sum { |job| job[:warming_time] }
    (total_time / completed_with_time.size).round(2)
  end

  def cache_hit_improvement
    # Calculate cache hit ratio improvement from warming
    @performance_metrics[:cache_hit_improvement] || 0.0
  end

  def last_optimization
    @last_optimization
  end

  def last_execution(strategy)
    last_job = @job_history.reverse.find { |job| job[:strategy] == strategy }
    last_job&.dig(:scheduled_at)
  end
end
