# frozen_string_literal: true

# Global exception handling and error tracking configuration

# Define the exception tracking module first
module ExceptionTracking
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def track_exceptions
      rescue_from StandardError do |exception|
        # Track the error
        ErrorTrackingService.track_error(exception, {
          controller: self.class.name,
          action: action_name,
          params: params.except(:controller, :action, :format),
          user_id: current_user&.id,
          organization_id: current_user&.organization_id,
          request_id: request.uuid,
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          referer: request.referer,
          url: request.url,
          method: request.method
        })
        
        # Re-raise for normal error handling
        raise exception
      end
    end
  end
end

Rails.application.configure do
  # Enable detailed error reports in development
  config.consider_all_requests_local = Rails.env.development?
  
  # Configure exception handling
  if Rails.env.production? || Rails.env.staging?
    # Set up global exception handler
    config.exceptions_app = proc do |env|
      ErrorHandlingController.action(:handle_error).call(env)
    end
  end
  
  # Configure error tracking for all environments
  config.after_initialize do
    # Set up global exception tracking
    setup_global_error_tracking
    
    # Set up ActiveJob error tracking
    setup_job_error_tracking
    
    # Set up ActionMailer error tracking
    setup_mailer_error_tracking
    
    # Set up database connection error tracking
    setup_database_error_tracking
  end
end

def setup_global_error_tracking
  # Include in ApplicationController
  ApplicationController.include(ExceptionTracking)
  ApplicationController.track_exceptions
end

def setup_job_error_tracking
  # Track ActiveJob errors
  ActiveJob::Base.around_perform do |job, block|
    begin
      block.call
    rescue => exception
      ErrorTrackingService.track_error(exception, {
        job_class: job.class.name,
        job_id: job.job_id,
        queue_name: job.queue_name,
        arguments: job.arguments,
        executions: job.executions,
        exception_executions: job.exception_executions
      })
      
      raise exception
    end
  end
  
  # Track job retry failures
  ActiveJob::Base.retry_on StandardError do |job, exception|
    if job.executions >= job.class.retry_attempts
      ErrorTrackingService.track_error(exception, {
        job_class: job.class.name,
        job_id: job.job_id,
        final_failure: true,
        total_executions: job.executions,
        arguments: job.arguments
      })
    end
  end
end

def setup_mailer_error_tracking
  # Track ActionMailer errors
  ActionMailer::Base.around_action do |controller, action, &block|
    begin
      block.call
    rescue => exception
      ErrorTrackingService.track_error(exception, {
        mailer_class: controller.class.name,
        mailer_action: action.method_name,
        mail_to: controller.instance_variable_get(:@_mail_was_called) ? controller.message.to : nil,
        mail_subject: controller.instance_variable_get(:@_mail_was_called) ? controller.message.subject : nil
      })
      
      raise exception
    end
  end
end

def setup_database_error_tracking
  # Track database connection errors
  ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
    if payload[:exception]
      exception = payload[:exception].last
      ErrorTrackingService.track_error(exception, {
        sql_query: payload[:sql],
        database_name: payload[:name],
        connection_id: payload[:connection]&.object_id,
        duration: ((finish - start) * 1000).round(2)
      })
    end
  end
  
  # Track slow queries as performance errors
  ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
    duration = ((finish - start) * 1000).round(2)
    
    # Track queries slower than 5 seconds as performance issues
    if duration > 5000 && payload[:name] != 'SCHEMA'
      ErrorTrackingService.track_custom_error(
        "Slow query detected: #{duration}ms",
        severity: :medium,
        category: :performance,
        context: {
          sql_query: payload[:sql],
          duration: duration,
          database_name: payload[:name],
          connection_id: payload[:connection]&.object_id
        }
      )
    end
  end
end

# ErrorHandlingController is defined in app/controllers/error_handling_controller.rb

# Set up periodic error cleanup
if defined?(Cron) # If using whenever gem or similar
  # Clean up old errors weekly
  Rails.application.configure do
    config.after_initialize do
      # Schedule cleanup job if we're in a job processing environment
      if defined?(Solid::Queue) || ENV['CLEANUP_ERRORS'] == 'true'
        ErrorCleanupJob.perform_later
      end
    end
  end
end

# Health check endpoint integration
Rails.application.routes.append do
  get '/health/errors', to: proc {
    error_health = ErrorReport.error_health_score
    recent_critical = ErrorReport.where('occurred_at > ?', 1.hour.ago)
                                .where(severity: 'critical')
                                .count
    
    status = if error_health >= 90 && recent_critical.zero?
               200
             elsif error_health >= 70 && recent_critical < 3
               200 # Warning but still healthy
             else
               503 # Service degraded
             end
    
    [status, { 'Content-Type' => 'application/json' }, [
      {
        error_health_score: error_health,
        recent_critical_errors: recent_critical,
        status: status == 200 ? 'healthy' : 'degraded',
        timestamp: Time.current.iso8601
      }.to_json
    ]]
  }
end