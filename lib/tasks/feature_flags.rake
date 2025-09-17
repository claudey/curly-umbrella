namespace :feature_flags do
  desc "Seed initial feature flags"
  task seed: :environment do
    puts "🚀 Seeding initial feature flags..."
    
    flags = [
      {
        key: 'new_dashboard_ui',
        name: 'New Dashboard UI',
        description: 'Enable the redesigned dashboard with improved user experience',
        enabled: false,
        percentage: nil
      },
      {
        key: 'advanced_analytics',
        name: 'Advanced Analytics',
        description: 'Enable advanced analytics and reporting features',
        enabled: true,
        percentage: 100
      },
      {
        key: 'api_v2',
        name: 'API Version 2',
        description: 'Enable access to API version 2 endpoints',
        enabled: false,
        percentage: 25
      },
      {
        key: 'real_time_notifications',
        name: 'Real-time Notifications',
        description: 'Enable real-time push notifications for users',
        enabled: true,
        percentage: 75
      },
      {
        key: 'document_ai_processing',
        name: 'AI Document Processing',
        description: 'Enable AI-powered document analysis and processing',
        enabled: false,
        percentage: 10
      },
      {
        key: 'enhanced_security',
        name: 'Enhanced Security Features',
        description: 'Enable additional security features and monitoring',
        enabled: true,
        percentage: 100
      },
      {
        key: 'mobile_app_integration',
        name: 'Mobile App Integration',
        description: 'Enable mobile app specific features and endpoints',
        enabled: false,
        percentage: nil
      },
      {
        key: 'beta_features',
        name: 'Beta Features Access',
        description: 'Enable access to beta features for testing',
        enabled: false,
        percentage: 5
      },
      {
        key: 'performance_monitoring',
        name: 'Performance Monitoring',
        description: 'Enable detailed performance monitoring and metrics',
        enabled: true,
        percentage: 100
      },
      {
        key: 'automated_workflows',
        name: 'Automated Workflows',
        description: 'Enable automated workflow processing for applications',
        enabled: false,
        percentage: 50
      }
    ]
    
    ActsAsTenant.without_tenant do
      flags.each do |flag_data|
        flag = FeatureFlag.find_or_initialize_by(key: flag_data[:key])
        
        if flag.new_record?
          flag.assign_attributes(flag_data)
          flag.metadata = { 
            seeded_at: Time.current,
            category: determine_category(flag_data[:key])
          }
          
          if flag.save
            puts "✅ Created feature flag: #{flag.key}"
          else
            puts "❌ Failed to create feature flag: #{flag.key} - #{flag.errors.full_messages.join(', ')}"
          end
        else
          puts "⚠️  Feature flag already exists: #{flag.key}"
        end
      end
    end
    
    puts "🎉 Feature flags seeding completed!"
    puts "📊 Total flags: #{FeatureFlag.count}"
    puts "🟢 Enabled flags: #{FeatureFlag.enabled.count}"
    puts "🔴 Disabled flags: #{FeatureFlag.disabled.count}"
  end
  
  desc "List all feature flags"
  task list: :environment do
    puts "📋 Feature Flags Status:"
    puts "=" * 80
    
    ActsAsTenant.without_tenant do
      FeatureFlag.order(:name).each do |flag|
        status = flag.enabled? ? "🟢 ENABLED" : "🔴 DISABLED"
        percentage = flag.percentage ? " (#{flag.percentage}%)" : ""
        
        puts "#{status}#{percentage} - #{flag.key}"
        puts "  Name: #{flag.name}"
        puts "  Description: #{flag.description}"
        puts "  User Groups: #{flag.user_groups.join(', ')}" if flag.user_groups.any?
        puts "  Conditions: #{flag.conditions}" if flag.conditions.any?
        puts "  Created: #{flag.created_at.strftime('%Y-%m-%d')}"
        puts "-" * 80
      end
    end
    
    stats = FeatureFlagService.instance.flags_by_status
    puts "\n📊 Summary:"
    puts "Total flags: #{stats[:enabled] + stats[:disabled]}"
    puts "Enabled: #{stats[:enabled]}"
    puts "Disabled: #{stats[:disabled]}"
    puts "Percentage rollout: #{stats[:percentage_rollout]}"
    puts "Group-based: #{stats[:group_based]}"
  end
  
  desc "Enable a feature flag"
  task :enable, [:key] => :environment do |t, args|
    if args[:key].blank?
      puts "❌ Please provide a feature flag key: rake feature_flags:enable[key_name]"
      exit 1
    end
    
    ActsAsTenant.without_tenant do
      flag = FeatureFlag.find_by(key: args[:key])
      
      if flag
        flag.update!(enabled: true)
        FeatureFlagService.instance.clear_cache
        puts "✅ Enabled feature flag: #{args[:key]}"
      else
        puts "❌ Feature flag not found: #{args[:key]}"
        exit 1
      end
    end
  end
  
  desc "Disable a feature flag"
  task :disable, [:key] => :environment do |t, args|
    if args[:key].blank?
      puts "❌ Please provide a feature flag key: rake feature_flags:disable[key_name]"
      exit 1
    end
    
    ActsAsTenant.without_tenant do
      flag = FeatureFlag.find_by(key: args[:key])
      
      if flag
        flag.update!(enabled: false)
        FeatureFlagService.instance.clear_cache
        puts "✅ Disabled feature flag: #{args[:key]}"
      else
        puts "❌ Feature flag not found: #{args[:key]}"
        exit 1
      end
    end
  end
  
  desc "Set percentage rollout for a feature flag"
  task :set_percentage, [:key, :percentage] => :environment do |t, args|
    if args[:key].blank? || args[:percentage].blank?
      puts "❌ Please provide key and percentage: rake feature_flags:set_percentage[key_name,50]"
      exit 1
    end
    
    percentage = args[:percentage].to_i
    if percentage < 0 || percentage > 100
      puts "❌ Percentage must be between 0 and 100"
      exit 1
    end
    
    ActsAsTenant.without_tenant do
      flag = FeatureFlag.find_by(key: args[:key])
      
      if flag
        flag.update!(enabled: true, percentage: percentage)
        FeatureFlagService.instance.clear_cache
        puts "✅ Set #{args[:key]} to #{percentage}% rollout"
      else
        puts "❌ Feature flag not found: #{args[:key]}"
        exit 1
      end
    end
  end
  
  desc "Export feature flags to JSON"
  task export: :environment do
    ActsAsTenant.without_tenant do
      flags_data = FeatureFlagService.instance.export_flags
      filename = "feature_flags_export_#{Date.current.strftime('%Y%m%d')}.json"
      
      File.write(filename, JSON.pretty_generate({
        exported_at: Time.current,
        total_count: flags_data.length,
        flags: flags_data
      }))
      
      puts "✅ Exported #{flags_data.length} feature flags to #{filename}"
    end
  end
  
  desc "Clear feature flags cache"
  task clear_cache: :environment do
    FeatureFlagService.instance.clear_cache
    puts "✅ Feature flags cache cleared"
  end
  
  desc "Health check for feature flag system"
  task health: :environment do
    health_data = FeatureFlagService.instance.health_check
    
    puts "🏥 Feature Flag System Health Check"
    puts "=" * 50
    puts "Total flags: #{health_data[:total_flags]}"
    puts "Enabled flags: #{health_data[:enabled_flags]}"
    puts "Cache size: #{health_data[:cache_size]}"
    puts "Last updated: #{health_data[:last_updated]}"
    puts "System healthy: #{health_data[:system_healthy] ? '✅ YES' : '❌ NO'}"
    
    if health_data[:system_healthy]
      puts "\n🎉 All systems operational!"
    else
      puts "\n⚠️  System issues detected!"
      exit 1
    end
  end
  
  private
  
  def determine_category(key)
    case key
    when /ui|dashboard|interface/
      'ui'
    when /api|endpoint/
      'api'
    when /security|auth/
      'security'
    when /analytics|reporting|monitoring/
      'analytics'
    when /mobile|app/
      'mobile'
    when /beta|experimental/
      'experimental'
    when /workflow|automation/
      'automation'
    else
      'general'
    end
  end
end