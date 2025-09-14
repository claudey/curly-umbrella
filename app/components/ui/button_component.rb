class Ui::ButtonComponent < ViewComponent::Base
  VARIANTS = %w[primary secondary accent neutral ghost link].freeze
  SIZES = %w[xs sm md lg].freeze

  def initialize(
    variant: "primary",
    size: "md",
    outline: false,
    disabled: false,
    loading: false,
    wide: false,
    circle: false,
    square: false,
    glass: false,
    no_animation: false,
    icon: nil,
    icon_position: :left,
    href: nil,
    method: nil,
    data: {},
    **options
  )
    @variant = variant.to_s
    @size = size.to_s
    @outline = outline
    @disabled = disabled
    @loading = loading
    @wide = wide
    @circle = circle
    @square = square
    @glass = glass
    @no_animation = no_animation
    @icon = icon
    @icon_position = icon_position.to_sym
    @href = href
    @method = method
    @data = data
    @options = options

    validate_variant!
    validate_size!
  end

  private

  attr_reader :variant, :size, :outline, :disabled, :loading, :wide, :circle, :square, :glass, :no_animation,
              :icon, :icon_position, :href, :method, :data, :options

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
    classes = ["btn"]
    classes << "btn-#{variant}" if VARIANTS.include?(variant)
    classes << "btn-#{size}" if SIZES.include?(size)
    classes << "btn-outline" if outline
    classes << "btn-wide" if wide
    classes << "btn-circle" if circle
    classes << "btn-square" if square
    classes << "btn-glass" if glass
    classes << "no-animation" if no_animation
    classes << "loading" if loading

    classes.join(" ")
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
    when "xs" then 3
    when "sm" then 4
    when "md" then 4
    when "lg" then 5
    else 4
    end
  end

  def content_classes
    classes = []
    classes << "flex" << "items-center" << "justify-center" if show_icon?
    classes << "space-x-2" if show_icon? && content.present?
    classes.join(" ")
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