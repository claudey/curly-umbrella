class InsuranceCompanyMailer < ApplicationMailer
  def new_application_available(distribution)
    @distribution = distribution
    @application = distribution.insurance_application
    @insurance_company = distribution.insurance_company
    @match_score = distribution.match_score
    @client = @application.client

    mail(
      to: @insurance_company.email,
      subject: "New #{@application.insurance_type_display_name} Application Available - #{@application.application_number}",
      template_name: "new_application_available"
    )
  end

  def application_reminder(distribution)
    @distribution = distribution
    @application = distribution.insurance_application
    @insurance_company = distribution.insurance_company
    @days_remaining = distribution.days_since_distribution
    @client = @application.client

    mail(
      to: @insurance_company.email,
      subject: "Reminder: Application Pending Review - #{@application.application_number}",
      template_name: "application_reminder"
    )
  end

  def quote_status_update(quote)
    @quote = quote
    @application = quote.insurance_application
    @insurance_company = quote.insurance_company
    @client = @application.client

    subject_text = case @quote.status
    when "approved"
                    "Quote Approved - #{@quote.quote_number}"
    when "rejected"
                    "Quote Rejected - #{@quote.quote_number}"
    when "accepted"
                    "Congratulations! Quote Accepted - #{@quote.quote_number}"
    else
                    "Quote Status Update - #{@quote.quote_number}"
    end

    mail(
      to: @insurance_company.email,
      subject: subject_text,
      template_name: "quote_status_update"
    )
  end

  def daily_digest(insurance_company, date = Date.current)
    @insurance_company = insurance_company
    @date = date

    # Get daily statistics
    @stats = {
      new_applications: ApplicationDistribution.for_company(insurance_company)
                                              .where(created_at: date.beginning_of_day..date.end_of_day)
                                              .count,
      pending_applications: ApplicationDistribution.for_company(insurance_company)
                                                  .pending
                                                  .count,
      quotes_submitted: Quote.where(insurance_company: insurance_company)
                            .where(created_at: date.beginning_of_day..date.end_of_day)
                            .count,
      quotes_accepted: Quote.where(insurance_company: insurance_company)
                           .where(accepted_at: date.beginning_of_day..date.end_of_day)
                           .count
    }

    # Get recent applications
    @recent_applications = ApplicationDistribution.for_company(insurance_company)
                                                 .includes(:insurance_application)
                                                 .where(created_at: date.beginning_of_day..date.end_of_day)
                                                 .limit(5)

    # Get pending applications
    @pending_applications = ApplicationDistribution.for_company(insurance_company)
                                                  .pending
                                                  .includes(:insurance_application)
                                                  .where("application_distributions.created_at <= ?", 2.days.ago)
                                                  .limit(5)

    mail(
      to: @insurance_company.email,
      subject: "Daily Digest - #{date.strftime('%B %d, %Y')}",
      template_name: "daily_digest"
    )
  end

  def performance_report(insurance_company, period = :monthly)
    @insurance_company = insurance_company
    @period = period
    @report_date = Date.current

    @performance_data = DistributionAnalytics.company_performance_report(
      insurance_company,
      period: period == :monthly ? :this_month : :last_month
    )

    period_text = period == :monthly ? "Monthly" : "Weekly"

    mail(
      to: @insurance_company.email,
      subject: "#{period_text} Performance Report - #{@report_date.strftime('%B %Y')}",
      template_name: "performance_report"
    )
  end
end
