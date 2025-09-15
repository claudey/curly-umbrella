# frozen_string_literal: true

module AuditsHelper
  def severity_badge_class(severity)
    case severity.to_s
    when 'info'
      'bg-blue-100 text-blue-800'
    when 'warning'
      'bg-yellow-100 text-yellow-800'
    when 'error'
      'bg-red-100 text-red-800'
    when 'critical'
      'bg-purple-100 text-purple-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  def severity_border_class(severity)
    case severity.to_s
    when 'info'
      'border-blue-400'
    when 'warning'
      'border-yellow-400'
    when 'error'
      'border-red-400'
    when 'critical'
      'border-purple-400'
    else
      'border-gray-400'
    end
  end

  def severity_color_class(severity)
    case severity.to_s
    when 'info'
      'bg-blue-500'
    when 'warning'
      'bg-yellow-500'
    when 'error'
      'bg-red-500'
    when 'critical'
      'bg-purple-500'
    else
      'bg-gray-500'
    end
  end

  def severity_bar_class(severity)
    case severity.to_s
    when 'info'
      'bg-blue-500'
    when 'warning'
      'bg-yellow-500'
    when 'error'
      'bg-red-500'
    when 'critical'
      'bg-purple-500'
    else
      'bg-gray-500'
    end
  end

  def category_badge_class(category)
    case category.to_s
    when 'authentication'
      'bg-green-100 text-green-800'
    when 'authorization'
      'bg-orange-100 text-orange-800'
    when 'data_access'
      'bg-blue-100 text-blue-800'
    when 'data_modification'
      'bg-purple-100 text-purple-800'
    when 'system_access'
      'bg-indigo-100 text-indigo-800'
    when 'compliance'
      'bg-teal-100 text-teal-800'
    when 'security'
      'bg-red-100 text-red-800'
    when 'financial'
      'bg-emerald-100 text-emerald-800'
    when 'user_management'
      'bg-cyan-100 text-cyan-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  def category_color_class(category)
    case category.to_s
    when 'authentication'
      'bg-green-500'
    when 'authorization'
      'bg-orange-500'
    when 'data_access'
      'bg-blue-500'
    when 'data_modification'
      'bg-purple-500'
    when 'system_access'
      'bg-indigo-500'
    when 'compliance'
      'bg-teal-500'
    when 'security'
      'bg-red-500'
    when 'financial'
      'bg-emerald-500'
    when 'user_management'
      'bg-cyan-500'
    else
      'bg-gray-500'
    end
  end

  def audit_action_icon(action)
    case action.to_s.downcase
    when /login/
      'ph-sign-in'
    when /logout/
      'ph-sign-out'
    when /create/
      'ph-plus-circle'
    when /update/, /edit/
      'ph-pencil'
    when /delete/, /destroy/
      'ph-trash'
    when /approve/
      'ph-check-circle'
    when /reject/
      'ph-x-circle'
    when /access/, /view/
      'ph-eye'
    when /export/
      'ph-download'
    when /upload/
      'ph-upload'
    else
      'ph-activity'
    end
  end

  def format_audit_details(details)
    return {} if details.blank?
    
    formatted = {}
    details.each do |key, value|
      case key.to_s
      when 'changes'
        formatted['Changes'] = format_changes(value)
      when 'amount'
        formatted['Amount'] = number_to_currency(value) if value
      when 'ip_address'
        formatted['IP Address'] = value
      when 'user_agent'
        formatted['Browser'] = parse_user_agent(value)
      when 'timestamp'
        formatted['Timestamp'] = Time.parse(value).strftime('%B %d, %Y at %I:%M %p') rescue value
      else
        formatted[key.humanize] = value
      end
    end
    formatted
  end

  def format_changes(changes)
    return '' if changes.blank?
    
    if changes.is_a?(Hash)
      changes.map do |field, (old_val, new_val)|
        "#{field.humanize}: #{old_val} → #{new_val}"
      end.join(', ')
    else
      changes.to_s
    end
  end

  def parse_user_agent(user_agent)
    return user_agent if user_agent.blank?
    
    case user_agent
    when /Chrome/
      'Chrome'
    when /Firefox/
      'Firefox'
    when /Safari/
      'Safari'
    when /Edge/
      'Edge'
    when /Opera/
      'Opera'
    else
      'Unknown Browser'
    end
  end

  def audit_activity_summary(logs)
    return {} if logs.empty?
    
    {
      total: logs.count,
      today: logs.where(created_at: Date.current.all_day).count,
      this_week: logs.where(created_at: 1.week.ago..Time.current).count,
      by_severity: logs.group(:severity).count,
      by_category: logs.group(:category).count,
      top_users: logs.joins(:user).group('users.email').count.sort_by { |k, v| -v }.first(5)
    }
  end

  def risk_level_badge(level)
    case level.to_s
    when 'low'
      content_tag :span, 'Low Risk', class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800'
    when 'medium'
      content_tag :span, 'Medium Risk', class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800'
    when 'high'
      content_tag :span, 'High Risk', class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800'
    else
      content_tag :span, 'Unknown', class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800'
    end
  end

  def compliance_status_badge(suspicious_count, failed_auth_count)
    if suspicious_count == 0 && failed_auth_count < 5
      content_tag :span, 'Compliant', class: 'inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800'
    elsif suspicious_count < 10
      content_tag :span, 'Review Required', class: 'inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-yellow-100 text-yellow-800'
    else
      content_tag :span, 'Attention Required', class: 'inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800'
    end
  end

  def audit_export_formats
    [
      ['CSV', 'csv'],
      ['JSON', 'json'],
      ['PDF Report', 'pdf']
    ]
  end

  def audit_date_ranges
    [
      ['Last 7 days', 7.days.ago.to_date, Date.current],
      ['Last 30 days', 30.days.ago.to_date, Date.current],
      ['Last 90 days', 90.days.ago.to_date, Date.current],
      ['This month', Date.current.beginning_of_month, Date.current.end_of_month],
      ['Last month', 1.month.ago.beginning_of_month, 1.month.ago.end_of_month],
      ['This year', Date.current.beginning_of_year, Date.current.end_of_year]
    ]
  end

  def humanize_audit_action(action)
    case action.to_s
    when 'create'
      'Created'
    when 'update'
      'Updated'
    when 'destroy'
      'Deleted'
    when 'login_success'
      'Successful Login'
    when 'login_failure'
      'Failed Login'
    when 'password_reset_request'
      'Password Reset Requested'
    when 'account_locked'
      'Account Locked'
    when 'unauthorized_access'
      'Unauthorized Access Attempt'
    else
      action.humanize
    end
  end

  def audit_trends_data(logs, days = 30)
    end_date = Date.current
    start_date = days.days.ago.to_date
    
    daily_counts = {}
    (start_date..end_date).each do |date|
      daily_counts[date.strftime('%Y-%m-%d')] = logs.where(created_at: date.all_day).count
    end
    
    daily_counts
  end
end