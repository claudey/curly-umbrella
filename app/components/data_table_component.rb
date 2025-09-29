class DataTableComponent < ApplicationComponent
  def initialize(headers:, rows:, sortable: true, searchable: false, paginated: false, striped: true, compact: false, actions: [], empty_message: "No data available", loading: false, id: "data-table")
    @headers = headers
    @rows = rows
    @sortable = sortable
    @searchable = searchable
    @paginated = paginated
    @striped = striped
    @compact = compact
    @actions = actions
    @empty_message = empty_message
    @loading = loading
    @id = id
  end

  private

  def table_classes
    base = "table w-full"
    base += " table-zebra" if @striped
    base += " table-compact" if @compact
    base
  end

  def header_classes(header)
    base = "bg-base-200 font-semibold"
    base += " cursor-pointer hover:bg-base-300" if @sortable && header[:sortable] != false
    base
  end

  def cell_classes(cell_config = {})
    base = ""
    base += " text-right" if cell_config[:align] == "right"
    base += " text-center" if cell_config[:align] == "center"
    base += " font-mono" if cell_config[:type] == "number"
    base
  end

  def render_cell_content(row, column_key, cell_config = {})
    value = row[column_key] || row[column_key.to_s]

    case cell_config[:type]
    when "currency"
      "$#{number_with_delimiter(value)}"
    when "percentage"
      "#{value}%"
    when "date"
      value&.strftime("%b %d, %Y")
    when "datetime"
      value&.strftime("%b %d, %Y %I:%M %p")
    when "status"
      content_tag(:span, value&.humanize, class: status_badge_class(value))
    when "link"
      link_to(value, cell_config[:url] || "#", class: "link link-primary")
    when "boolean"
      value ? "✓" : "✗"
    else
      value.to_s
    end
  end

  def status_badge_class(status)
    case status&.to_s&.downcase
    when "active", "approved", "completed", "success"
      "badge badge-success badge-sm"
    when "pending", "in_progress", "processing"
      "badge badge-warning badge-sm"
    when "inactive", "rejected", "failed", "error"
      "badge badge-error badge-sm"
    else
      "badge badge-neutral badge-sm"
    end
  end

  def action_button_class(action)
    case action[:type]
    when "primary"
      "btn btn-primary btn-xs"
    when "secondary"
      "btn btn-secondary btn-xs"
    when "ghost"
      "btn btn-ghost btn-xs"
    when "danger"
      "btn btn-error btn-xs"
    else
      "btn btn-outline btn-xs"
    end
  end

  def generate_sort_url(column_key, current_sort = {})
    # This would integrate with your controller's sorting logic
    current_direction = current_sort[:column] == column_key ? current_sort[:direction] : nil
    new_direction = current_direction == "asc" ? "desc" : "asc"

    "?sort=#{column_key}&direction=#{new_direction}"
  end

  def sort_icon(column_key, current_sort = {})
    return "" unless @sortable

    if current_sort[:column] == column_key
      case current_sort[:direction]
      when "asc"
        icon("chevron-up", class: "w-4 h-4")
      when "desc"
        icon("chevron-down", class: "w-4 h-4")
      else
        icon("chevron-up-down", class: "w-4 h-4 opacity-50")
      end
    else
      icon("chevron-up-down", class: "w-4 h-4 opacity-50")
    end
  end
end
