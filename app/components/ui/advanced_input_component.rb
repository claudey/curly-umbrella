class Ui::AdvancedInputComponent < ApplicationComponent
  SIZES = %w[xs sm md lg].freeze
  VARIANTS = %w[bordered ghost].freeze

  def initialize(
    name:,
    value: nil,
    type: "text",
    placeholder: nil,
    label: nil,
    hint: nil,
    error: nil,
    size: "md",
    variant: "bordered",
    disabled: false,
    readonly: false,
    required: false,
    icon_left: nil,
    icon_right: nil,
    prefix: nil,
    suffix: nil,
    floating_label: false,
    class: nil,
    **options
  )
    @name = name
    @value = value
    @type = type
    @placeholder = placeholder
    @label = label
    @hint = hint
    @error = error
    @size = size.to_s
    @variant = variant.to_s
    @disabled = disabled
    @readonly = readonly
    @required = required
    @icon_left = icon_left
    @icon_right = icon_right
    @prefix = prefix
    @suffix = suffix
    @floating_label = floating_label
    @additional_classes = binding.local_variable_get(:class)
    @options = options

    validate_size!
    validate_variant!
  end

  private

  attr_reader :name, :value, :type, :placeholder, :label, :hint, :error, :size, :variant,
              :disabled, :readonly, :required, :icon_left, :icon_right, :prefix, :suffix,
              :floating_label, :additional_classes, :options

  def wrapper_classes
    classes = ["form-control", "w-full"]
    classes << additional_classes if additional_classes
    classes.compact.join(" ")
  end

  def input_group_classes
    classes = []
    
    if has_prefix? || has_suffix? || has_icons?
      classes << "input-group"
    end
    
    classes.join(" ")
  end

  def input_classes
    classes = ["input"]
    
    # DaisyUI variant classes
    case variant
    when "bordered" then classes << "input-bordered"
    when "ghost" then classes << "input-ghost"
    end

    # DaisyUI size classes
    case size
    when "xs" then classes << "input-xs"
    when "sm" then classes << "input-sm"
    when "lg" then classes << "input-lg"
    # md is default, no class needed
    end

    # State classes
    classes << "input-error" if has_error?
    classes << "input-disabled" if disabled

    # Focus classes for floating labels
    if floating_label
      classes << "placeholder-transparent"
      classes << "peer"
    end

    classes.compact.join(" ")
  end

  def label_classes
    classes = ["label"]
    
    if floating_label
      classes.concat([
        "absolute", "text-sm", "text-gray-500", "dark:text-gray-400", 
        "duration-300", "transform", "-translate-y-4", "scale-75", 
        "top-2", "z-10", "origin-[0]", "bg-white", "dark:bg-gray-900", 
        "px-2", "peer-focus:px-2", "peer-focus:text-blue-600", 
        "peer-focus:dark:text-blue-500", "peer-placeholder-shown:scale-100", 
        "peer-placeholder-shown:-translate-y-1/2", "peer-placeholder-shown:top-1/2",
        "peer-focus:top-2", "peer-focus:scale-75", "peer-focus:-translate-y-4",
        "left-1"
      ])
    end
    
    classes.join(" ")
  end

  def input_attributes
    attrs = {
      name: name,
      type: type,
      class: input_classes,
      disabled: disabled,
      readonly: readonly,
      required: required
    }

    attrs[:value] = value if value.present?
    attrs[:placeholder] = placeholder if placeholder.present? && !floating_label
    attrs[:placeholder] = " " if floating_label # Required for floating label effect
    
    attrs.merge!(options)
    attrs
  end

  def field_id
    @field_id ||= options[:id] || "#{name}_#{SecureRandom.hex(4)}"
  end

  def has_label?
    label.present?
  end

  def has_hint?
    hint.present?
  end

  def has_error?
    error.present?
  end

  def has_prefix?
    prefix.present?
  end

  def has_suffix?
    suffix.present?
  end

  def has_icons?
    icon_left.present? || icon_right.present?
  end

  def icon_size
    case size
    when "xs" then 12
    when "sm" then 16
    when "md" then 20
    when "lg" then 24
    else 20
    end
  end

  def validate_size!
    return if SIZES.include?(size)
    raise ArgumentError, "Invalid size: #{size}. Must be one of #{SIZES.join(', ')}"
  end

  def validate_variant!
    return if VARIANTS.include?(variant)
    raise ArgumentError, "Invalid variant: #{variant}. Must be one of #{VARIANTS.join(', ')}"
  end
end