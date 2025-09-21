class Ui::ResponsiveNavigationComponent < ViewComponent::Base
  include Ui::DesignSystem

  renders_many :nav_items, "Ui::ResponsiveNavigationComponent::NavItemComponent"
  renders_one :brand
  renders_one :user_menu

  def initialize(
    variant: "header",
    sticky: true,
    transparent: false,
    mobile_breakpoint: "lg",
    class: nil,
    **options
  )
    @variant = variant.to_s
    @sticky = sticky
    @transparent = transparent
    @mobile_breakpoint = mobile_breakpoint.to_s
    @additional_classes = binding.local_variable_get(:class)
    @options = options
  end

  private

  attr_reader :variant, :sticky, :transparent, :mobile_breakpoint, :additional_classes, :options

  def nav_classes
    base_classes = [ "relative", "z-40" ]
    base_classes << "sticky top-0" if sticky

    if transparent
      base_classes << "bg-transparent"
    else
      base_classes << "bg-white border-b border-neutral-200 shadow-sm"
    end

    base_classes << additional_classes if additional_classes
    base_classes.join(" ")
  end

  def container_classes
    "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8"
  end

  def inner_nav_classes
    "flex items-center justify-between h-16"
  end

  def brand_classes
    "flex-shrink-0 flex items-center"
  end

  def desktop_nav_classes
    "hidden #{mobile_breakpoint}:flex #{mobile_breakpoint}:items-center #{mobile_breakpoint}:space-x-8"
  end

  def mobile_button_classes
    "#{mobile_breakpoint}:hidden inline-flex items-center justify-center p-2 rounded-md text-neutral-400 hover:text-neutral-500 hover:bg-neutral-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-primary-500"
  end

  def mobile_menu_classes
    "#{mobile_breakpoint}:hidden absolute top-16 inset-x-0 bg-white shadow-lg border-b border-neutral-200"
  end

  def user_menu_classes
    "flex items-center space-x-4"
  end

  class NavItemComponent < ViewComponent::Base
    def initialize(
      href: nil,
      active: false,
      icon: nil,
      badge: nil,
      mobile_only: false,
      desktop_only: false,
      **options
    )
      @href = href
      @active = active
      @icon = icon
      @badge = badge
      @mobile_only = mobile_only
      @desktop_only = desktop_only
      @options = options
    end

    private

    attr_reader :href, :active, :icon, :badge, :mobile_only, :desktop_only, :options

    def nav_item_classes(mobile: false)
      base_classes = [
        "inline-flex", "items-center", "px-1", "pt-1", "text-sm", "font-medium",
        "transition-colors", "duration-200"
      ]

      if mobile
        base_classes = [
          "block", "px-3", "py-2", "text-base", "font-medium", "border-l-4",
          "transition-colors", "duration-200"
        ]
      end

      if active
        if mobile
          base_classes << "bg-primary-50 border-primary-500 text-primary-700"
        else
          base_classes << "border-primary-500 text-primary-600"
        end
      else
        if mobile
          base_classes << "border-transparent text-neutral-600 hover:bg-neutral-50 hover:border-neutral-300 hover:text-neutral-800"
        else
          base_classes << "border-transparent text-neutral-500 hover:border-neutral-300 hover:text-neutral-700"
        end
      end

      base_classes.join(" ")
    end

    def wrapper_classes
      classes = []
      classes << "lg:hidden" if mobile_only
      classes << "hidden lg:block" if desktop_only
      classes.join(" ")
    end

    def show_icon?
      icon.present?
    end

    def show_badge?
      badge.present?
    end

    def call
      content_tag :div, class: wrapper_classes do
        # Desktop version
        desktop_link = if href
          link_to href, class: nav_item_classes, **options do
            concat(helpers.phosphor_icon(icon, size: 16, class: "mr-2")) if show_icon?
            concat(content_tag(:span, content))
            concat(content_tag(:span, badge, class: "ml-2 bg-primary-100 text-primary-800 text-xs font-medium px-2.5 py-0.5 rounded-full")) if show_badge?
          end
        else
          content_tag :span, class: nav_item_classes do
            concat(helpers.phosphor_icon(icon, size: 16, class: "mr-2")) if show_icon?
            concat(content_tag(:span, content))
            concat(content_tag(:span, badge, class: "ml-2 bg-primary-100 text-primary-800 text-xs font-medium px-2.5 py-0.5 rounded-full")) if show_badge?
          end
        end

        # Mobile version
        mobile_link = if href
          link_to href, class: nav_item_classes(mobile: true), **options do
            concat(helpers.phosphor_icon(icon, size: 20, class: "mr-3")) if show_icon?
            concat(content_tag(:span, content))
            concat(content_tag(:span, badge, class: "ml-auto bg-primary-100 text-primary-800 text-xs font-medium px-2.5 py-0.5 rounded-full")) if show_badge?
          end
        else
          content_tag :span, class: nav_item_classes(mobile: true) do
            concat(helpers.phosphor_icon(icon, size: 20, class: "mr-3")) if show_icon?
            concat(content_tag(:span, content))
            concat(content_tag(:span, badge, class: "ml-auto bg-primary-100 text-primary-800 text-xs font-medium px-2.5 py-0.5 rounded-full")) if show_badge?
          end
        end

        concat(content_tag(:div, desktop_link, class: "hidden #{parent.mobile_breakpoint}:block"))
        concat(content_tag(:div, mobile_link, class: "#{parent.mobile_breakpoint}:hidden"))
      end
    end
  end
end
