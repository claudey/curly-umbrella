class Ui::AdvancedButtonComponent < ApplicationComponent
  VARIANTS = %w[primary secondary accent neutral ghost outline success warning error info].freeze
  SIZES = %w[xs sm md lg xl].freeze
  SHAPES = %w[default square circle].freeze

  def initialize(
    variant: "primary",
    size: "md",
    shape: "default",
    href: nil,
    method: nil,
    disabled: false,
    loading: false,
    wide: false,
    block: false,
    glass: false,
    no_animation: false,
    icon_left: nil,
    icon_right: nil,
    tooltip: nil,
    confirm: nil,
    class: nil,
    **options
  )
    @variant = variant.to_s
    @size = size.to_s
    @shape = shape.to_s
    @href = href
    @method = method
    @disabled = disabled
    @loading = loading
    @wide = wide
    @block = block
    @glass = glass
    @no_animation = no_animation
    @icon_left = icon_left
    @icon_right = icon_right
    @tooltip = tooltip
    @confirm = confirm
    @additional_classes = binding.local_variable_get(:class)
    @options = options

    validate_variant!
    validate_size!
    validate_shape!
  end

  private

  attr_reader :variant, :size, :shape, :href, :method, :disabled, :loading, :wide, :block,
              :glass, :no_animation, :icon_left, :icon_right, :tooltip, :confirm,
              :additional_classes, :options

  def tag_name
    href ? :a : :button
  end

  def button_classes
    classes = ["btn"]

    # DaisyUI variant classes
    case variant
    when "primary" then classes << "btn-primary"
    when "secondary" then classes << "btn-secondary"
    when "accent" then classes << "btn-accent"
    when "neutral" then classes << "btn-neutral"
    when "ghost" then classes << "btn-ghost"
    when "outline" then classes << "btn-outline"
    when "success" then classes << "btn-success"
    when "warning" then classes << "btn-warning"
    when "error" then classes << "btn-error"
    when "info" then classes << "btn-info"
    end

    # DaisyUI size classes
    case size
    when "xs" then classes << "btn-xs"
    when "sm" then classes << "btn-sm"
    when "lg" then classes << "btn-lg"
    when "xl" then classes << "btn-xl"
    # md is default, no class needed
    end

    # DaisyUI shape classes
    case shape
    when "square" then classes << "btn-square"
    when "circle" then classes << "btn-circle"
    end

    # DaisyUI modifier classes
    classes << "btn-wide" if wide
    classes << "btn-block" if block
    classes << "glass" if glass
    classes << "no-animation" if no_animation
    classes << "btn-disabled" if disabled
    classes << "loading" if loading

    classes << additional_classes if additional_classes

    classes.compact.join(" ")
  end

  def button_attributes
    attrs = { class: button_classes }
    
    if tag_name == :button
      attrs[:type] = options[:type] || "button"
      attrs[:disabled] = true if disabled || loading
    else
      attrs[:href] = href
    end

    # Rails UJS attributes
    attrs[:"data-method"] = method if method && href
    attrs[:"data-confirm"] = confirm if confirm
    
    # Tooltip
    if tooltip
      attrs[:title] = tooltip
      attrs[:"data-controller"] = "tooltip"
    end

    attrs.merge!(options.except(:type))
    attrs
  end

  def show_left_icon?
    icon_left.present? && !loading
  end

  def show_right_icon?
    icon_right.present? && !loading
  end

  def show_loading?
    loading
  end

  def icon_size
    case size
    when "xs" then 12
    when "sm" then 16
    when "md" then 20
    when "lg" then 24
    when "xl" then 28
    else 20
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

  def validate_shape!
    return if SHAPES.include?(shape)
    raise ArgumentError, "Invalid shape: #{shape}. Must be one of #{SHAPES.join(', ')}"
  end
end