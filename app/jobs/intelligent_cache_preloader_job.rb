class IntelligentCachePreloaderJob < ApplicationJob
  queue_as :caching
  
  def perform(options = {})
    cache_service = AdvancedCachingService.instance
    preload_strategy = options[:strategy] || 'predictive'
    
    begin
      start_time = Time.current
      
      case preload_strategy
      when 'predictive'
        preload_predictive_data(cache_service, options)
      when 'user_behavior'
        preload_based_on_user_behavior(cache_service, options)
      when 'business_hours'
        preload_for_business_hours(cache_service, options)
      when 'seasonal'
        preload_seasonal_data(cache_service, options)
      else
        preload_critical_data(cache_service, options)
      end
      
      preload_time = Time.current - start_time
      Rails.logger.info "Intelligent cache preloading completed (#{preload_strategy}) in #{preload_time.round(2)}s"
      
      # Schedule next preload cycle
      schedule_next_preload(preload_strategy, options) if options[:recurring]
      
    rescue => e
      Rails.logger.error "Intelligent cache preloader failed (#{preload_strategy}): #{e.message}"
      raise
    end
  end
  
  private
  
  def preload_predictive_data(cache_service, options)
    # Analyze access patterns and preload likely-to-be-accessed data
    popular_applications = analyze_popular_applications
    trending_quotes = analyze_trending_quotes
    active_organizations = analyze_active_organizations
    
    Rails.logger.info "Preloading predictive data: #{popular_applications.size} apps, #{trending_quotes.size} quotes, #{active_organizations.size} orgs"
    
    # Preload popular insurance applications
    popular_applications.each do |app_id|
      cache_service.intelligent_preload(:application_data, app_id, priority: :high)
    end
    
    # Preload trending quotes
    trending_quotes.each do |quote_id|
      cache_service.intelligent_preload(:quote_data, quote_id, priority: :medium)
    end
    
    # Preload active organizations
    active_organizations.each do |org_id|
      cache_service.intelligent_preload(:organization_data, org_id, priority: :medium)
    end
  end
  
  def preload_based_on_user_behavior(cache_service, options)
    # Preload based on recent user access patterns
    user_patterns = analyze_user_access_patterns
    
    Rails.logger.info "Preloading based on user behavior: #{user_patterns.size} patterns identified"
    
    user_patterns.each do |pattern|
      case pattern[:type]
      when 'frequent_application_access'
        cache_service.intelligent_preload(:application_data, pattern[:resource_id], 
                                        priority: :high, ttl: 2.hours)
      when 'document_downloads'
        cache_service.intelligent_preload(:document_data, pattern[:resource_id],
                                        priority: :medium, ttl: 1.hour)
      when 'dashboard_views'
        preload_dashboard_data(cache_service, pattern[:user_id])
      end
    end
  end
  
  def preload_for_business_hours(cache_service, options)
    # Preload data commonly accessed during business hours
    current_hour = Time.current.hour
    
    if business_hours_starting_soon?(current_hour)
      Rails.logger.info "Preloading for business hours start"
      
      # Preload dashboard data
      preload_dashboard_aggregates(cache_service)
      
      # Preload recent applications and quotes
      preload_recent_business_data(cache_service)
      
      # Preload user session data for active users
      preload_active_user_sessions(cache_service)
      
    elsif business_hours_ending_soon?(current_hour)
      Rails.logger.info "Preloading for business hours end"
      
      # Preload end-of-day reports
      preload_daily_reports(cache_service)
      
      # Cache daily statistics
      preload_daily_statistics(cache_service)
    end
  end
  
  def preload_seasonal_data(cache_service, options)
    # Preload data based on seasonal insurance patterns
    current_season = determine_insurance_season
    
    Rails.logger.info "Preloading seasonal data for: #{current_season}"
    
    case current_season
    when 'auto_renewal_season'
      preload_auto_insurance_data(cache_service)
    when 'home_buying_season'
      preload_property_insurance_data(cache_service)
    when 'business_year_end'
      preload_commercial_insurance_data(cache_service)
    when 'health_enrollment'
      preload_health_insurance_data(cache_service)
    end
  end
  
  def preload_critical_data(cache_service, options)
    # Fallback: preload essential system data
    Rails.logger.info "Preloading critical system data"
    
    # Preload system configurations
    cache_service.intelligent_preload(:system_config, 'global', priority: :critical)
    
    # Preload active user sessions
    User.active_within(30.minutes).limit(100).find_each do |user|
      cache_service.intelligent_preload(:user_session, user.id, priority: :high)
    end
    
    # Preload recent applications
    InsuranceApplication.recent.limit(50).find_each do |app|
      cache_service.intelligent_preload(:application_data, app.id, priority: :medium)
    end
  end
  
  def analyze_popular_applications
    # Analyze application access patterns from cache statistics
    Rails.cache.fetch('popular_applications_analysis', expires_in: 30.minutes) do
      # Get most accessed applications from the last 24 hours
      InsuranceApplication
        .joins(:audit_logs)
        .where(audit_logs: { created_at: 24.hours.ago.. })
        .where(audit_logs: { action: 'read' })
        .group(:id)
        .order('COUNT(audit_logs.id) DESC')
        .limit(20)
        .pluck(:id)
    end
  end
  
  def analyze_trending_quotes
    # Find quotes with increasing access patterns
    Rails.cache.fetch('trending_quotes_analysis', expires_in: 30.minutes) do
      Quote
        .where(created_at: 7.days.ago..)
        .where('access_count > ?', 5)
        .order(access_count: :desc, updated_at: :desc)
        .limit(15)
        .pluck(:id)
    end
  end
  
  def analyze_active_organizations
    # Identify organizations with high current activity
    Rails.cache.fetch('active_organizations_analysis', expires_in: 1.hour) do
      Organization
        .joins(:users)
        .where(users: { last_sign_in_at: 2.hours.ago.. })
        .distinct
        .limit(10)
        .pluck(:id)
    end
  end
  
  def analyze_user_access_patterns
    # Analyze user behavior patterns for intelligent preloading
    Rails.cache.fetch('user_access_patterns', expires_in: 1.hour) do
      patterns = []
      
      # Find users with frequent application access
      frequent_app_users = AuditLog
        .where(created_at: 24.hours.ago..)
        .where(auditable_type: 'InsuranceApplication', action: 'read')
        .group(:user_id, :auditable_id)
        .having('COUNT(*) >= ?', 3)
        .pluck(:user_id, :auditable_id, 'COUNT(*)')
      
      frequent_app_users.each do |user_id, app_id, count|
        patterns << {
          type: 'frequent_application_access',
          user_id: user_id,
          resource_id: app_id,
          frequency: count
        }
      end
      
      # Find frequent document downloads
      document_patterns = AuditLog
        .where(created_at: 4.hours.ago..)
        .where(auditable_type: 'Document', action: 'download')
        .group(:auditable_id)
        .having('COUNT(*) >= ?', 2)
        .pluck(:auditable_id, 'COUNT(*)')
      
      document_patterns.each do |doc_id, count|
        patterns << {
          type: 'document_downloads',
          resource_id: doc_id,
          frequency: count
        }
      end
      
      patterns
    end
  end
  
  def preload_dashboard_data(cache_service, user_id)
    # Preload user-specific dashboard data
    cache_service.intelligent_preload(:user_dashboard, user_id, priority: :high)
    cache_service.intelligent_preload(:user_metrics, user_id, priority: :medium)
    cache_service.intelligent_preload(:user_recent_activity, user_id, priority: :medium)
  end
  
  def preload_dashboard_aggregates(cache_service)
    # Preload common dashboard aggregates
    cache_service.intelligent_preload(:daily_metrics, Date.current.to_s, priority: :high)
    cache_service.intelligent_preload(:weekly_summary, Date.current.cweek.to_s, priority: :medium)
    cache_service.intelligent_preload(:monthly_summary, Date.current.month.to_s, priority: :medium)
  end
  
  def preload_recent_business_data(cache_service)
    # Preload recent applications and quotes likely to be accessed
    InsuranceApplication.recent.limit(30).find_each do |app|
      cache_service.intelligent_preload(:application_data, app.id, priority: :medium)
    end
    
    Quote.where(created_at: 24.hours.ago..).limit(20).find_each do |quote|
      cache_service.intelligent_preload(:quote_data, quote.id, priority: :low)
    end
  end
  
  def preload_active_user_sessions(cache_service)
    # Preload session data for recently active users
    User.active_within(1.hour).limit(50).find_each do |user|
      cache_service.intelligent_preload(:user_session, user.id, priority: :high, ttl: 2.hours)
    end
  end
  
  def preload_daily_reports(cache_service)
    # Preload end-of-day report data
    cache_service.intelligent_preload(:daily_report, Date.current.to_s, priority: :medium)
    cache_service.intelligent_preload(:application_summary, Date.current.to_s, priority: :medium)
  end
  
  def preload_daily_statistics(cache_service)
    # Preload daily statistics
    cache_service.intelligent_preload(:daily_stats, Date.current.to_s, priority: :low)
  end
  
  def business_hours_starting_soon?(hour)
    # Check if business hours are starting in the next hour (8 AM)
    hour >= 7 && hour < 9
  end
  
  def business_hours_ending_soon?(hour)
    # Check if business hours are ending soon (5-6 PM)
    hour >= 17 && hour < 19
  end
  
  def determine_insurance_season
    month = Date.current.month
    
    case month
    when 1, 2, 12 # Winter - auto renewals
      'auto_renewal_season'
    when 3, 4, 5 # Spring - home buying
      'home_buying_season'
    when 6, 7, 8 # Summer - general activity
      'general_season'
    when 9, 10, 11 # Fall - business year-end, health enrollment
      if month == 11
        'health_enrollment'
      else
        'business_year_end'
      end
    end
  end
  
  def preload_auto_insurance_data(cache_service)
    # Preload auto insurance related data
    InsuranceApplication.where(policy_type: 'auto').recent.limit(30).find_each do |app|
      cache_service.intelligent_preload(:application_data, app.id, priority: :medium)
    end
  end
  
  def preload_property_insurance_data(cache_service)
    # Preload property insurance data
    InsuranceApplication.where(policy_type: 'property').recent.limit(20).find_each do |app|
      cache_service.intelligent_preload(:application_data, app.id, priority: :medium)
    end
  end
  
  def preload_commercial_insurance_data(cache_service)
    # Preload commercial insurance data
    InsuranceApplication.where(policy_type: 'commercial').recent.limit(25).find_each do |app|
      cache_service.intelligent_preload(:application_data, app.id, priority: :medium)
    end
  end
  
  def preload_health_insurance_data(cache_service)
    # Preload health insurance data
    InsuranceApplication.where(policy_type: 'health').recent.limit(40).find_each do |app|
      cache_service.intelligent_preload(:application_data, app.id, priority: :high)
    end
  end
  
  def schedule_next_preload(strategy, options)
    interval = case strategy
               when 'predictive' then 2.hours
               when 'user_behavior' then 30.minutes
               when 'business_hours' then 1.hour
               when 'seasonal' then 6.hours
               else 1.hour
               end
    
    self.class.set(wait: interval).perform_later(options)
  end
end