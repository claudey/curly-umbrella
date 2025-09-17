class Ui::ResponsiveFormComponent < ViewComponent::Base
  include Ui::DesignSystem

  renders_many :form_sections, "Ui::ResponsiveFormComponent::FormSectionComponent"
  renders_many :form_fields, "Ui::ResponsiveFormComponent::FormFieldComponent"
  renders_one :form_actions

  def initialize(
    layout: "single_column",
    mobile_stack: true,
    sticky_actions: false,
    compact_mobile: true,
    class: nil,
    **options
  )
    @layout = layout.to_s
    @mobile_stack = mobile_stack
    @sticky_actions = sticky_actions
    @compact_mobile = compact_mobile
    @additional_classes = binding.local_variable_get(:class)
    @options = options
  end

  private

  attr_reader :layout, :mobile_stack, :sticky_actions, :compact_mobile, :additional_classes, :options

  def form_classes
    base_classes = ["space-y-6"]
    
    case layout
    when "two_column"
      base_classes = ["grid", "grid-cols-1", "gap-6"]
      base_classes << "lg:grid-cols-2" unless mobile_stack
    when "three_column"
      base_classes = ["grid", "grid-cols-1", "gap-6"]
      base_classes << "md:grid-cols-2 lg:grid-cols-3" unless mobile_stack
    when "sidebar"
      base_classes = ["grid", "grid-cols-1", "gap-6", "lg:grid-cols-3"]
    end

    base_classes << "space-y-4" if compact_mobile
    base_classes << additional_classes if additional_classes
    base_classes.join(" ")
  end

  def actions_classes
    base_classes = ["flex", "justify-end", "space-x-3", "pt-6", "border-t", "border-neutral-200"]
    base_classes << "sticky bottom-0 bg-white z-10 pb-4" if sticky_actions
    base_classes << "flex-col space-y-3 space-x-0 sm:flex-row sm:space-y-0 sm:space-x-3" if mobile_stack
    base_classes.join(" ")
  end

  class FormSectionComponent < ViewComponent::Base
    renders_many :fields, "Ui::ResponsiveFormComponent::FormFieldComponent"

    def initialize(
      title: nil,
      description: nil,
      collapsible: false,
      span: nil,
      class: nil,
      **options
    )
      @title = title
      @description = description
      @collapsible = collapsible
      @span = span
      @additional_classes = binding.local_variable_get(:class)
      @options = options
    end

    private

    attr_reader :title, :description, :collapsible, :span, :additional_classes, :options

    def section_classes
      classes = ["space-y-4"]
      classes << "lg:col-span-#{span}" if span
      classes << additional_classes if additional_classes
      classes.join(" ")
    end

    def header_classes
      "pb-4 border-b border-neutral-200"
    end

    def title_classes
      "text-lg font-medium text-neutral-900"
    end

    def description_classes
      "mt-1 text-sm text-neutral-500"
    end

    def show_header?
      title.present? || description.present?
    end
  end

  class FormFieldComponent < ViewComponent::Base
    def initialize(
      type: "input",
      label: nil,
      name: nil,
      required: false,
      span: nil,
      mobile_full_width: true,
      **field_options
    )
      @type = type.to_s
      @label = label
      @name = name
      @required = required
      @span = span
      @mobile_full_width = mobile_full_width
      @field_options = field_options
    end

    private

    attr_reader :type, :label, :name, :required, :span, :mobile_full_width, :field_options

    def field_wrapper_classes
      classes = []
      classes << "lg:col-span-#{span}" if span
      classes << "w-full" if mobile_full_width
      classes.join(" ")
    end

    def render_field
      case type
      when "input"
        render Ui::InputComponent.new(
          name: name,
          label: label,
          required: required,
          **field_options
        )
      when "textarea"
        render_textarea
      when "select"
        render_select
      when "checkbox"
        render_checkbox
      when "radio_group"
        render_radio_group
      when "file"
        render_file_input
      else
        content
      end
    end

    def render_textarea
      label_tag = label_tag(name, label, class: label_classes) if label.present?
      textarea_tag = text_area_tag(name, nil, {
        class: textarea_classes,
        required: required,
        **field_options
      })
      
      content_tag :div do
        concat label_tag if label_tag
        concat textarea_tag
      end
    end

    def render_select
      label_tag = label_tag(name, label, class: label_classes) if label.present?
      select_tag = select_tag(name, options_for_select(field_options[:options] || []), {
        class: select_classes,
        required: required,
        **field_options.except(:options)
      })
      
      content_tag :div do
        concat label_tag if label_tag
        concat select_tag
      end
    end

    def render_checkbox
      content_tag :div, class: "flex items-center" do
        concat check_box_tag(name, "1", field_options[:checked], {
          class: checkbox_classes,
          required: required,
          **field_options.except(:checked)
        })
        concat label_tag(name, label, class: "ml-2 text-sm text-neutral-700") if label.present?
      end
    end

    def render_radio_group
      content_tag :fieldset do
        if label.present?
          concat content_tag(:legend, label, class: "text-sm font-medium text-neutral-900 mb-2")
        end
        
        content_tag :div, class: "space-y-2" do
          (field_options[:options] || []).each do |option|
            concat content_tag(:div, class: "flex items-center") do
              concat radio_button_tag(name, option[:value], option[:checked], {
                class: radio_classes,
                id: "#{name}_#{option[:value]}"
              })
              concat label_tag("#{name}_#{option[:value]}", option[:label], class: "ml-2 text-sm text-neutral-700")
            end
          end
        end
      end
    end

    def render_file_input
      label_tag = label_tag(name, label, class: label_classes) if label.present?
      file_tag = file_field_tag(name, {
        class: file_input_classes,
        required: required,
        **field_options
      })
      
      content_tag :div do
        concat label_tag if label_tag
        concat file_tag
      end
    end

    def label_classes
      classes = ["block text-sm font-medium text-neutral-700 mb-1"]
      classes << "after:content-['*'] after:ml-1 after:text-error-500" if required
      classes.join(" ")
    end

    def textarea_classes
      [
        "block w-full rounded-lg border border-neutral-300",
        "focus:border-primary-500 focus:ring-2 focus:ring-primary-200",
        "transition-colors duration-200",
        "px-3 py-2 text-sm"
      ].join(" ")
    end

    def select_classes
      [
        "block w-full rounded-lg border border-neutral-300",
        "focus:border-primary-500 focus:ring-2 focus:ring-primary-200",
        "transition-colors duration-200",
        "px-3 py-2 text-sm"
      ].join(" ")
    end

    def checkbox_classes
      [
        "h-4 w-4 text-primary-600 border-neutral-300 rounded",
        "focus:ring-primary-500 focus:ring-2"
      ].join(" ")
    end

    def radio_classes
      [
        "h-4 w-4 text-primary-600 border-neutral-300",
        "focus:ring-primary-500 focus:ring-2"
      ].join(" ")
    end

    def file_input_classes
      [
        "block w-full text-sm text-neutral-500",
        "file:mr-4 file:py-2 file:px-4",
        "file:rounded-lg file:border-0",
        "file:text-sm file:font-medium",
        "file:bg-primary-50 file:text-primary-700",
        "hover:file:bg-primary-100"
      ].join(" ")
    end
  end
end