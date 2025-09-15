class NotificationMailer < ApplicationMailer
  default from: 'noreply@brokersync.com'

  def new_application_notification(user, application)
    @user = user
    @application = application
    @organization = user.organization

    mail(
      to: @user.email,
      subject: "New Motor Insurance Application - #{@application.policy_number}"
    )
  end

  def status_update_notification(user, application, old_status, new_status)
    @user = user
    @application = application
    @old_status = old_status
    @new_status = new_status
    @organization = user.organization

    mail(
      to: @user.email,
      subject: "Application Status Update - #{@application.policy_number}"
    )
  end

  def user_invitation(user, inviter, organization)
    @user = user
    @inviter = inviter
    @organization = organization

    mail(
      to: @user.email,
      subject: "You've been invited to join #{@organization.name} on BrokerSync"
    )
  end

  def system_alert(user, title, message)
    @user = user
    @title = title
    @message = message
    @organization = user.organization

    mail(
      to: @user.email,
      subject: "BrokerSync Alert: #{@title}"
    )
  end
end
