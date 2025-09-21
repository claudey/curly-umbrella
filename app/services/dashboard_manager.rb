class DashboardManager
  include Singleton

  # Dashboard layouts and configurations
  DASHBOARD_LAYOUTS = {
    executive: {
      grid: { columns: 12, rows: 8 },
      widgets: [
        { name: :kpi_summary, position: { x: 0, y: 0, w: 12, h: 2 } },
        { name: :revenue_trends, position: { x: 0, y: 2, w: 8, h: 3 } },
        { name: :customer_metrics, position: { x: 8, y: 2, w: 4, h: 3 } },
        { name: :risk_analysis, position: { x: 0, y: 5, w: 6, h: 3 } },
        { name: :performance_indicators, position: { x: 6, y: 5, w: 6, h: 3 } }
      ]
    },
    operational: {
      grid: { columns: 12, rows: 10 },
      widgets: [
        { name: :real_time_metrics, position: { x: 0, y: 0, w: 12, h: 2 } },
        { name: :application_pipeline, position: { x: 0, y: 2, w: 6, h: 4 } },
        { name: :claims_processing, position: { x: 6, y: 2, w: 6, h: 4 } },
        { name: :agent_performance, position: { x: 0, y: 6, w: 8, h: 4 } },
        { name: :system_health, position: { x: 8, y: 6, w: 4, h: 4 } }
      ]
    },
    analytical: {
      grid: { columns: 12, rows: 12 },
      widgets: [
        { name: :predictive_analytics, position: { x: 0, y: 0, w: 6, h: 4 } },
        { name: :trend_analysis, position: { x: 6, y: 0, w: 6, h: 4 } },
        { name: :customer_segmentation, position: { x: 0, y: 4, w: 8, h: 4 } },
        { name: :market_intelligence, position: { x: 8, y: 4, w: 4, h: 4 } },
        { name: :forecasting, position: { x: 0, y: 8, w: 12, h: 4 } }
      ]
    }
  }.freeze

  def initialize
    @user_dashboards = {}
    @dashboard_subscriptions = {}
  end

  # Get dashboard configuration for user
  def get_user_dashboard(user_id, dashboard_type)
    user_key = "#{user_id}:#{dashboard_type}"

    # Check if user has custom dashboard
    if @user_dashboards[user_key]
      @user_dashboards[user_key]
    else
      # Return default layout
      DASHBOARD_LAYOUTS[dashboard_type.to_sym] || DASHBOARD_LAYOUTS[:executive]
    end
  end

  # Save custom dashboard layout for user
  def save_user_dashboard(user_id, dashboard_type, layout_config)
    user_key = "#{user_id}:#{dashboard_type}"

    validated_config = validate_dashboard_config(layout_config)
    return { success: false, errors: validated_config[:errors] } unless validated_config[:valid]

    @user_dashboards[user_key] = {
      user_id: user_id,
      dashboard_type: dashboard_type,
      layout: layout_config,
      created_at: Time.current,
      updated_at: Time.current
    }

    # Persist to database
    save_dashboard_to_db(user_id, dashboard_type, layout_config)

    { success: true, dashboard_saved: true }
  end

  # Subscribe user to dashboard updates
  def subscribe_to_dashboard(user_id, dashboard_type, connection_id)
    subscription_key = "#{user_id}:#{dashboard_type}"
    @dashboard_subscriptions[subscription_key] ||= []
    @dashboard_subscriptions[subscription_key] << connection_id

    Rails.logger.info "User #{user_id} subscribed to #{dashboard_type} dashboard updates"
  end

  # Unsubscribe user from dashboard updates
  def unsubscribe_from_dashboard(user_id, dashboard_type, connection_id)
    subscription_key = "#{user_id}:#{dashboard_type}"
    @dashboard_subscriptions[subscription_key]&.delete(connection_id)

    Rails.logger.info "User #{user_id} unsubscribed from #{dashboard_type} dashboard updates"
  end

  # Broadcast update to subscribed users
  def broadcast_dashboard_update(dashboard_type, update_data)
    @dashboard_subscriptions.each do |subscription_key, connection_ids|
      if subscription_key.ends_with?(":#{dashboard_type}")
        connection_ids.each do |connection_id|
          broadcast_to_connection(connection_id, update_data)
        end
      end
    end
  end

  # Get available dashboard templates
  def get_dashboard_templates
    {
      executive: {
        name: "Executive Dashboard",
        description: "High-level KPIs and strategic metrics",
        target_audience: "C-level executives and senior management",
        refresh_interval: "5 minutes",
        widget_count: 5
      },
      operational: {
        name: "Operational Dashboard",
        description: "Real-time operational metrics and monitoring",
        target_audience: "Operations managers and team leads",
        refresh_interval: "1 minute",
        widget_count: 5
      },
      analytical: {
        name: "Analytics Dashboard",
        description: "Advanced analytics and predictive insights",
        target_audience: "Data analysts and business intelligence teams",
        refresh_interval: "15 minutes",
        widget_count: 5
      },
      financial: {
        name: "Financial Dashboard",
        description: "Financial performance and profitability metrics",
        target_audience: "Finance teams and controllers",
        refresh_interval: "10 minutes",
        widget_count: 4
      }
    }
  end

  # Clone dashboard template for customization
  def clone_dashboard_template(user_id, template_name, custom_name)
    template = DASHBOARD_LAYOUTS[template_name.to_sym]
    return { success: false, error: "Template not found" } unless template

    custom_dashboard = template.deep_dup
    custom_dashboard[:name] = custom_name
    custom_dashboard[:created_from_template] = template_name
    custom_dashboard[:created_at] = Time.current

    save_user_dashboard(user_id, custom_name.parameterize.underscore.to_sym, custom_dashboard)
  end

  # Export dashboard configuration
  def export_dashboard_config(user_id, dashboard_type)
    user_key = "#{user_id}:#{dashboard_type}"
    dashboard_config = @user_dashboards[user_key]

    return { success: false, error: "Dashboard not found" } unless dashboard_config

    {
      success: true,
      export_data: {
        dashboard_type: dashboard_type,
        layout: dashboard_config[:layout],
        exported_at: Time.current,
        version: "1.0"
      }
    }
  end

  # Import dashboard configuration
  def import_dashboard_config(user_id, import_data)
    return { success: false, error: "Invalid import data" } unless import_data[:layout]

    dashboard_type = import_data[:dashboard_type] || "imported_dashboard"
    save_user_dashboard(user_id, dashboard_type, import_data[:layout])
  end

  private

  def validate_dashboard_config(config)
    errors = []

    # Check required fields
    errors << "Grid configuration missing" unless config[:grid]
    errors << "Widgets configuration missing" unless config[:widgets]

    # Validate grid
    if config[:grid]
      errors << "Grid must have columns and rows" unless config[:grid][:columns] && config[:grid][:rows]
    end

    # Validate widgets
    if config[:widgets]
      config[:widgets].each_with_index do |widget, index|
        errors << "Widget #{index}: name missing" unless widget[:name]
        errors << "Widget #{index}: position missing" unless widget[:position]

        if widget[:position]
          pos = widget[:position]
          errors << "Widget #{index}: invalid position coordinates" unless pos[:x] && pos[:y] && pos[:w] && pos[:h]
        end
      end
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def save_dashboard_to_db(user_id, dashboard_type, layout_config)
    # Save to database for persistence
    dashboard_record = UserDashboard.find_or_initialize_by(
      user_id: user_id,
      dashboard_type: dashboard_type.to_s
    )

    dashboard_record.update!(
      layout_config: layout_config,
      updated_at: Time.current
    )

    dashboard_record
  end

  def broadcast_to_connection(connection_id, data)
    # Broadcast data to WebSocket connection
    ActionCable.server.broadcast("dashboard_updates_#{connection_id}", {
      type: "dashboard_update",
      data: data,
      timestamp: Time.current
    })
  rescue => e
    Rails.logger.warn "Failed to broadcast to connection #{connection_id}: #{e.message}"
  end
end

# Model for persisting user dashboard configurations
class UserDashboard < ApplicationRecord
  belongs_to :user

  validates :dashboard_type, presence: true
  validates :layout_config, presence: true

  serialize :layout_config, JSON
end
