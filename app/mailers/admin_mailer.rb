class AdminMailer < ApplicationMailer
  default from: "noreply@brokersync.com"

  def organization_created(admin_user, temporary_password)
    @admin_user = admin_user
    @organization = admin_user.organization
    @temporary_password = temporary_password
    @login_url = new_user_session_url(host: organization_host(@organization))

    mail(
      to: @admin_user.email,
      subject: "Welcome to #{@organization.name} on BrokerSync"
    )
  end

  def organization_activated(organization)
    @organization = organization
    @admin_users = organization.users.where(role: "brokerage_admin")

    @admin_users.each do |admin_user|
      mail(
        to: admin_user.email,
        subject: "#{@organization.name} has been activated"
      ).deliver_later
    end
  end

  def organization_deactivated(organization, reason = nil)
    @organization = organization
    @reason = reason
    @admin_users = organization.users.where(role: "brokerage_admin")

    @admin_users.each do |admin_user|
      mail(
        to: admin_user.email,
        subject: "#{@organization.name} has been deactivated"
      ).deliver_later
    end
  end

  private

  def organization_host(organization)
    if Rails.env.production?
      "#{organization.subdomain}.brokersync.com"
    else
      "localhost:3000"
    end
  end
end
