# frozen_string_literal: true

class AddPerformanceOptimizationIndexes < ActiveRecord::Migration[8.0]
  def up
    # Performance optimization indexes for BrokerSync

    # Insurance Applications - frequently queried by status, type, and organization
    add_index :insurance_applications, [ :organization_id, :status ],
              name: 'idx_insurance_apps_org_status'
    add_index :insurance_applications, [ :organization_id, :insurance_type ],
              name: 'idx_insurance_apps_org_type'
    add_index :insurance_applications, [ :organization_id, :created_at ],
              name: 'idx_insurance_apps_org_created'
    add_index :insurance_applications, [ :user_id, :status ],
              name: 'idx_insurance_apps_user_status'
    add_index :insurance_applications, [ :client_id, :status ],
              name: 'idx_insurance_apps_client_status'

    # Quotes - frequently queried by status, organization, and deadlines
    add_index :quotes, [ :organization_id, :status ],
              name: 'idx_quotes_org_status'
    add_index :quotes, [ :organization_id, :created_at ],
              name: 'idx_quotes_org_created'
    add_index :quotes, [ :insurance_application_id, :status ],
              name: 'idx_quotes_app_status'
    add_index :quotes, [ :insurance_company_id, :status ],
              name: 'idx_quotes_company_status'
    add_index :quotes, [ :expires_at ],
              name: 'idx_quotes_expires_at'
    add_index :quotes, [ :organization_id, :expires_at ],
              name: 'idx_quotes_org_expires'

    # Documents - frequently queried by organization, type, and expiration
    add_index :documents, [ :organization_id, :document_type ],
              name: 'idx_documents_org_type'
    add_index :documents, [ :organization_id, :created_at ],
              name: 'idx_documents_org_created'
    add_index :documents, [ :user_id, :created_at ],
              name: 'idx_documents_user_created'
    add_index :documents, [ :expires_at ],
              name: 'idx_documents_expires_at',
              where: 'expires_at IS NOT NULL'
    add_index :documents, [ :organization_id, :expires_at ],
              name: 'idx_documents_org_expires',
              where: 'expires_at IS NOT NULL'

    # Security Alerts - frequently queried by organization, status, and severity
    add_index :security_alerts, [ :organization_id, :status ],
              name: 'idx_security_alerts_org_status'
    add_index :security_alerts, [ :organization_id, :severity ],
              name: 'idx_security_alerts_org_severity'
    add_index :security_alerts, [ :organization_id, :triggered_at ],
              name: 'idx_security_alerts_org_triggered'
    add_index :security_alerts, [ :status, :triggered_at ],
              name: 'idx_security_alerts_status_triggered'
    add_index :security_alerts, [ :alert_type, :triggered_at ],
              name: 'idx_security_alerts_type_triggered'

    # Notifications - frequently queried by user and read status
    add_index :notifications, [ :user_id, :read_at ],
              name: 'idx_notifications_user_read'
    add_index :notifications, [ :user_id, :created_at ],
              name: 'idx_notifications_user_created'
    add_index :notifications, [ :organization_id, :created_at ],
              name: 'idx_notifications_org_created'

    # Users - frequently queried by organization and email
    add_index :users, [ :email, :organization_id ],
              name: 'idx_users_email_org'

    # Audit logs - frequently queried by organization and date ranges
    add_index :audit_logs, [ :organization_id, :action, :created_at ],
              name: 'idx_audit_logs_org_action_created'
    add_index :audit_logs, [ :user_id, :action, :created_at ],
              name: 'idx_audit_logs_user_action_created'
    add_index :audit_logs, [ :resource_type, :resource_id ],
              name: 'idx_audit_logs_resource'

    # Application distributions - for matching and analytics
    add_index :application_distributions, [ :insurance_application_id, :match_score ],
              name: 'idx_app_dist_app_score'
    add_index :application_distributions, [ :insurance_company_id, :created_at ],
              name: 'idx_app_dist_company_created'
    add_index :application_distributions, [ :status, :created_at ],
              name: 'idx_app_dist_status_created'

    # Composite indexes for complex queries
    add_index :insurance_applications, [ :organization_id, :status, :insurance_type ],
              name: 'idx_insurance_apps_org_status_type'
    add_index :quotes, [ :organization_id, :status, :created_at ],
              name: 'idx_quotes_org_status_created'
    add_index :documents, [ :organization_id, :document_type, :created_at ],
              name: 'idx_documents_org_type_created'

    # Full-text search optimization (if using PostgreSQL)
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      # Enable pg_trgm extension for better text search
      enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

      # Add GIN indexes for text search
      add_index :clients, :first_name, using: :gin, opclass: :gin_trgm_ops,
                name: 'idx_clients_first_name_gin'
      add_index :clients, :last_name, using: :gin, opclass: :gin_trgm_ops,
                name: 'idx_clients_last_name_gin'
      add_index :clients, :email, using: :gin, opclass: :gin_trgm_ops,
                name: 'idx_clients_email_gin'

      add_index :documents, :name, using: :gin, opclass: :gin_trgm_ops,
                name: 'idx_documents_name_gin'
      add_index :documents, :description, using: :gin, opclass: :gin_trgm_ops,
                name: 'idx_documents_description_gin'
    end
  end

  def down
    # Remove performance optimization indexes

    # Insurance Applications indexes
    remove_index :insurance_applications, name: 'idx_insurance_apps_org_status'
    remove_index :insurance_applications, name: 'idx_insurance_apps_org_type'
    remove_index :insurance_applications, name: 'idx_insurance_apps_org_created'
    remove_index :insurance_applications, name: 'idx_insurance_apps_user_status'
    remove_index :insurance_applications, name: 'idx_insurance_apps_client_status'

    # Quotes indexes
    remove_index :quotes, name: 'idx_quotes_org_status'
    remove_index :quotes, name: 'idx_quotes_org_created'
    remove_index :quotes, name: 'idx_quotes_app_status'
    remove_index :quotes, name: 'idx_quotes_company_status'
    remove_index :quotes, name: 'idx_quotes_expires_at'
    remove_index :quotes, name: 'idx_quotes_org_expires'

    # Documents indexes
    remove_index :documents, name: 'idx_documents_org_type'
    remove_index :documents, name: 'idx_documents_org_created'
    remove_index :documents, name: 'idx_documents_user_created'
    remove_index :documents, name: 'idx_documents_expires_at'
    remove_index :documents, name: 'idx_documents_org_expires'

    # Security Alerts indexes
    remove_index :security_alerts, name: 'idx_security_alerts_org_status'
    remove_index :security_alerts, name: 'idx_security_alerts_org_severity'
    remove_index :security_alerts, name: 'idx_security_alerts_org_triggered'
    remove_index :security_alerts, name: 'idx_security_alerts_status_triggered'
    remove_index :security_alerts, name: 'idx_security_alerts_type_triggered'

    # Notifications indexes
    remove_index :notifications, name: 'idx_notifications_user_read'
    remove_index :notifications, name: 'idx_notifications_user_created'
    remove_index :notifications, name: 'idx_notifications_org_created'

    # Users indexes
    remove_index :users, name: 'idx_users_email_org'

    # Audit logs indexes
    remove_index :audit_logs, name: 'idx_audit_logs_org_action_created'
    remove_index :audit_logs, name: 'idx_audit_logs_user_action_created'
    remove_index :audit_logs, name: 'idx_audit_logs_resource'

    # Application distributions indexes
    remove_index :application_distributions, name: 'idx_app_dist_app_score'
    remove_index :application_distributions, name: 'idx_app_dist_company_created'
    remove_index :application_distributions, name: 'idx_app_dist_status_created'

    # Composite indexes
    remove_index :insurance_applications, name: 'idx_insurance_apps_org_status_type'
    remove_index :quotes, name: 'idx_quotes_org_status_created'
    remove_index :documents, name: 'idx_documents_org_type_created'

    # Full-text search indexes
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      remove_index :clients, name: 'idx_clients_first_name_gin'
      remove_index :clients, name: 'idx_clients_last_name_gin'
      remove_index :clients, name: 'idx_clients_email_gin'
      remove_index :documents, name: 'idx_documents_name_gin'
      remove_index :documents, name: 'idx_documents_description_gin'
    end
  end
end
