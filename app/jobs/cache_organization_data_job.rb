# frozen_string_literal: true

# Background job to cache organization data for performance optimization
class CacheOrganizationDataJob < ApplicationJob
  queue_as :caching

  def perform(organization_id)
    organization = Organization.find_by(id: organization_id)
    return unless organization

    # Set tenant context
    ActsAsTenant.with_tenant(organization) do
      cache_organization_data(organization)
    end
  end

  private

  def cache_organization_data(organization)
    # Cache basic organization information
    CachingService.cache_organization_data(organization)

    # Cache dashboard statistics
    cache_dashboard_stats(organization)

    # Cache security metrics
    cache_security_metrics(organization)

    # Cache quote statistics
    cache_quote_statistics(organization)

    # Cache document metrics
    cache_document_metrics(organization)

    # Cache recent activities
    cache_recent_activities(organization)

    Rails.logger.info "Cached data for organization: #{organization.name} (ID: #{organization.id})"
  rescue => e
    Rails.logger.error "Failed to cache organization data: #{e.message}"
    Bugsnag.notify(e) if defined?(Bugsnag)
  end

  def cache_dashboard_stats(organization)
    stats = {
      total_applications: organization.insurance_applications.count,
      pending_applications: organization.insurance_applications.pending.count,
      approved_applications: organization.insurance_applications.approved.count,
      total_quotes: organization.quotes.count,
      pending_quotes: organization.quotes.pending.count,
      accepted_quotes: organization.quotes.accepted.count,
      total_users: organization.users.count,
      active_users: organization.users.where('last_sign_in_at > ?', 30.days.ago).count,
      total_documents: organization.documents.count,
      expiring_documents: organization.documents.expiring_soon.count
    }

    CachingService.write("dashboard:#{organization.id}:stats", stats, expires_in: :short)
  end

  def cache_security_metrics(organization)
    # Get security alerts from the last 30 days
    recent_alerts = SecurityAlert.where(organization: organization)
                                 .where('triggered_at > ?', 30.days.ago)

    metrics = {
      total_alerts: recent_alerts.count,
      critical_alerts: recent_alerts.where(severity: 'critical').count,
      high_alerts: recent_alerts.where(severity: 'high').count,
      unresolved_alerts: recent_alerts.unresolved.count,
      alerts_by_type: recent_alerts.group(:alert_type).count,
      alerts_by_day: recent_alerts.group_by_day(:triggered_at, last: 7).count
    }

    CachingService.cache_security_metrics(organization.id, metrics)
  end

  def cache_quote_statistics(organization)
    quotes = organization.quotes.includes(:insurance_application, :insurance_company)
    
    stats = {
      total_quotes: quotes.count,
      quotes_by_status: quotes.group(:status).count,
      quotes_by_type: quotes.joins(:insurance_application)
                           .group('insurance_applications.insurance_type')
                           .count,
      average_quote_value: quotes.where.not(premium_amount: nil).average(:premium_amount),
      quotes_this_month: quotes.where('created_at > ?', 1.month.ago).count,
      acceptance_rate: calculate_acceptance_rate(quotes)
    }

    CachingService.cache_quote_stats(organization.id, stats)
  end

  def cache_document_metrics(organization)
    documents = organization.documents

    counts = {
      total_documents: documents.count,
      documents_by_type: documents.group(:document_type).count,
      expiring_soon: documents.expiring_soon.count,
      expired: documents.expired.count,
      archived: documents.archived.count,
      recent_uploads: documents.where('created_at > ?', 7.days.ago).count,
      average_file_size: documents.average(:file_size) || 0
    }

    CachingService.cache_document_counts(organization.id, counts)
  end

  def cache_recent_activities(organization)
    # Get recent activities across different models
    activities = []

    # Recent applications
    recent_apps = organization.insurance_applications
                             .includes(:user, :client)
                             .limit(5)
                             .order(created_at: :desc)

    recent_apps.each do |app|
      activities << {
        type: 'application',
        action: 'created',
        description: "New #{app.insurance_type} application submitted",
        user_name: app.user&.full_name,
        created_at: app.created_at,
        object_id: app.id
      }
    end

    # Recent quotes
    recent_quotes = organization.quotes
                               .includes(:insurance_application, :insurance_company)
                               .limit(5)
                               .order(created_at: :desc)

    recent_quotes.each do |quote|
      activities << {
        type: 'quote',
        action: 'created',
        description: "Quote received from #{quote.insurance_company&.name}",
        user_name: quote.insurance_company&.name,
        created_at: quote.created_at,
        object_id: quote.id
      }
    end

    # Recent documents
    recent_docs = organization.documents
                             .includes(:user)
                             .limit(5)
                             .order(created_at: :desc)

    recent_docs.each do |doc|
      activities << {
        type: 'document',
        action: 'uploaded',
        description: "Document uploaded: #{doc.name}",
        user_name: doc.user&.full_name,
        created_at: doc.created_at,
        object_id: doc.id
      }
    end

    # Sort by date and limit
    sorted_activities = activities.sort_by { |a| a[:created_at] }.reverse.first(20)

    CachingService.write("activities:#{organization.id}:recent", sorted_activities, expires_in: :short)
  end

  def calculate_acceptance_rate(quotes)
    return 0 if quotes.empty?

    accepted = quotes.accepted.count
    total_responded = quotes.where.not(status: ['pending', 'submitted']).count
    
    return 0 if total_responded.zero?

    ((accepted.to_f / total_responded) * 100).round(2)
  end
end