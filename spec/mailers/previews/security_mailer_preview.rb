# Preview all emails at http://localhost:3000/rails/mailers/security_mailer_mailer
class SecurityMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/security_mailer_mailer/critical_alert
  def critical_alert
    SecurityMailer.critical_alert
  end

  # Preview this email at http://localhost:3000/rails/mailers/security_mailer_mailer/security_alert
  def security_alert
    SecurityMailer.security_alert
  end

  # Preview this email at http://localhost:3000/rails/mailers/security_mailer_mailer/user_security_alert
  def user_security_alert
    SecurityMailer.user_security_alert
  end
end
