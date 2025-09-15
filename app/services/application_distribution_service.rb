class ApplicationDistributionService
  def initialize(application, options = {})
    @application = application
    @options = options
    @distributed_by = options[:distributed_by]
    @max_companies = options[:max_companies] || 5
    @distribution_method = options[:method] || 'automatic'
  end

  def distribute!
    return false unless @application.can_be_distributed?

    Rails.logger.info "Starting distribution for application #{@application.application_number}"

    begin
      # Find eligible companies
      eligible_companies = find_eligible_companies
      
      if eligible_companies.empty?
        Rails.logger.warn "No eligible companies found for application #{@application.application_number}"
        return false
      end

      # Create distributions
      distributions = create_distributions(eligible_companies)
      
      # Send notifications
      send_notifications(distributions)
      
      # Update application status
      update_application_status(distributions.count)
      
      # Schedule follow-up tasks
      schedule_follow_ups(distributions)
      
      Rails.logger.info "Successfully distributed application #{@application.application_number} to #{distributions.count} companies"
      
      {
        success: true,
        distributions_created: distributions.count,
        companies: eligible_companies.pluck(:name),
        distribution_ids: distributions.pluck(:id)
      }
      
    rescue StandardError => e
      Rails.logger.error "Distribution failed for application #{@application.application_number}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      {
        success: false,
        error: e.message
      }
    end
  end

  def self.auto_distribute_pending_applications
    pending_applications = InsuranceApplication.submitted
                                              .where(distributed_at: nil)
                                              .where('created_at > ?', 1.hour.ago)

    results = []
    
    pending_applications.find_each do |application|
      service = new(application, method: 'automatic')
      result = service.distribute!
      
      if result[:success]
        application.update!(distributed_at: Time.current)
      end
      
      results << {
        application_id: application.id,
        application_number: application.application_number,
        result: result
      }
    end

    results
  end

  def self.redistribute_application(application, options = {})
    # Mark existing distributions as expired
    existing_distributions = ApplicationDistribution.where(insurance_application: application)
                                                   .active
    existing_distributions.update_all(
      status: 'expired',
      expired_at: Time.current
    )

    # Create new distribution
    service = new(application, options.merge(method: 'manual'))
    service.distribute!
  end

  def self.send_daily_reminders
    # Find applications distributed 2 days ago that haven't been viewed
    reminder_distributions = ApplicationDistribution.pending
                                                   .where(created_at: 2.days.ago.beginning_of_day..2.days.ago.end_of_day)
                                                   .includes(:insurance_company, :insurance_application)

    reminder_distributions.find_each do |distribution|
      InsuranceCompanyMailer.application_reminder(distribution).deliver_later
    end

    Rails.logger.info "Sent #{reminder_distributions.count} application reminders"
  end

  def self.expire_old_distributions
    # Expire distributions older than 7 days that are still pending
    expired_count = ApplicationDistribution.pending
                                          .where('created_at < ?', 7.days.ago)
                                          .update_all(
                                            status: 'expired',
                                            expired_at: Time.current
                                          )

    Rails.logger.info "Expired #{expired_count} old distributions"
  end

  def self.send_daily_digests
    # Send daily digest to companies that have opted in
    InsuranceCompany.active
                   .joins(:company_preferences)
                   .where("company_preferences.distribution_settings->>'daily_digest' = 'true'")
                   .find_each do |company|
      
      # Only send if they have activity in the last 24 hours
      has_activity = ApplicationDistribution.for_company(company)
                                           .where(created_at: 1.day.ago..Time.current)
                                           .exists?

      if has_activity
        InsuranceCompanyMailer.daily_digest(company).deliver_later
      end
    end
  end

  private

  def find_eligible_companies
    # Use the ApplicationDistribution model's logic
    ApplicationDistribution.find_eligible_companies(@application, @options)
  end

  def create_distributions(companies)
    distributions = []

    companies.each do |company|
      begin
        # Calculate match score
        match_score = ApplicationDistribution.calculate_match_score(@application, company)
        
        # Build distribution criteria
        criteria = ApplicationDistribution.build_criteria(@application, company)

        distribution = ApplicationDistribution.create!(
          insurance_application: @application,
          insurance_company: company,
          distributed_by: @distributed_by,
          distribution_method: @distribution_method,
          match_score: match_score,
          distribution_criteria: criteria
        )

        distributions << distribution
        
      rescue StandardError => e
        Rails.logger.error "Failed to create distribution for company #{company.name}: #{e.message}"
      end
    end

    distributions
  end

  def send_notifications(distributions)
    distributions.each do |distribution|
      # Email notifications are sent automatically via after_create callback
      # But we can add additional notification logic here if needed
      
      # Send SMS if enabled
      if should_send_sms_notification?(distribution.insurance_company)
        send_sms_notification(distribution)
      end

      # Send push notification if supported
      if should_send_push_notification?(distribution.insurance_company)
        send_push_notification(distribution)
      end
    end
  end

  def update_application_status(distribution_count)
    @application.update!(
      status: 'under_review',
      distributed_at: Time.current,
      distribution_count: distribution_count
    )
  end

  def schedule_follow_ups(distributions)
    # Schedule reminder emails for 2 days later
    distributions.each do |distribution|
      ApplicationReminderJob.set(wait: 2.days)
                           .perform_later(distribution.id)
    end

    # Schedule expiration for 7 days later
    distributions.each do |distribution|
      DistributionExpirationJob.set(wait: 7.days)
                              .perform_later(distribution.id)
    end
  end

  def should_send_sms_notification?(company)
    company.company_preferences&.notification_preferences&.dig('sms_notifications') == true
  end

  def should_send_push_notification?(company)
    company.company_preferences&.notification_preferences&.dig('push_notifications') == true
  end

  def send_sms_notification(distribution)
    # Implement SMS notification logic here
    # This would integrate with a service like Twilio
    Rails.logger.info "SMS notification would be sent to #{distribution.insurance_company.phone}"
  end

  def send_push_notification(distribution)
    # Implement push notification logic here
    # This would integrate with a service like Firebase Cloud Messaging
    Rails.logger.info "Push notification would be sent to #{distribution.insurance_company.name}"
  end
end