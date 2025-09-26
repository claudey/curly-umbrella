module UiComponentHelper
  # Advanced DaisyUI Components
  def advanced_card(**options, &block)
    render Ui::AdvancedCardComponent.new(**options), &block
  end

  def advanced_button(**options, &block)
    render Ui::AdvancedButtonComponent.new(**options), &block
  end

  def advanced_input(**options)
    render Ui::AdvancedInputComponent.new(**options)
  end

  def draggable_widget(**options, &block)
    render Ui::DraggableWidgetComponent.new(**options), &block
  end

  # Customer Portal Components
  def customer_portal_layout(**options, &block)
    render Ui::CustomerPortalLayoutComponent.new(**options), &block
  end

  def customer_policy_card(policy, **options)
    render Ui::CustomerPolicyCardComponent.new(policy: policy, **options)
  end

  # Form helpers that use advanced components
  def ui_text_field(form, field, **options)
    error = form.object.errors[field].first
    
    advanced_input(
      name: form.object_name + "[#{field}]",
      value: form.object.public_send(field),
      label: options[:label] || field.to_s.humanize,
      error: error,
      required: options[:required],
      placeholder: options[:placeholder],
      **options.except(:label, :required)
    )
  end

  def ui_email_field(form, field, **options)
    ui_text_field(form, field, type: "email", icon_left: :envelope, **options)
  end

  def ui_password_field(form, field, **options)
    ui_text_field(form, field, type: "password", icon_left: :lock_closed, **options)
  end

  def ui_search_field(form, field, **options)
    ui_text_field(form, field, type: "search", icon_left: :magnifying_glass, **options)
  end

  def ui_phone_field(form, field, **options)
    ui_text_field(form, field, type: "tel", icon_left: :phone, **options)
  end

  def ui_url_field(form, field, **options)
    ui_text_field(form, field, type: "url", icon_left: :link, **options)
  end

  # Button helpers
  def ui_primary_button(text, **options, &block)
    content = block_given? ? capture(&block) : text
    advanced_button(variant: "primary", **options) { content }
  end

  def ui_secondary_button(text, **options, &block)
    content = block_given? ? capture(&block) : text
    advanced_button(variant: "secondary", **options) { content }
  end

  def ui_outline_button(text, **options, &block)
    content = block_given? ? capture(&block) : text
    advanced_button(variant: "outline", **options) { content }
  end

  def ui_ghost_button(text, **options, &block)
    content = block_given? ? capture(&block) : text
    advanced_button(variant: "ghost", **options) { content }
  end

  # Card helpers
  def ui_stat_card(title:, value:, **options, &block)
    advanced_card(variant: "default", **options) do |card|
      card.with_body do
        content_tag :div, class: "stat" do
          stat_content = content_tag(:div, value, class: "stat-value text-primary")
          stat_content += content_tag(:div, title, class: "stat-title")
          if block_given?
            stat_content += content_tag(:div, capture(&block), class: "stat-desc")
          end
          stat_content
        end
      end
    end
  end

  def ui_metric_card(title:, value:, change: nil, change_type: nil, icon: nil, **options)
    advanced_card(variant: "default", **options) do |card|
      card.with_body do
        content_tag :div, class: "text-center" do
          metric_content = ""
          
          if icon
            metric_content += content_tag(:div, class: "mb-3") do
              content_tag(:div, class: "w-12 h-12 bg-primary/10 rounded-full mx-auto flex items-center justify-center") do
                phosphor_icon(icon, size: 24, class: "text-primary")
              end
            end
          end
          
          metric_content += content_tag(:div, value, class: "text-3xl font-bold text-base-content")
          metric_content += content_tag(:div, title, class: "text-sm text-base-content/70 mt-1")
          
          if change
            change_classes = case change_type&.to_sym
                           when :positive then "text-success"
                           when :negative then "text-error"
                           else "text-base-content/60"
                           end
            
            change_icon = case change_type&.to_sym
                         when :positive then :arrow_up
                         when :negative then :arrow_down
                         else :minus
                         end
            
            metric_content += content_tag(:div, class: "flex items-center justify-center mt-2 text-sm font-medium #{change_classes}") do
              phosphor_icon(change_icon, size: 16, class: "mr-1") + change.to_s
            end
          end
          
          metric_content.html_safe
        end
      end
    end
  end

  # Widget grid helpers
  def ui_dashboard_grid(**options, &block)
    content_tag :div,
                class: "grid gap-4 auto-rows-min",
                data: {
                  controller: "dashboard-grid",
                  "dashboard-grid-columns-value": options[:columns] || 3,
                  "dashboard-grid-gap-value": options[:gap] || 16,
                  "dashboard-grid-auto-save-value": options[:auto_save] != false,
                  "dashboard-grid-save-url-value": options[:save_url]
                },
                **options.except(:columns, :gap, :auto_save, :save_url),
                &block
  end

  def ui_widget_dropzone(**options)
    content_tag :div,
                class: "border-2 border-dashed border-base-300 rounded-lg p-8 text-center text-base-content/50 transition-colors hover:border-primary hover:bg-primary/5",
                data: { "dashboard-grid-target": "dropzone" },
                **options do
      content_tag(:div, class: "space-y-2") do
        phosphor_icon(:plus, size: 32, class: "mx-auto text-base-content/30") +
        content_tag(:div, "Drop widgets here", class: "text-sm font-medium") +
        content_tag(:div, "or click to add new widget", class: "text-xs")
      end
    end
  end

  # Quick component builders
  def ui_loading_card(**options)
    advanced_card(**options) do |card|
      card.with_body do
        content_tag :div, class: "flex items-center justify-center py-8" do
          content_tag(:span, class: "loading loading-spinner loading-lg text-primary") + 
          content_tag(:span, "Loading...", class: "ml-3 text-base-content/70")
        end
      end
    end
  end

  def ui_empty_state(title:, description: nil, icon: :folder_open, action: nil, **options)
    advanced_card(variant: "bordered", **options) do |card|
      card.with_body do
        content_tag :div, class: "text-center py-8" do
          empty_content = content_tag(:div, class: "space-y-4") do
            icon_content = content_tag(:div, class: "w-16 h-16 bg-base-200 rounded-full mx-auto flex items-center justify-center") do
              phosphor_icon(icon, size: 32, class: "text-base-content/40")
            end
            
            text_content = content_tag(:div) do
              title_content = content_tag(:h3, title, class: "text-lg font-semibold text-base-content")
              desc_content = description ? content_tag(:p, description, class: "text-sm text-base-content/70 mt-1") : ""
              title_content + desc_content
            end
            
            action_content = action ? content_tag(:div, action, class: "mt-4") : ""
            
            icon_content + text_content + action_content
          end
          
          empty_content
        end
      end
    end
  end
end