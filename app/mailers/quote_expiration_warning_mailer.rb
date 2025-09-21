class QuoteExpirationWarningMailer < ApplicationMailer
  def expiration_warning(quote)
    @quote = quote
    @application = quote.insurance_application
    @insurance_company = quote.insurance_company
    @client = @application.client
    @days_remaining = quote.expires_in_days

    mail(
      to: @insurance_company.email,
      subject: "Quote Expiring Soon - #{@quote.quote_number}",
      template_name: "expiration_warning"
    )
  end

  def deadline_reminder(quote)
    @quote = quote
    @application = quote.insurance_application
    @insurance_company = quote.insurance_company
    @client = @application.client
    @days_remaining = quote.expires_in_days

    mail(
      to: @insurance_company.email,
      subject: "Quote Deadline Reminder - #{@quote.quote_number}",
      template_name: "deadline_reminder"
    )
  end

  def quote_expired(quote)
    @quote = quote
    @application = quote.insurance_application
    @insurance_company = quote.insurance_company
    @client = @application.client

    mail(
      to: @insurance_company.email,
      subject: "Quote Expired - #{@quote.quote_number}",
      template_name: "quote_expired"
    )
  end
end
