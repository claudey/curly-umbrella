class QuoteDeadlineService
  def self.process_expired_deadlines!
    Rails.logger.info "Processing expired quote deadlines"

    expired_distributions = ApplicationDistribution.active
                                                  .where("created_at < ?", 7.days.ago)
                                                  .includes(:insurance_company, :insurance_application)

    expired_count = 0
    reminder_count = 0

    expired_distributions.find_each do |distribution|
      # Check if company has submitted a quote
      if distribution.has_submitted_quote?
        # Mark as quoted if quote exists
        distribution.mark_as_quoted! unless distribution.quoted?
      elsif distribution.deadline_expired?
        # Expire distribution if deadline passed and no quote submitted
        distribution.expire!
        send_deadline_expired_notification(distribution)
        expired_count += 1
      elsif distribution.deadline_approaching?
        # Send reminder if deadline is approaching
        send_deadline_reminder(distribution)
        reminder_count += 1
      end
    end

    Rails.logger.info "Expired #{expired_count} distributions, sent #{reminder_count} reminders"

    {
      expired: expired_count,
      reminders_sent: reminder_count
    }
  end

  def self.send_daily_deadline_report
    approaching_deadlines = ApplicationDistribution.active
                                                  .select(&:deadline_approaching?)
                                                  .group_by(&:insurance_company)

    approaching_deadlines.each do |company, distributions|
      DeadlineReportMailer.daily_deadline_report(company, distributions).deliver_later
    end

    Rails.logger.info "Sent deadline reports to #{approaching_deadlines.count} companies"
  end

  def self.extend_deadline(distribution, days)
    return false unless distribution.active?

    new_deadline = distribution.quote_deadline + days.days

    # Store extended deadline in metadata or separate field
    distribution.update!(
      notes: "Deadline extended by #{days} days to #{new_deadline.strftime('%B %d, %Y')}"
    )

    # Send notification about extension
    DeadlineExtensionMailer.deadline_extended(distribution, days).deliver_later

    Rails.logger.info "Extended deadline for distribution #{distribution.id} by #{days} days"

    true
  end

  def self.bulk_extend_deadlines(distribution_ids, days)
    distributions = ApplicationDistribution.where(id: distribution_ids).active
    extended_count = 0

    distributions.find_each do |distribution|
      if extend_deadline(distribution, days)
        extended_count += 1
      end
    end

    Rails.logger.info "Extended deadlines for #{extended_count} distributions"
    extended_count
  end

  private

  def self.send_deadline_expired_notification(distribution)
    DeadlineNotificationMailer.deadline_expired(distribution).deliver_later
  end

  def self.send_deadline_reminder(distribution)
    DeadlineNotificationMailer.deadline_reminder(distribution).deliver_later
  end
end
