class Ui::DraggableWidgetComponent < ApplicationComponent
  renders_one :header
  renders_one :body
  renders_one :footer

  WIDGET_TYPES = %w[chart stat metric table list feed].freeze
  SIZES = %w[sm md lg xl full].freeze

  def initialize(
    widget_type: "metric",
    size: "md", 
    title: nil,
    subtitle: nil,
    icon: nil,
    value: nil,
    change: nil,
    change_type: nil,
    draggable: true,
    resizable: false,
    collapsible: false,
    removable: false,
    widget_id: nil,
    position: nil,
    class: nil,
    **options
  )
    @widget_type = widget_type.to_s
    @size = size.to_s
    @title = title
    @subtitle = subtitle  
    @icon = icon
    @value = value
    @change = change
    @change_type = change_type # :positive, :negative, :neutral
    @draggable = draggable
    @resizable = resizable
    @collapsible = collapsible
    @removable = removable
    @widget_id = widget_id || SecureRandom.hex(8)
    @position = position
    @additional_classes = binding.local_variable_get(:class)
    @options = options

    validate_widget_type!
    validate_size!
  end

  private

  attr_reader :widget_type, :size, :title, :subtitle, :icon, :value, :change, :change_type,
              :draggable, :resizable, :collapsible, :removable, :widget_id, :position,
              :additional_classes, :options

  def widget_classes
    classes = [
      "card", "bg-base-100", "shadow-lg", "border", "border-base-200",
      "transition-all", "duration-300", "hover:shadow-xl"
    ]
    
    # Size-based classes
    case size
    when "sm" then classes.concat(["w-64", "h-32"])
    when "md" then classes.concat(["w-80", "h-48"])
    when "lg" then classes.concat(["w-96", "h-64"])
    when "xl" then classes.concat(["w-full", "h-80"])
    when "full" then classes.concat(["w-full", "h-full"])
    end

    # Draggable styling
    if draggable
      classes.concat(["cursor-move", "hover:border-primary", "hover:ring-2", "hover:ring-primary/20"])
    end

    # Resizable styling
    classes << "resize" if resizable

    classes << additional_classes if additional_classes
    classes.compact.join(" ")
  end

  def widget_attributes
    attrs = {
      class: widget_classes,
      "data-controller" => controllers.join(" "),
      "data-widget-id" => widget_id,
      "data-widget-type" => widget_type,
      "data-widget-size" => size
    }

    if draggable
      attrs["draggable"] = true
      attrs["data-draggable-widget-position-value"] = position.to_json if position
    end

    attrs.merge!(options)
    attrs
  end

  def controllers
    controllers_list = ["widget"]
    controllers_list << "draggable-widget" if draggable
    controllers_list << "collapsible-card" if collapsible
    controllers_list
  end

  def header_classes
    classes = ["card-body", "pb-2"]
    classes << "cursor-move" if draggable
    classes.join(" ")
  end

  def body_classes
    "card-body pt-0 pb-2"
  end

  def footer_classes
    "card-body pt-0"
  end

  def show_header?
    title.present? || subtitle.present? || icon.present? || header?
  end

  def show_controls?
    removable || collapsible
  end

  def show_change?
    change.present? && widget_type == "metric"
  end

  def change_classes
    base_classes = ["text-sm", "font-medium"]
    
    case change_type&.to_sym
    when :positive then base_classes << "text-success"
    when :negative then base_classes << "text-error"
    else base_classes << "text-base-content/60"
    end

    base_classes.join(" ")
  end

  def change_icon
    case change_type&.to_sym
    when :positive then :arrow_up
    when :negative then :arrow_down
    else :minus
    end
  end

  def render_widget_content
    case widget_type
    when "stat" then render_stat_content
    when "metric" then render_metric_content
    when "chart" then render_chart_content
    when "table" then render_table_content
    when "list" then render_list_content
    when "feed" then render_feed_content
    else
      render_default_content
    end
  end

  def render_stat_content
    content_tag :div, class: "stat" do
      content = ""
      content += content_tag(:div, icon(icon, size: 24), class: "stat-figure text-primary") if icon.present?
      content += content_tag(:div, title, class: "stat-title") if title.present?
      content += content_tag(:div, value, class: "stat-value text-primary") if value.present?
      content += content_tag(:div, subtitle, class: "stat-desc") if subtitle.present?
      content.html_safe
    end
  end

  def render_metric_content
    content_tag :div, class: "text-center" do
      content = ""
      content += content_tag(:div, value, class: "text-3xl font-bold text-primary") if value.present?
      content += content_tag(:div, title, class: "text-sm text-base-content/70 mt-1") if title.present?
      if show_change?
        content += content_tag(:div, class: "flex items-center justify-center mt-2 #{change_classes}") do
          icon(change_icon, size: 16, class: "mr-1") + change.to_s
        end
      end
      content.html_safe
    end
  end

  def render_chart_content
    if body?
      render body
    else
      content_tag :div, class: "flex items-center justify-center h-32 text-base-content/50" do
        "Chart content goes here"
      end
    end
  end

  def render_table_content
    if body?
      render body
    else
      content_tag :div, class: "overflow-x-auto" do
        content_tag :table, class: "table table-compact w-full" do
          content_tag(:thead) do
            content_tag(:tr) do
              content_tag(:th, "Column 1") + content_tag(:th, "Column 2")
            end
          end +
          content_tag(:tbody) do
            content_tag(:tr) do
              content_tag(:td, "Data 1") + content_tag(:td, "Data 2")  
            end
          end
        end
      end
    end
  end

  def render_list_content
    if body?
      render body
    else
      content_tag :ul, class: "menu p-0" do
        3.times.map do |i|
          content_tag :li do
            content_tag :a, "List Item #{i + 1}", class: "text-sm"
          end
        end.join.html_safe
      end
    end
  end

  def render_feed_content
    if body?
      render body
    else
      content_tag :div, class: "space-y-3" do
        3.times.map do |i|
          content_tag :div, class: "flex items-center space-x-3" do
            content_tag(:div, class: "avatar placeholder") do
              content_tag(:div, class: "bg-neutral-focus text-neutral-content rounded-full w-8") do
                content_tag :span, class: "text-xs" do
                  (i + 1).to_s
                end
              end
            end +
            content_tag(:div, class: "flex-1") do
              content_tag(:div, "Feed Item #{i + 1}", class: "text-sm font-medium") +
              content_tag(:div, "Description", class: "text-xs text-base-content/60")
            end
          end
        end.join.html_safe
      end
    end
  end

  def render_default_content
    if body?
      render body
    else
      content_tag :div, class: "text-center text-base-content/50" do
        "Widget content"
      end
    end
  end

  def validate_widget_type!
    return if WIDGET_TYPES.include?(widget_type)
    raise ArgumentError, "Invalid widget_type: #{widget_type}. Must be one of #{WIDGET_TYPES.join(', ')}"
  end

  def validate_size!
    return if SIZES.include?(size)
    raise ArgumentError, "Invalid size: #{size}. Must be one of #{SIZES.join(', ')}"
  end
end