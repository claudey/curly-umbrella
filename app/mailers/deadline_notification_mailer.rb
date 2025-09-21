class DeadlineNotificationMailer < ApplicationMailer
  def deadline_reminder(distribution)
    @distribution = distribution
    @application = distribution.insurance_application
    @insurance_company = distribution.insurance_company
    @client = @application.client
    @days_remaining = distribution.expires_in_days
    @deadline_date = distribution.quote_deadline

    mail(
      to: @insurance_company.email,
      subject: "Quote Deadline Reminder - #{@application.application_number}",
      template_name: "deadline_reminder"
    )
  end

  def deadline_expired(distribution)
    @distribution = distribution
    @application = distribution.insurance_application
    @insurance_company = distribution.insurance_company
    @client = @application.client
    @deadline_date = distribution.quote_deadline

    mail(
      to: @insurance_company.email,
      subject: "Quote Deadline Expired - #{@application.application_number}",
      template_name: "deadline_expired"
    )
  end

  def deadline_extended(distribution, extended_days)
    @distribution = distribution
    @application = distribution.insurance_application
    @insurance_company = distribution.insurance_company
    @client = @application.client
    @extended_days = extended_days
    @new_deadline = distribution.quote_deadline + extended_days.days
    @days_remaining = ((@new_deadline - Time.current) / 1.day).ceil

    mail(
      to: @insurance_company.email,
      subject: "Quote Deadline Extended - #{@application.application_number}",
      template_name: "deadline_extended"
    )
  end
end
