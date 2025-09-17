class Ui::ResponsiveLayoutComponent < ViewComponent::Base
  include Ui::DesignSystem

  renders_one :sidebar
  renders_one :header
  renders_one :main_content
  renders_one :footer

  LAYOUTS = %w[default sidebar_left sidebar_right dashboard mobile_stack].freeze

  def initialize(
    layout: "default",
    container: true,
    padding: true,
    mobile_navigation: true,
    breakpoint: "lg",
    class: nil,
    **options
  )
    @layout = layout.to_s
    @container = container
    @padding = padding
    @mobile_navigation = mobile_navigation
    @breakpoint = breakpoint.to_s
    @additional_classes = binding.local_variable_get(:class)
    @options = options

    validate_layout!
  end

  private

  attr_reader :layout, :container, :padding, :mobile_navigation, :breakpoint, :additional_classes, :options

  def wrapper_classes
    base_classes = ["min-h-screen", "bg-neutral-50"]
    base_classes << container_classes if container
    base_classes << additional_classes if additional_classes
    base_classes.join(" ")
  end

  def container_classes
    case layout
    when "dashboard"
      "max-w-7xl mx-auto"
    when "sidebar_left", "sidebar_right"
      "max-w-none"
    else
      "max-w-6xl mx-auto"
    end
  end

  def layout_classes
    base_classes = ["flex", "flex-col", "min-h-screen"]
    
    case layout
    when "sidebar_left"
      base_classes = ["flex", "min-h-screen"]
      base_classes << "flex-col #{breakpoint}:flex-row"
    when "sidebar_right"
      base_classes = ["flex", "min-h-screen"]
      base_classes << "flex-col #{breakpoint}:flex-row-reverse"
    when "dashboard"
      base_classes << "#{breakpoint}:grid #{breakpoint}:grid-cols-12 #{breakpoint}:gap-6"
    when "mobile_stack"
      base_classes = ["flex", "flex-col", "space-y-4"]
    end

    base_classes.join(" ")
  end

  def header_classes
    base_classes = ["bg-white", "shadow-sm", "border-b", "border-neutral-200"]
    base_classes << "sticky top-0 z-40" unless layout == "mobile_stack"
    base_classes << (padding ? "p-4 #{breakpoint}:p-6" : "")
    base_classes.join(" ")
  end

  def sidebar_classes
    base_classes = ["bg-white", "border-neutral-200"]
    
    case layout
    when "sidebar_left"
      base_classes << "border-r w-full #{breakpoint}:w-64 #{breakpoint}:flex-shrink-0"
      base_classes << "#{breakpoint}:sticky #{breakpoint}:top-0 #{breakpoint}:h-screen #{breakpoint}:overflow-y-auto"
    when "sidebar_right"
      base_classes << "border-l w-full #{breakpoint}:w-64 #{breakpoint}:flex-shrink-0"
      base_classes << "#{breakpoint}:sticky #{breakpoint}:top-0 #{breakpoint}:h-screen #{breakpoint}:overflow-y-auto"
    when "dashboard"
      base_classes << "#{breakpoint}:col-span-3 xl:col-span-2"
    end

    base_classes << (padding ? "p-4 #{breakpoint}:p-6" : "")
    base_classes.join(" ")
  end

  def main_classes
    base_classes = ["flex-1", "bg-white"]
    
    case layout
    when "sidebar_left", "sidebar_right"
      base_classes << "#{breakpoint}:overflow-y-auto"
    when "dashboard"
      base_classes << "#{breakpoint}:col-span-9 xl:col-span-10"
    end

    base_classes << (padding ? "p-4 #{breakpoint}:p-6" : "")
    base_classes.join(" ")
  end

  def footer_classes
    base_classes = ["bg-white", "border-t", "border-neutral-200", "mt-auto"]
    base_classes << (padding ? "p-4 #{breakpoint}:p-6" : "")
    base_classes.join(" ")
  end

  def mobile_nav_classes
    "#{breakpoint}:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-neutral-200 z-50"
  end

  def show_sidebar?
    sidebar?
  end

  def show_mobile_nav?
    mobile_navigation && show_sidebar?
  end

  def validate_layout!
    return if LAYOUTS.include?(layout)

    raise ArgumentError, "Invalid layout: #{layout}. Must be one of #{LAYOUTS.join(', ')}"
  end
end