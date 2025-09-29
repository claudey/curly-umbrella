class DashboardWidgetComponent < ApplicationComponent
  def initialize(title:, size: "medium", type: "default", refresh_url: nil, auto_refresh: nil, collapsible: false, removable: false, draggable: false, loading: false, error: nil, actions: [], classes: "")
    @title = title
    @size = size
    @type = type
    @refresh_url = refresh_url
    @auto_refresh = auto_refresh
    @collapsible = collapsible
    @removable = removable
    @draggable = draggable
    @loading = loading
    @error = error
    @actions = actions
    @classes = classes
  end

  private

  def widget_classes
    base = "dashboard-widget card bg-base-100 shadow-sm"
    base += " #{size_classes}"
    base += " #{type_classes}"
    base += " #{@classes}" if @classes.present?
    base += " widget-draggable" if @draggable
    base
  end

  def size_classes
    case @size
    when "small"
      "col-span-1 row-span-1"
    when "medium"
      "col-span-2 row-span-1"
    when "large"
      "col-span-2 row-span-2"
    when "full"
      "col-span-full"
    else
      "col-span-2 row-span-1"
    end
  end

  def type_classes
    case @type
    when "chart"
      "widget-chart"
    when "metric"
      "widget-metric"
    when "list"
      "widget-list"
    when "activity"
      "widget-activity"
    else
      "widget-default"
    end
  end

  def header_classes
    base = "card-header flex justify-between items-center p-4 border-b border-base-300"
    base += " cursor-move" if @draggable
    base
  end

  def body_classes
    base = "card-body p-4"
    base += " overflow-auto" if @type == "list" || @type == "activity"
    base
  end

  def stimulus_data
    data = {
      "dashboard-widget-title-value" => @title,
      "dashboard-widget-size-value" => @size,
      "dashboard-widget-type-value" => @type
    }

    if @refresh_url
      data["dashboard-widget-refresh-url-value"] = @refresh_url
    end

    if @auto_refresh
      data["dashboard-widget-auto-refresh-value"] = @auto_refresh
    end

    data
  end

  def widget_id
    @title.parameterize
  end

  def has_header_actions?
    @collapsible || @removable || @refresh_url.present? || @actions.any?
  end
end
