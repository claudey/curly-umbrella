class InsuranceCompanyMailer < ApplicationMailer
  def new_application_available(distribution)
    @distribution = distribution
    @application = distribution.motor_application
    @insurance_company = distribution.insurance_company
    @match_score = distribution.match_score
    
    mail(
      to: @insurance_company.email,
      subject: "New Insurance Application Available - #{@application.coverage_type.humanize} Coverage",
      template_name: 'new_application_available'
    )
  end
  
  def application_reminder(distribution)
    @distribution = distribution
    @application = distribution.motor_application
    @insurance_company = distribution.insurance_company
    @days_remaining = distribution.expires_in_days
    
    mail(
      to: @insurance_company.email,
      subject: "Reminder: Application Expires Soon - #{@application.application_number}",
      template_name: 'application_reminder'
    )
  end
  
  def quote_status_update(quote)
    @quote = quote
    @application = quote.motor_application
    @insurance_company = quote.insurance_company
    
    subject_text = case @quote.status
                  when 'approved'
                    "Quote Approved - #{@quote.quote_number}"
                  when 'rejected'
                    "Quote Rejected - #{@quote.quote_number}"
                  when 'accepted'
                    "Congratulations! Quote Accepted - #{@quote.quote_number}"
                  else
                    "Quote Status Update - #{@quote.quote_number}"
                  end
    
    mail(
      to: @insurance_company.email,
      subject: subject_text,
      template_name: 'quote_status_update'
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
                                                 .includes(:motor_application)
                                                 .where(created_at: date.beginning_of_day..date.end_of_day)
                                                 .limit(5)
    
    # Get expiring applications
    @expiring_applications = ApplicationDistribution.for_company(insurance_company)
                                                   .pending
                                                   .joins(:motor_application)
                                                   .where('motor_applications.application_expires_at <= ?', 3.days.from_now)
                                                   .limit(5)
    
    mail(
      to: @insurance_company.email,
      subject: "Daily Digest - #{date.strftime('%B %d, %Y')}",
      template_name: 'daily_digest'
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
    
    period_text = period == :monthly ? 'Monthly' : 'Weekly'
    
    mail(
      to: @insurance_company.email,
      subject: "#{period_text} Performance Report - #{@report_date.strftime('%B %Y')}",
      template_name: 'performance_report'
    )
  end
end