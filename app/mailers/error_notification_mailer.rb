# frozen_string_literal: true

class ErrorNotificationMailer < ApplicationMailer
  def error_alert(user, error_report)
    @user = user
    @error_report = error_report
    @error_context = format_error_context(@error_report)
    @similar_errors = @error_report.similar_errors.limit(5)
    @occurrence_count = @error_report.occurrence_count

    subject = build_subject(@error_report)

    mail(
      to: @user.email,
      subject: subject,
      template_name: template_for_severity(@error_report.severity)
    )
  end

  def error_digest(user, error_reports, period: "daily")
    @user = user
    @error_reports = error_reports
    @period = period
    @error_summary = generate_error_summary(@error_reports)
    @top_errors = group_errors_by_frequency(@error_reports)

    mail(
      to: @user.email,
      subject: "🚨 #{period.capitalize} Error Digest - #{@error_summary[:total_errors]} errors",
      template_name: "error_digest"
    )
  end

  def critical_error_escalation(user, error_report)
    @user = user
    @error_report = error_report
    @escalation_reason = determine_escalation_reason(@error_report)
    @recommended_actions = generate_recommended_actions(@error_report)

    mail(
      to: @user.email,
      subject: "🚨 URGENT: Critical Error Escalation - #{@error_report.exception_class}",
      template_name: "critical_error_escalation"
    )
  end

  def error_resolution_notification(user, error_report)
    @user = user
    @error_report = error_report
    @resolution_time = @error_report.time_to_resolution
    @impact_summary = calculate_impact_summary(@error_report)

    mail(
      to: @user.email,
      subject: "✅ Error Resolved: #{@error_report.exception_class}",
      template_name: "error_resolution"
    )
  end

  private

  def build_subject(error_report)
    severity_emoji = case error_report.severity
    when "critical" then "🚨"
    when "high" then "⚠️"
    when "medium" then "⚡"
    else "📝"
    end

    occurrence_text = error_report.occurrence_count > 1 ? " (#{error_report.occurrence_count}x)" : ""

    "#{severity_emoji} #{error_report.severity.humanize} Error: #{error_report.exception_class}#{occurrence_text}"
  end

  def template_for_severity(severity)
    case severity
    when "critical", "high"
      "critical_error_alert"
    else
      "standard_error_alert"
    end
  end

  def format_error_context(error_report)
    context = error_report.context || {}

    {
      location: format_error_location(error_report),
      user_impact: format_user_impact(context),
      request_details: format_request_details(context),
      system_info: format_system_info(context),
      timing: format_timing_info(error_report)
    }
  end

  def format_error_location(error_report)
    primary_line = error_report.primary_backtrace_line
    return "Unknown location" unless primary_line

    if error_report.affected_file && error_report.affected_line_number
      "#{error_report.affected_file}:#{error_report.affected_line_number}"
    else
      primary_line
    end
  end

  def format_user_impact(context)
    impact = {}

    impact[:affected_user] = context["user_email"] if context["user_email"]
    impact[:organization] = context["organization_name"] if context["organization_name"]
    impact[:controller_action] = "#{context['controller']}##{context['action']}" if context["controller"] && context["action"]
    impact[:request_path] = context["request_path"] if context["request_path"]

    impact
  end

  def format_request_details(context)
    details = {}

    details[:method] = context["request_method"] if context["request_method"]
    details[:path] = context["request_path"] if context["request_path"]
    details[:ip_address] = context["ip_address"] if context["ip_address"]
    details[:user_agent] = context["user_agent"]&.truncate(100) if context["user_agent"]
    details[:request_id] = context["request_id"] if context["request_id"]

    details
  end

  def format_system_info(context)
    info = {}

    info[:hostname] = context["hostname"] if context["hostname"]
    info[:process_id] = context["process_id"] if context["process_id"]
    info[:memory_usage] = "#{context['memory_usage']} MB" if context["memory_usage"]
    info[:environment] = Rails.env
    info[:application_version] = Rails.application.config.version rescue "1.0.0"

    info
  end

  def format_timing_info(error_report)
    {
      occurred_at: error_report.occurred_at.strftime("%Y-%m-%d %H:%M:%S %Z"),
      first_seen: error_report.first_occurrence.occurred_at.strftime("%Y-%m-%d %H:%M:%S %Z"),
      frequency: "#{error_report.frequency_per_hour.round(2)} errors/hour"
    }
  end

  def generate_error_summary(error_reports)
    {
      total_errors: error_reports.count,
      by_severity: error_reports.group_by(&:severity).transform_values(&:count),
      by_category: error_reports.group_by(&:category).transform_values(&:count),
      unique_errors: error_reports.map(&:fingerprint).uniq.count,
      unresolved_count: error_reports.count(&:unresolved?),
      trending_errors: error_reports.select(&:is_trending?).count
    }
  end

  def group_errors_by_frequency(error_reports)
    error_reports.group_by(&:fingerprint)
                .map do |fingerprint, errors|
      representative_error = errors.first
      {
        error: representative_error,
        count: errors.count,
        latest_occurrence: errors.max_by(&:occurred_at).occurred_at,
        severity: representative_error.severity,
        is_trending: representative_error.is_trending?
      }
    end
                .sort_by { |group| -group[:count] }
                .first(10)
  end

  def determine_escalation_reason(error_report)
    reasons = []

    reasons << "High frequency (#{error_report.frequency_per_hour.round(1)} errors/hour)" if error_report.frequency_per_hour > 10
    reasons << "Multiple users affected (#{error_report.user_impact_score} impact score)" if error_report.user_impact_score >= 3
    reasons << "Critical system component" if error_report.category.in?([ "database", "security", "authentication" ])
    reasons << "Error trending upward" if error_report.is_trending?
    reasons << "Unresolved for extended period" if error_report.occurred_at < 2.hours.ago && !error_report.resolved?

    reasons.join("; ")
  end

  def generate_recommended_actions(error_report)
    actions = []

    case error_report.category
    when "database"
      actions << "Check database connection and query performance"
      actions << "Review recent migrations or schema changes"
      actions << "Monitor database server resources"
    when "security"
      actions << "Investigate potential security incident"
      actions << "Review access logs and user permissions"
      actions << "Consider implementing additional security measures"
    when "performance"
      actions << "Analyze query performance and optimize slow operations"
      actions << "Check server resources (CPU, memory, disk)"
      actions << "Review caching strategies"
    when "external_service"
      actions << "Check external service status and connectivity"
      actions << "Verify API keys and authentication"
      actions << "Implement circuit breaker patterns if needed"
    else
      actions << "Review error logs and stack trace"
      actions << "Check recent code deployments"
      actions << "Verify configuration settings"
    end

    # Add general high-priority actions
    if error_report.severity == "critical"
      actions.unshift("Consider rolling back recent deployments if applicable")
      actions << "Escalate to on-call engineer if not resolved within 1 hour"
    end

    actions
  end

  def calculate_impact_summary(error_report)
    {
      occurrence_count: error_report.occurrence_count,
      resolution_time: error_report.time_to_resolution,
      user_impact_score: error_report.user_impact_score,
      business_impact_score: error_report.business_impact_score,
      first_occurred: error_report.first_occurrence.occurred_at,
      resolved_at: error_report.resolved_at
    }
  end
end
