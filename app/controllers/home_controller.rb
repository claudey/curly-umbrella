class HomeController < ApplicationController
  before_action :authenticate_user!
  before_action :load_dashboard_data

  def index
    # Dashboard will show different content based on user role and organization
  end

  private

  def load_dashboard_data
    @current_org = current_user.organization
    load_document_metrics
    load_recent_activity
    load_system_metrics
    load_upcoming_tasks
  end

  def load_document_metrics
    # Document statistics for current organization
    documents_scope = Document.where(organization: @current_org)

    @document_metrics = {
      total_documents: documents_scope.count,
      active_documents: documents_scope.not_archived.count,
      archived_documents: documents_scope.archived.count,
      documents_this_month: documents_scope.where(created_at: Time.current.beginning_of_month..Time.current).count,
      total_file_size: documents_scope.sum(:file_size),
      expiring_soon: documents_scope.expiring_soon(7).count,
      expired_documents: documents_scope.expired.count
    }

    # Document type breakdown
    @document_type_breakdown = documents_scope.group(:document_type).count

    # Storage usage by month (simple grouping)
    @monthly_storage = documents_scope
      .where(created_at: 6.months.ago..Time.current)
      .group("DATE_TRUNC('month', created_at)")
      .sum(:file_size)

    # Top document categories
    @category_breakdown = documents_scope
      .where.not(category: nil)
      .group(:category)
      .count
      .sort_by { |k, v| -v }
      .first(5)
  end

  def load_recent_activity
    # Recent documents and activities for current organization
    @recent_documents = Document.where(organization: @current_org)
                               .includes(:user, file_attachment: :blob)
                               .recent
                               .limit(10)

    # Recent document versions
    @recent_versions = Document.where(organization: @current_org)
                              .where("version > 1")
                              .includes(:user)
                              .order(updated_at: :desc)
                              .limit(5)

    # User's recent document activity
    @my_recent_documents = Document.where(organization: @current_org, user: current_user)
                                  .includes(file_attachment: :blob)
                                  .recent
                                  .limit(5)
  end

  def load_system_metrics
    # Organization-wide system metrics
    @system_metrics = {
      total_users: User.where(organization: @current_org).count,
      active_users_today: User.joins(:documents)
                             .where(organization: @current_org)
                             .where(documents: { created_at: Time.current.beginning_of_day..Time.current })
                             .distinct
                             .count,
      total_applications: defined?(MotorApplication) ? MotorApplication.where(organization: @current_org).count : 0,
      pending_quotes: 0 # Placeholder until Quote model associations are fixed
    }
  end

  def load_upcoming_tasks
    # Upcoming document-related tasks and deadlines
    @upcoming_tasks = []

    # Expiring documents
    expiring_docs = Document.where(organization: @current_org)
                           .expiring_soon(14)
                           .limit(5)

    expiring_docs.each do |doc|
      @upcoming_tasks << {
        type: "expiring_document",
        title: "Document expiring: #{doc.name}",
        description: "Expires on #{doc.expires_at.strftime('%B %d, %Y')}",
        due_date: doc.expires_at,
        priority: doc.expiring_soon?(3) ? "high" : "medium",
        url: document_path(doc)
      }
    end

    # Documents needing review (archived but might need attention)
    archived_recent = Document.where(organization: @current_org)
                             .archived
                             .where(archived_at: 1.week.ago..Time.current)
                             .limit(3)

    archived_recent.each do |doc|
      @upcoming_tasks << {
        type: "archived_document",
        title: "Recently archived: #{doc.name}",
        description: "Archived #{time_ago_in_words(doc.archived_at)} ago",
        due_date: doc.archived_at + 30.days, # Review in 30 days
        priority: "low",
        url: document_path(doc)
      }
    end

    # Sort tasks by priority and due date
    @upcoming_tasks.sort_by! { |task| [ task[:priority] == "high" ? 0 : 1, task[:due_date] ] }
    @upcoming_tasks = @upcoming_tasks.first(10)
  end
end
