module AuthorizationHelper
  # UI authorization helpers for views

  def show_if_authorized(action, resource = nil, context = {}, &block)
    if can?(action, resource, context)
      capture(&block) if block_given?
    end
  end

  def hide_if_unauthorized(action, resource = nil, context = {}, &block)
    unless can?(action, resource, context)
      capture(&block) if block_given?
    end
  end

  def authorized_link_to(name, path, action, resource = nil, html_options = {}, context = {})
    if can?(action, resource, context)
      link_to(name, path, html_options)
    else
      content_tag(:span, name, class: "text-gray-400 cursor-not-allowed #{html_options[:class]}")
    end
  end

  def authorized_button_to(name, path, action, resource = nil, html_options = {}, context = {})
    if can?(action, resource, context)
      button_to(name, path, html_options)
    else
      button_to(name, "#", html_options.merge(disabled: true, class: "#{html_options[:class]} opacity-50 cursor-not-allowed"))
    end
  end

  # Role-based UI helpers
  def show_for_roles(*role_names, &block)
    if has_any_role?(*role_names)
      capture(&block) if block_given?
    end
  end

  def hide_for_roles(*role_names, &block)
    unless has_any_role?(*role_names)
      capture(&block) if block_given?
    end
  end

  def show_for_admins(&block)
    show_for_roles("super_admin", "admin", &block)
  end

  def show_for_super_admin(&block)
    show_for_roles("super_admin", &block)
  end

  def show_for_minimum_level(level, &block)
    if has_role_level?(level)
      capture(&block) if block_given?
    end
  end

  # Permission-based UI helpers
  def show_with_permission(permission_name, &block)
    if has_permission?(permission_name)
      capture(&block) if block_given?
    end
  end

  def show_with_any_permission(*permission_names, &block)
    if has_any_permission?(*permission_names)
      capture(&block) if block_given?
    end
  end

  def authorized_form_field(form, field_name, action, resource = nil, field_options = {}, context = {})
    if can?(action, resource, context)
      case field_options[:type]
      when :text_field
        form.text_field(field_name, field_options.except(:type))
      when :text_area
        form.text_area(field_name, field_options.except(:type))
      when :select
        form.select(field_name, field_options[:options], field_options.except(:type, :options))
      when :check_box
        form.check_box(field_name, field_options.except(:type))
      else
        form.text_field(field_name, field_options.except(:type))
      end
    else
      # Show read-only version
      value = resource.try(field_name) || form.object.try(field_name)
      content_tag(:div, value, class: "form-control bg-gray-100 text-gray-600")
    end
  end

  # Feature flag helpers
  def show_feature(feature_name, context = {}, &block)
    if feature_enabled?(feature_name, context)
      capture(&block) if block_given?
    end
  end

  def feature_link_to(name, path, feature_name, html_options = {}, context = {})
    if feature_enabled?(feature_name, context)
      link_to(name, path, html_options)
    else
      content_tag(:span, name, class: "text-gray-400 cursor-not-allowed #{html_options[:class]}")
    end
  end

  # Navigation helpers
  def nav_item_if_authorized(name, path, action, resource = nil, html_options = {}, context = {})
    if can?(action, resource, context)
      active_class = current_page?(path) ? "active" : ""
      css_classes = "#{html_options[:class]} #{active_class}".strip

      content_tag(:li, class: css_classes) do
        link_to(name, path, html_options.except(:class))
      end
    end
  end

  def sidebar_section_if_authorized(title, permissions = [], &block)
    if permissions.empty? || has_any_permission?(*permissions)
      content_tag(:div, class: "sidebar-section") do
        concat(content_tag(:h3, title, class: "sidebar-section-title"))
        concat(capture(&block)) if block_given?
      end
    end
  end

  # Table action helpers
  def table_actions_for(resource, actions = {})
    authorized_actions = actions.select do |action_name, action_config|
      can?(action_config[:permission] || action_name, resource, action_config[:context] || {})
    end

    return if authorized_actions.empty?

    content_tag(:div, class: "flex space-x-2") do
      authorized_actions.each do |action_name, action_config|
        concat(
          link_to(
            action_config[:label] || action_name.to_s.humanize,
            action_config[:path],
            class: "btn btn-sm #{action_config[:class] || 'btn-outline'}",
            method: action_config[:method],
            data: action_config[:data] || {}
          )
        )
      end
    end
  end

  # Status badge helpers with authorization
  def status_badge_with_actions(resource, status_field = :status)
    current_status = resource.public_send(status_field)

    content_tag(:div, class: "flex items-center space-x-2") do
      concat(content_tag(:span, current_status.humanize, class: "badge badge-#{status_color(current_status)}"))

      # Show status change buttons if authorized
      if can?(:update, resource)
        available_transitions = status_transitions_for(resource, status_field)
        available_transitions.each do |transition|
          concat(
            button_to(
              transition[:label],
              transition[:path],
              method: :patch,
              class: "btn btn-xs #{transition[:class]}",
              data: { confirm: transition[:confirm] }
            )
          )
        end
      end
    end
  end

  # Dynamic menu generation based on permissions
  def authorized_menu_items(menu_config)
    authorized_items = menu_config.select do |item|
      item[:permissions].nil? || has_any_permission?(*item[:permissions])
    end

    content_tag(:ul, class: "menu") do
      authorized_items.each do |item|
        concat(
          content_tag(:li) do
            if item[:submenu]
              # Handle submenu
              content_tag(:details) do
                concat(content_tag(:summary, item[:title]))
                concat(authorized_menu_items(item[:submenu]))
              end
            else
              link_to(item[:title], item[:path], class: item[:class])
            end
          end
        )
      end
    end
  end

  # Form section helpers
  def form_section_if_authorized(title, permission, resource = nil, &block)
    if has_permission?(permission) && (resource.nil? || can?(:update, resource))
      content_tag(:div, class: "form-section") do
        concat(content_tag(:h4, title, class: "form-section-title"))
        concat(capture(&block)) if block_given?
      end
    end
  end

  # Data export helpers
  def export_buttons_if_authorized(resource_type, format_options = [])
    return unless has_permission?("exports.create")

    content_tag(:div, class: "export-buttons flex space-x-2") do
      format_options.each do |format|
        if can?(:export, resource_type, format: format)
          concat(
            link_to(
              "Export #{format.upcase}",
              export_path(resource_type, format: format),
              class: "btn btn-outline btn-sm",
              data: {
                turbo_method: :post,
                confirm: "Export #{resource_type.to_s.humanize} data as #{format.upcase}?"
              }
            )
          )
        end
      end
    end
  end

  # Bulk action helpers
  def bulk_actions_if_authorized(resource_type, selected_ids = [])
    return if selected_ids.empty?

    authorized_actions = []
    authorized_actions << { name: "Delete", action: :destroy, class: "btn-error" } if can?(:destroy, resource_type)
    authorized_actions << { name: "Archive", action: :archive, class: "btn-warning" } if can?(:archive, resource_type)
    authorized_actions << { name: "Export", action: :export, class: "btn-info" } if can?(:export, resource_type)

    return if authorized_actions.empty?

    content_tag(:div, class: "bulk-actions") do
      form_with url: bulk_action_path(resource_type), method: :patch, local: true do |form|
        concat(form.hidden_field :selected_ids, value: selected_ids.join(","))

        authorized_actions.each do |action|
          concat(
            form.submit(
              action[:name],
              name: "bulk_action",
              value: action[:action],
              class: "btn btn-sm #{action[:class]}",
              data: { confirm: "Are you sure you want to #{action[:name].downcase} #{selected_ids.size} items?" }
            )
          )
        end
      end
    end
  end

  private

  def status_color(status)
    case status.to_s.downcase
    when "active", "approved", "completed" then "success"
    when "pending", "draft", "in_review" then "warning"
    when "rejected", "cancelled", "expired" then "error"
    else "info"
    end
  end

  def status_transitions_for(resource, status_field)
    # This would be customized per resource type
    case resource.class.name
    when "Application"
      application_status_transitions(resource)
    when "Quote"
      quote_status_transitions(resource)
    else
      []
    end
  end

  def application_status_transitions(application)
    transitions = []
    case application.status
    when "draft"
      transitions << { label: "Submit", path: submit_application_path(application), class: "btn-primary", confirm: "Submit application?" }
    when "submitted"
      transitions << { label: "Approve", path: approve_application_path(application), class: "btn-success", confirm: "Approve application?" } if can?(:approve, application)
      transitions << { label: "Reject", path: reject_application_path(application), class: "btn-error", confirm: "Reject application?" } if can?(:reject, application)
    end
    transitions
  end

  def quote_status_transitions(quote)
    transitions = []
    case quote.status
    when "draft"
      transitions << { label: "Send", path: send_quote_path(quote), class: "btn-primary", confirm: "Send quote to client?" }
    when "sent"
      transitions << { label: "Accept", path: accept_quote_path(quote), class: "btn-success", confirm: "Accept quote?" } if can?(:accept, quote)
      transitions << { label: "Decline", path: decline_quote_path(quote), class: "btn-error", confirm: "Decline quote?" } if can?(:decline, quote)
    end
    transitions
  end
end
