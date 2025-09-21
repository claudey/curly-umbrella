class Ui::InputComponent < ViewComponent::Base
  include Ui::DesignSystem

  SIZES = %w[sm md lg].freeze
  STATES = %w[default error success disabled].freeze

  def initialize(
    name:,
    type: "text",
    value: nil,
    placeholder: nil,
    label: nil,
    hint: nil,
    error: nil,
    size: "md",
    state: "default",
    required: false,
    disabled: false,
    readonly: false,
    autocomplete: nil,
    icon: nil,
    icon_position: :left,
    class: nil,
    **options
  )
    @name = name
    @type = type
    @value = value
    @placeholder = placeholder
    @label = label
    @hint = hint
    @error = error
    @size = size.to_s
    @state = determine_state(state, error, disabled)
    @required = required
    @disabled = disabled
    @readonly = readonly
    @autocomplete = autocomplete
    @icon = icon
    @icon_position = icon_position.to_sym
    @additional_classes = binding.local_variable_get(:class)
    @options = options

    validate_size!
    validate_state!
  end

  private

  attr_reader :name, :type, :value, :placeholder, :label, :hint, :error, :size, :state,
              :required, :disabled, :readonly, :autocomplete, :icon, :icon_position,
              :additional_classes, :options

  def determine_state(provided_state, error, disabled)
    return "disabled" if disabled
    return "error" if error.present?
    provided_state.to_s
  end

  def input_classes
    base_classes = Ui::DesignSystem.input_classes(
      size: size.to_sym,
      state: state.to_sym
    )

    additional_classes_array = []
    additional_classes_array << "pl-10" if icon_left?
    additional_classes_array << "pr-10" if icon_right?
    additional_classes_array << additional_classes if additional_classes

    [ base_classes, *additional_classes_array ].compact.join(" ")
  end

  def wrapper_classes
    classes = [ "relative" ]
    classes << "opacity-50" if disabled
    classes.join(" ")
  end

  def label_classes
    base_classes = "block text-sm font-medium mb-1"

    case state
    when "error"
      "#{base_classes} text-error-700"
    when "success"
      "#{base_classes} text-success-700"
    when "disabled"
      "#{base_classes} text-neutral-400"
    else
      "#{base_classes} text-neutral-700"
    end
  end

  def hint_classes
    base_classes = "mt-1 text-xs"

    case state
    when "error"
      "#{base_classes} text-error-600"
    when "success"
      "#{base_classes} text-success-600"
    else
      "#{base_classes} text-neutral-500"
    end
  end

  def icon_classes
    base_classes = "absolute top-1/2 transform -translate-y-1/2 pointer-events-none"
    position_classes = icon_left? ? "left-3" : "right-3"

    color_classes = case state
    when "error" then "text-error-500"
    when "success" then "text-success-500"
    when "disabled" then "text-neutral-300"
    else "text-neutral-400"
    end

    "#{base_classes} #{position_classes} #{color_classes}"
  end

  def icon_size
    case size
    when "sm" then Ui::DesignSystem::ICON_SIZES[:sm]
    when "md" then Ui::DesignSystem::ICON_SIZES[:md]
    when "lg" then Ui::DesignSystem::ICON_SIZES[:lg]
    else Ui::DesignSystem::ICON_SIZES[:md]
    end
  end

  def input_attributes
    base_attrs = {
      type: type,
      name: name,
      id: name,
      value: value,
      placeholder: placeholder,
      class: input_classes,
      required: required,
      disabled: disabled,
      readonly: readonly,
      **options
    }

    base_attrs[:autocomplete] = autocomplete if autocomplete
    base_attrs["aria-invalid"] = "true" if state == "error"
    base_attrs["aria-describedby"] = "#{name}_hint" if hint.present? || error.present?

    base_attrs
  end

  def show_label?
    label.present?
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

  def show_hint?
    hint.present? || error.present?
  end

  def hint_text
    error.present? ? error : hint
  end

  def validate_size!
    return if SIZES.include?(size)

    raise ArgumentError, "Invalid size: #{size}. Must be one of #{SIZES.join(', ')}"
  end

  def validate_state!
    return if STATES.include?(state)

    raise ArgumentError, "Invalid state: #{state}. Must be one of #{STATES.join(', ')}"
  end
end
