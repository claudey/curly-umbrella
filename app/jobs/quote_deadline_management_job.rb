class QuoteDeadlineManagementJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting quote deadline management job"
    
    expire_overdue_quotes
    send_expiration_warnings
    send_deadline_reminders
    
    Rails.logger.info "Completed quote deadline management job"
  end

  private

  def expire_overdue_quotes
    expired_count = Quote.check_expired_quotes!
    Rails.logger.info "Expired #{expired_count} overdue quotes"
    
    # Notify insurance companies about expired quotes
    Quote.where(status: 'expired')
         .where('updated_at >= ?', 1.hour.ago)
         .includes(:insurance_company, :insurance_application)
         .find_each do |quote|
      send_expiration_notification(quote)
    end
  end

  def send_expiration_warnings
    # Send warnings 24 hours before expiration
    warning_quotes = Quote.active
                         .where(expires_at: 24.hours.from_now..25.hours.from_now)
                         .includes(:insurance_company, :insurance_application)

    warning_quotes.find_each do |quote|
      QuoteExpirationWarningMailer.expiration_warning(quote).deliver_now
      Rails.logger.info "Sent expiration warning for quote #{quote.quote_number}"
    end

    Rails.logger.info "Sent #{warning_quotes.count} expiration warnings"
  end

  def send_deadline_reminders
    # Send reminders 3 days before expiration
    reminder_quotes = Quote.active
                          .where(expires_at: 3.days.from_now..3.days.from_now + 1.hour)
                          .includes(:insurance_company, :insurance_application)

    reminder_quotes.find_each do |quote|
      QuoteExpirationWarningMailer.deadline_reminder(quote).deliver_now
      Rails.logger.info "Sent deadline reminder for quote #{quote.quote_number}"
    end

    Rails.logger.info "Sent #{reminder_quotes.count} deadline reminders"
  end

  def send_expiration_notification(quote)
    QuoteExpirationWarningMailer.quote_expired(quote).deliver_now
    Rails.logger.info "Sent expiration notification for quote #{quote.quote_number}"
  end
end