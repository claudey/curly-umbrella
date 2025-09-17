class Ui::ButtonComponent < ViewComponent::Base
  include Ui::DesignSystem

  VARIANTS = %w[primary secondary success warning error outline ghost].freeze
  SIZES = %w[xs sm md lg xl].freeze

  def initialize(
    variant: "primary",
    size: "md",
    outline: false,
    disabled: false,
    loading: false,
    wide: false,
    icon: nil,
    icon_position: :left,
    href: nil,
    method: nil,
    data: {},
    class: nil,
    **options
  )
    @variant = variant.to_s
    @size = size.to_s
    @outline = outline
    @disabled = disabled
    @loading = loading
    @wide = wide
    @icon = icon
    @icon_position = icon_position.to_sym
    @href = href
    @method = method
    @data = data
    @additional_classes = binding.local_variable_get(:class)
    @options = options

    validate_variant!
    validate_size!
  end

  private

  attr_reader :variant, :size, :outline, :disabled, :loading, :wide,
              :icon, :icon_position, :href, :method, :data, :additional_classes, :options

  def tag_name
    href ? :a : :button
  end

  def tag_options
    base_options = {
      class: button_classes,
      disabled: disabled_state,
      **data_attributes,
      **options
    }

    if href
      base_options[:href] = href
      base_options[:method] = method if method
    else
      base_options[:type] ||= "button"
    end

    base_options
  end

  def button_classes
    # Use the design system button classes
    design_variant = outline ? :outline : variant.to_sym
    base_classes = Ui::DesignSystem.button_classes(
      variant: design_variant,
      size: size.to_sym,
      disabled: disabled
    )

    additional_classes_array = []
    additional_classes_array << "w-full" if wide
    additional_classes_array << "relative" if loading
    additional_classes_array << additional_classes if additional_classes

    [base_classes, *additional_classes_array].compact.join(" ")
  end

  def disabled_state
    disabled || loading || nil
  end

  def data_attributes
    return {} unless data.any?

    data.transform_keys { |key| "data-#{key.to_s.dasherize}" }
  end

  def show_icon?
    icon.present?
  end

  def icon_left?
    icon_position == :left
  end

  def icon_right?
    icon_position == :right
  end

  def icon_size
    case size
    when "xs" then Ui::DesignSystem::ICON_SIZES[:xs]
    when "sm" then Ui::DesignSystem::ICON_SIZES[:sm]
    when "md" then Ui::DesignSystem::ICON_SIZES[:md]
    when "lg" then Ui::DesignSystem::ICON_SIZES[:lg]
    when "xl" then Ui::DesignSystem::ICON_SIZES[:xl]
    else Ui::DesignSystem::ICON_SIZES[:md]
    end
  end

  def content_classes
    classes = []
    if show_icon?
      classes << "flex" << "items-center" << "justify-center"
      classes << "space-x-2" if content.present?
    end
    classes.join(" ")
  end

  def loading_spinner
    return unless loading

    content_tag :span, class: "absolute inset-0 flex items-center justify-center" do
      content_tag :svg, 
        class: "animate-spin h-#{icon_size} w-#{icon_size} text-current",
        fill: "none",
        viewBox: "0 0 24 24" do
        concat content_tag(:circle, nil, class: "opacity-25", cx: "12", cy: "12", r: "10", stroke: "currentColor", "stroke-width": "4")
        concat content_tag(:path, nil, class: "opacity-75", fill: "currentColor", d: "m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z")
      end
    end
  end

  def validate_variant!
    return if VARIANTS.include?(variant)

    raise ArgumentError, "Invalid variant: #{variant}. Must be one of #{VARIANTS.join(', ')}"
  end

  def validate_size!
    return if SIZES.include?(size)

    raise ArgumentError, "Invalid size: #{size}. Must be one of #{SIZES.join(', ')}"
  end
end