class SecurityMailer < ApplicationMailer
  default from: 'security@brokersync.com'

  def critical_alert(admin, alert)
    @admin = admin
    @alert = alert
    @organization = alert.organization
    @urgency = 'CRITICAL'

    mail(
      to: @admin.email,
      subject: "[CRITICAL SECURITY ALERT] #{alert.message}",
      priority: 'high'
    )
  end

  def security_alert(alert)
    @alert = alert
    @organization = alert.organization
    @admins = @organization.users.where(role: ['super_admin', 'brokerage_admin'])

    mail(
      to: @admins.pluck(:email),
      subject: "[Security Alert] #{alert.alert_type.humanize} - #{@organization.name}",
      priority: alert.severity == 'high' ? 'high' : 'normal'
    )
  end

  def user_security_alert(user, alert)
    @user = user
    @alert = alert
    @organization = user.organization

    mail(
      to: @user.email,
      subject: "Security Alert for Your Account - #{@organization.name}",
      priority: 'normal'
    )
  end

  def daily_security_digest(admin, alerts_summary, date = Date.current)
    @admin = admin
    @date = date
    @organization = admin.organization
    @summary = alerts_summary
    @alerts = SecurityAlert.where(organization: @organization)
                          .where(triggered_at: date.all_day)
                          .order(severity: :desc, triggered_at: :desc)

    mail(
      to: @admin.email,
      subject: "Daily Security Digest - #{date.strftime('%B %d, %Y')} - #{@organization.name}"
    )
  end

  def weekly_security_report(admin, start_date, end_date)
    @admin = admin
    @start_date = start_date
    @end_date = end_date
    @organization = admin.organization
    
    alerts = SecurityAlert.where(organization: @organization)
                         .where(triggered_at: start_date..end_date)
    
    @summary = {
      total_alerts: alerts.count,
      by_severity: alerts.group(:severity).count,
      by_type: alerts.group(:alert_type).count,
      resolved_count: alerts.where(status: 'resolved').count,
      unresolved_count: alerts.unresolved.count
    }
    
    @top_alerts = alerts.where(severity: ['high', 'critical'])
                       .order(triggered_at: :desc)
                       .limit(10)

    mail(
      to: @admin.email,
      subject: "Weekly Security Report - #{start_date.strftime('%m/%d')} to #{end_date.strftime('%m/%d')} - #{@organization.name}"
    )
  end

  def critical_security_alert(user, alert)
    @user = user
    @alert = alert
    @alert_data = alert.formatted_data
    
    mail(
      to: @user.email,
      subject: "🚨 Critical Security Alert: #{@alert.message}",
      priority: 'high'
    )
  end

  def ip_block_notification(user, ip_address, reason, permanent, duration)
    @user = user
    @ip_address = ip_address
    @reason = reason
    @permanent = permanent
    @duration = duration
    @blocked_at = Time.current
    
    subject = if permanent
                "🛡️ IP Permanently Blocked: #{ip_address}"
              else
                "⏰ IP Temporarily Blocked: #{ip_address}"
              end

    mail(
      to: @user.email,
      subject: subject,
      priority: 'high'
    )
  end
end
