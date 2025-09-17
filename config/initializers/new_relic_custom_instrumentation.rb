# frozen_string_literal: true

# New Relic Custom Instrumentation for BrokerSync
# This initializer sets up comprehensive monitoring for business-specific operations

if defined?(NewRelic::Agent) && NewRelic::Agent.config[:agent_enabled]
  Rails.application.configure do
    # Set up custom attributes for all requests
    config.middleware.use(Class.new do
      def initialize(app)
        @app = app
      end
      
      def call(env)
        request = ActionDispatch::Request.new(env)
        
        # Add request-level custom attributes
        NewRelic::Agent.add_custom_attributes({
          'request.method' => request.method,
          'request.path' => request.path,
          'request.ip' => request.remote_ip,
          'request.user_agent' => request.user_agent,
          'request.referer' => request.referer
        })
        
        # Track request start time for performance metrics
        start_time = Time.current
        
        begin
          status, headers, response = @app.call(env)
          
          # Calculate request duration
          duration = Time.current - start_time
          
          # Track API performance if this is an API endpoint
          if request.path.start_with?('/api/')
            NewRelicInstrumentationService.track_api_performance(
              request.path,
              request.method,
              duration,
              status,
              env['warden']&.user&.id
            )
          end
          
          # Add response attributes
          NewRelic::Agent.add_custom_attributes({
            'response.status' => status,
            'response.duration_ms' => (duration * 1000).round(2)
          })
          
          [status, headers, response]
        rescue => error
          # Track errors with enhanced context
          NewRelicInstrumentationService.track_application_error(error, {
            request_path: request.path,
            request_method: request.method,
            user_id: env['warden']&.user&.id,
            organization_id: env['warden']&.user&.organization_id,
            request_duration: Time.current - start_time
          })
          raise
        end
      end
    end)
  end
  
  # Instrument key business models
  Rails.application.config.after_initialize do
    # Instrument Application model methods
    if defined?(Application)
      NewRelicInstrumentationService.instrument_method(Application, :submit!, 'Custom/Application/submit')
      NewRelicInstrumentationService.instrument_method(Application, :approve!, 'Custom/Application/approve')
      NewRelicInstrumentationService.instrument_method(Application, :process_documents, 'Custom/Application/process_documents')
    end
    
    # Instrument Quote model methods
    if defined?(Quote)
      NewRelicInstrumentationService.instrument_method(Quote, :calculate_premium, 'Custom/Quote/calculate_premium')
      NewRelicInstrumentationService.instrument_method(Quote, :generate_proposal, 'Custom/Quote/generate_proposal')
    end
    
    # Instrument Document model methods
    if defined?(Document)
      NewRelicInstrumentationService.instrument_method(Document, :process_upload, 'Custom/Document/process_upload')
      NewRelicInstrumentationService.instrument_method(Document, :extract_metadata, 'Custom/Document/extract_metadata')
    end
    
    # Instrument PolicyDocument model methods
    if defined?(PolicyDocument)
      NewRelicInstrumentationService.instrument_method(PolicyDocument, :generate_pdf, 'Custom/PolicyDocument/generate_pdf')
    end
    
    # Add custom event tracking to business operations
    ActiveSupport::Notifications.subscribe('application.submitted') do |name, start, finish, id, payload|
      NewRelicInstrumentationService.track_application_submitted(payload[:application])
    end
    
    ActiveSupport::Notifications.subscribe('application.approved') do |name, start, finish, id, payload|
      processing_time = ((finish - start) / 1.hour).round(2)
      NewRelicInstrumentationService.track_application_approved(payload[:application], processing_time)
    end
    
    ActiveSupport::Notifications.subscribe('quote.generated') do |name, start, finish, id, payload|
      generation_time = finish - start
      NewRelicInstrumentationService.track_quote_generated(payload[:quote], generation_time)
    end
    
    ActiveSupport::Notifications.subscribe('document.processed') do |name, start, finish, id, payload|
      processing_time = finish - start
      NewRelicInstrumentationService.track_document_processed(payload[:document], processing_time)
    end
    
    # Track slow database queries
    ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      duration = finish - start
      
      # Only track slow queries (> 1 second)
      if duration > 1.0
        NewRelicInstrumentationService.track_slow_query(
          payload[:sql],
          duration,
          payload[:name]
        )
      end
    end
    
    # Track background job performance
    ActiveSupport::Notifications.subscribe('perform.active_job') do |name, start, finish, id, payload|
      duration = finish - start
      job = payload[:job]
      
      NewRelicInstrumentationService.track_job_performance(
        job.class.name,
        duration,
        'completed'
      )
    end
    
    # Track failed background jobs
    ActiveSupport::Notifications.subscribe('perform_start.active_job') do |name, start, finish, id, payload|
      # This will be used to track job start times
    end
    
    # Enhanced error tracking integration
    if defined?(ErrorTrackingService)
      # Monkey patch ErrorTrackingService to also send to New Relic
      ErrorTrackingService.class_eval do
        alias_method :original_track_error, :track_error
        
        def track_error(exception, context = {})
          # Call original method
          error_record = original_track_error(exception, context)
          
          # Handle both single record and array cases, but only if it's an actual record
          record_for_tracking = if error_record.is_a?(Array)
            error_record.first
          else
            error_record
          end
          
          # Only extract attributes if record_for_tracking responds to the methods (is an actual record)
          tracking_context = context.dup
          if record_for_tracking.respond_to?(:id) && !record_for_tracking.is_a?(ActiveSupport::Logger)
            tracking_context.merge!(
              error_record_id: record_for_tracking.id,
              severity: record_for_tracking.respond_to?(:severity) ? record_for_tracking.severity : nil,
              category: record_for_tracking.respond_to?(:category) ? record_for_tracking.category : nil
            )
          end
          
          # Also track in New Relic
          NewRelicInstrumentationService.track_application_error(exception, tracking_context)
          
          error_record
        end
      end
    end
    
    # Schedule periodic metrics collection
    if defined?(BusinessMetricsCollectionJob)
      # Enhance BusinessMetricsCollectionJob to report to New Relic
      BusinessMetricsCollectionJob.class_eval do
        after_perform do |job|
          # Record business metrics to New Relic after collection
          Rails.logger.info "Recording business metrics to New Relic"
          NewRelicInstrumentationService.record_application_metrics
        end
      end
    end
  end
  
  # Custom dashboard metrics collection
  NewRelic::Agent.add_custom_attributes({
    'app.name' => 'BrokerSync',
    'app.environment' => Rails.env,
    'app.version' => ENV['APP_VERSION'] || '1.0.0',
    'app.deployment_time' => ENV['DEPLOYMENT_TIME'] || Time.current.iso8601
  })
  
  # Periodic system health checks
  if Rails.env.production?
    # Schedule health metrics collection every 5 minutes
    Thread.new do
      loop do
        begin
          sleep(300) # 5 minutes
          NewRelicInstrumentationService.record_application_metrics
        rescue => e
          Rails.logger.error "Failed to record periodic New Relic metrics: #{e.message}"
        end
      end
    end
  end
  
  Rails.logger.info "New Relic custom instrumentation initialized for BrokerSync"
else
  Rails.logger.warn "New Relic agent not available or disabled - custom instrumentation skipped"
end

# Add method to controllers for easy custom tracking
module NewRelicControllerExtensions
  def track_business_event(event_name, attributes = {})
    # Add controller context
    enhanced_attributes = attributes.merge(
      controller: self.class.name,
      action: action_name,
      user_id: current_user&.id,
      organization_id: current_user&.organization_id
    )
    
    NewRelicInstrumentationService.track_business_event(event_name, enhanced_attributes)
  end
  
  def add_performance_attributes(attributes)
    NewRelicInstrumentationService.add_transaction_attributes(attributes)
  end
end

# Include in ApplicationController
if defined?(ApplicationController)
  ApplicationController.include(NewRelicControllerExtensions)
end