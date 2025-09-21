class Ui::Form::InputComponent < ViewComponent::Base
  def initialize(
    form:,
    name:,
    type: "text",
    label: nil,
    placeholder: nil,
    hint: nil,
    required: false,
    disabled: false,
    readonly: false,
    size: "md",
    bordered: true,
    ghost: false,
    icon: nil,
    icon_position: :left,
    **options
  )
    @form = form
    @name = name
    @type = type
    @label = label || name.to_s.humanize
    @placeholder = placeholder
    @hint = hint
    @required = required
    @disabled = disabled
    @readonly = readonly
    @size = size
    @bordered = bordered
    @ghost = ghost
    @icon = icon
    @icon_position = icon_position.to_sym
    @options = options
  end

  private

  attr_reader :form, :name, :type, :label, :placeholder, :hint, :required, :disabled, :readonly,
              :size, :bordered, :ghost, :icon, :icon_position, :options

  def input_classes
    classes = [ "input", "w-full" ]
    classes << "input-#{size}" unless size == "md"
    classes << "input-bordered" if bordered
    classes << "input-ghost" if ghost
    classes << "input-error" if has_error?
    classes << options[:class] if options[:class]

    classes.join(" ")
  end

  def wrapper_classes
    classes = [ "form-control", "w-full" ]
    classes << "max-w-xs" if size == "xs"
    classes.join(" ")
  end

  def label_classes
    classes = [ "label" ]
    classes << "label-text" if show_label?
    classes.join(" ")
  end

  def show_label?
    label.present?
  end

  def show_hint?
    hint.present?
  end

  def show_icon?
    icon.present?
  end

  def has_error?
    form.object&.errors&.key?(name)
  end

  def error_messages
    return [] unless has_error?

    form.object.errors[name]
  end

  def input_options
    base_options = {
      class: input_classes,
      placeholder: placeholder,
      required: required,
      disabled: disabled,
      readonly: readonly,
      **options.except(:class)
    }

    if type == "email"
      base_options[:type] = "email"
      base_options[:autocomplete] = "email"
    elsif type == "password"
      base_options[:type] = "password"
      base_options[:autocomplete] = "current-password"
    elsif type == "tel"
      base_options[:type] = "tel"
      base_options[:autocomplete] = "tel"
    else
      base_options[:type] = type
    end

    base_options
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
end
