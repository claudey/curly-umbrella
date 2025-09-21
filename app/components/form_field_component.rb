class FormFieldComponent < ApplicationComponent
  option :form, Types::Any
  option :field, Types::Symbol
  option :type, Types::String, default: proc { "text" }
  option :label, Types::String.optional, default: proc { nil }
  option :placeholder, Types::String.optional, default: proc { nil }
  option :help_text, Types::String.optional, default: proc { nil }
  option :required, Types::Bool, default: proc { false }
  option :disabled, Types::Bool, default: proc { false }
  option :readonly, Types::Bool, default: proc { false }
  option :options, Types::Array.optional, default: proc { nil } # For select fields
  option :multiple, Types::Bool, default: proc { false }
  option :size, Types::String, default: proc { "normal" } # xs, sm, normal, lg
  option :validation, Types::Hash, default: proc { {} }
  option :stimulus_controller, Types::String.optional, default: proc { nil }
  option :stimulus_data, Types::Hash, default: proc { {} }
  option :wrapper_classes, Types::String, default: proc { "" }
  option :input_classes, Types::String, default: proc { "" }

  private

  def field_label
    @label || @field.to_s.humanize
  end

  def field_id
    "#{@form.object_name}_#{@field}"
  end

  def wrapper_css_classes
    base = "form-control w-full"
    base += " #{size_wrapper_class}"
    base += " #{@wrapper_classes}" if @wrapper_classes.present?
    base
  end

  def input_css_classes
    base = input_base_classes
    base += " #{size_input_class}"
    base += " #{error_classes}" if has_errors?
    base += " #{@input_classes}" if @input_classes.present?
    base
  end

  def input_base_classes
    case @type
    when "select"
      "select select-bordered"
    when "textarea"
      "textarea textarea-bordered"
    when "checkbox"
      "checkbox"
    when "radio"
      "radio"
    when "range"
      "range"
    when "file"
      "file-input file-input-bordered"
    else
      "input input-bordered"
    end
  end

  def size_wrapper_class
    case @size
    when "xs" then "max-w-xs"
    when "sm" then "max-w-sm"
    when "lg" then "max-w-lg"
    else ""
    end
  end

  def size_input_class
    case @size
    when "xs" then "input-xs"
    when "sm" then "input-sm"
    when "lg" then "input-lg"
    else ""
    end
  end

  def error_classes
    case @type
    when "select"
      "select-error"
    when "textarea"
      "textarea-error"
    when "file"
      "file-input-error"
    else
      "input-error"
    end
  end

  def label_classes
    base = "label cursor-pointer"
    base += " label-required" if @required
    base
  end

  def has_errors?
    @form.object&.errors&.include?(@field)
  end

  def field_errors
    return [] unless has_errors?
    @form.object.errors[@field]
  end

  def stimulus_attributes
    attrs = {}

    if @stimulus_controller
      attrs["data-controller"] = @stimulus_controller
    end

    @stimulus_data.each do |key, value|
      attrs["data-#{@stimulus_controller}-#{key}"] = value
    end

    # Add validation attributes
    if @validation.any?
      attrs["data-controller"] = [ attrs["data-controller"], "form-validation" ].compact.join(" ")
      attrs["data-form-validation-rules-value"] = @validation.to_json
    end

    attrs
  end

  def input_attributes
    attrs = {
      class: input_css_classes,
      placeholder: @placeholder,
      required: @required,
      disabled: @disabled,
      readonly: @readonly
    }.merge(stimulus_attributes)

    # Add HTML5 validation attributes
    case @type
    when "email"
      attrs[:type] = "email"
    when "tel"
      attrs[:type] = "tel"
    when "url"
      attrs[:type] = "url"
    when "number"
      attrs[:type] = "number"
      attrs[:step] = @validation[:step] if @validation[:step]
      attrs[:min] = @validation[:min] if @validation[:min]
      attrs[:max] = @validation[:max] if @validation[:max]
    when "date"
      attrs[:type] = "date"
    when "datetime"
      attrs[:type] = "datetime-local"
    when "time"
      attrs[:type] = "time"
    when "password"
      attrs[:type] = "password"
    when "range"
      attrs[:type] = "range"
      attrs[:min] = @validation[:min] || 0
      attrs[:max] = @validation[:max] || 100
      attrs[:step] = @validation[:step] || 1
    end

    # Add length validations
    if @validation[:minlength]
      attrs[:minlength] = @validation[:minlength]
    end

    if @validation[:maxlength]
      attrs[:maxlength] = @validation[:maxlength]
    end

    # Add pattern validation
    if @validation[:pattern]
      attrs[:pattern] = @validation[:pattern]
    end

    attrs.compact
  end

  def render_input
    case @type
    when "select"
      render_select_field
    when "textarea"
      render_textarea_field
    when "checkbox"
      render_checkbox_field
    when "radio"
      render_radio_field
    when "file"
      render_file_field
    when "range"
      render_range_field
    else
      render_text_field
    end
  end

  def render_text_field
    @form.text_field(@field, input_attributes)
  end

  def render_textarea_field
    attrs = input_attributes
    attrs[:rows] = @validation[:rows] || 4
    @form.text_area(@field, attrs)
  end

  def render_select_field
    if @options
      options_html = options_for_select(@options, @form.object&.send(@field))
      @form.select(@field, options_html,
                  { include_blank: !@required },
                  input_attributes.merge(multiple: @multiple))
    else
      @form.select(@field, [], {}, input_attributes)
    end
  end

  def render_checkbox_field
    content_tag(:label, class: "label cursor-pointer justify-start gap-3") do
      @form.check_box(@field, input_attributes) +
      content_tag(:span, field_label, class: "label-text")
    end
  end

  def render_radio_field
    if @options
      content_tag(:div, class: "flex flex-col gap-2") do
        @options.map do |option|
          value = option.is_a?(Array) ? option[1] : option
          label_text = option.is_a?(Array) ? option[0] : option

          content_tag(:label, class: "label cursor-pointer justify-start gap-3") do
            @form.radio_button(@field, value, class: "radio radio-primary") +
            content_tag(:span, label_text, class: "label-text")
          end
        end.join.html_safe
      end
    end
  end

  def render_file_field
    @form.file_field(@field, input_attributes.merge(multiple: @multiple))
  end

  def render_range_field
    range_min = @validation[:min] || 0
    range_max = @validation[:max] || 100
    current_value = @form.object&.send(@field) || range_min

    content_tag(:div, class: "space-y-2") do
      @form.range_field(@field, input_attributes) +
      content_tag(:div, class: "flex justify-between text-xs text-gray-500") do
        content_tag(:span, range_min) +
        content_tag(:span, "Current: #{current_value}", class: "font-medium") +
        content_tag(:span, range_max)
      end
    end
  end
end
