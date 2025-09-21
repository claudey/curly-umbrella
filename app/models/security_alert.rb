class SecurityAlert < ApplicationRecord
  acts_as_tenant :organization

  belongs_to :organization
  belongs_to :resolved_by, class_name: "User", optional: true

  validates :alert_type, presence: true
  validates :message, presence: true
  validates :severity, presence: true, inclusion: { in: %w[low medium high critical] }
  validates :status, presence: true, inclusion: { in: %w[active investigating resolved dismissed] }
  validates :triggered_at, presence: true

  enum :severity, {
    low: "low",
    medium: "medium",
    high: "high",
    critical: "critical"
  }

  enum :status, {
    active: "active",
    investigating: "investigating",
    resolved: "resolved",
    dismissed: "dismissed"
  }

  enum :alert_type, {
    multiple_failed_logins: "multiple_failed_logins",
    suspicious_ip_activity: "suspicious_ip_activity",
    rapid_user_activity: "rapid_user_activity",
    unusual_login_location: "unusual_login_location",
    new_login_location: "new_login_location",
    concurrent_sessions: "concurrent_sessions",
    unauthorized_access_attempt: "unauthorized_access_attempt",
    privilege_escalation_attempt: "privilege_escalation_attempt",
    bulk_data_access: "bulk_data_access",
    brute_force_attack: "brute_force_attack",
    ip_user_anomaly: "ip_user_anomaly",
    activity_spike: "activity_spike",
    off_hours_activity: "off_hours_activity",
    unusual_login_time: "unusual_login_time"
  }

  scope :recent, -> { order(triggered_at: :desc) }
  scope :unresolved, -> { where(status: [ "active", "investigating" ]) }
  scope :critical_alerts, -> { where(severity: [ "high", "critical" ]) }
  scope :for_organization, ->(org) { where(organization: org) }

  def resolve!(user, notes = nil)
    update!(
      status: "resolved",
      resolved_at: Time.current,
      resolved_by: user,
      resolution_notes: notes
    )
  end

  def dismiss!(user, reason = nil)
    update!(
      status: "dismissed",
      resolved_at: Time.current,
      resolved_by: user,
      resolution_notes: reason
    )
  end

  def investigate!(user)
    update!(
      status: "investigating",
      resolved_by: user
    )
  end

  def severity_color
    case severity
    when "low" then "text-blue-600"
    when "medium" then "text-yellow-600"
    when "high" then "text-orange-600"
    when "critical" then "text-red-600"
    end
  end

  def severity_badge_class
    case severity
    when "low" then "bg-blue-100 text-blue-800"
    when "medium" then "bg-yellow-100 text-yellow-800"
    when "high" then "bg-orange-100 text-orange-800"
    when "critical" then "bg-red-100 text-red-800"
    end
  end

  def status_badge_class
    case status
    when "active" then "bg-red-100 text-red-800"
    when "investigating" then "bg-yellow-100 text-yellow-800"
    when "resolved" then "bg-green-100 text-green-800"
    when "dismissed" then "bg-gray-100 text-gray-800"
    end
  end

  def affected_user
    return nil unless data.is_a?(Hash)

    user_id = data["user_id"] || data.dig("user", "id")
    User.find_by(id: user_id) if user_id
  end

  def ip_address
    data&.dig("ip_address")
  end

  def auto_resolvable?
    %w[off_hours_activity unusual_login_time].include?(alert_type)
  end

  def requires_immediate_action?
    severity == "critical" && %w[brute_force_attack privilege_escalation_attempt].include?(alert_type)
  end

  def time_since_triggered
    return nil unless triggered_at

    Time.current - triggered_at
  end

  def formatted_data
    return {} unless data.is_a?(Hash)

    formatted = {}
    data.each do |key, value|
      case key.to_s
      when "user"
        formatted["User"] = value.is_a?(Hash) ? "#{value['name']} (#{value['email']})" : value.to_s
      when "ip_address"
        formatted["IP Address"] = value
      when "count", "attempt_count", "access_count", "activity_count"
        formatted[key.humanize] = value
      when "current_hour", "typical_hours"
        formatted[key.humanize] = value
      else
        formatted[key.humanize] = value
      end
    end
    formatted
  end

  def self.cleanup_old_alerts(days_old = 90)
    where("triggered_at < ?", days_old.days.ago)
      .where(status: [ "resolved", "dismissed" ])
      .delete_all
  end

  def self.daily_summary(organization, date = Date.current)
    alerts = where(organization: organization)
             .where(triggered_at: date.all_day)

    {
      total: alerts.count,
      by_severity: alerts.group(:severity).count,
      by_status: alerts.group(:status).count,
      critical_unresolved: alerts.critical_alerts.unresolved.count,
      auto_resolved: alerts.where(status: "resolved").where("resolved_at IS NOT NULL").count
    }
  end
end
