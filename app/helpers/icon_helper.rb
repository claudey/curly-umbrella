module IconHelper
  # Generic icon helper that wraps phosphor_icon for backward compatibility
  def icon(name, **options)
    # Extract class from options and convert to css_class
    css_class = options.delete(:class)

    # Map common icon names to phosphor icon names
    icon_mapping = {
      # Basic icons
      "bell" => :bell,
      "bell-slash" => :bell_slash,
      "check" => :check,
      "check-circle" => :check_circle,
      "user" => :user,
      "settings" => :gear,
      "cog-6-tooth" => :gear_six,
      "home" => :house,
      "dashboard" => :squares_four,
      "logout" => :sign_out,
      "login" => :sign_in,
      "search" => :magnifying_glass,
      "magnifying-glass" => :magnifying_glass,
      "plus" => :plus,
      "squares-plus" => :squares_plus,
      "minus" => :minus,
      "edit" => :pencil,
      "delete" => :trash,
      "save" => :floppy_disk,
      "close" => :x,
      "x-mark" => :x,
      "menu" => :list,
      "bars-3" => :list,
      "eye" => :eye,
      "printer" => :printer,
      "clock" => :clock,
      "calendar" => :calendar,

      # Arrows
      "arrow-right" => :arrow_right,
      "arrow-left" => :arrow_left,
      "arrow-up" => :arrow_up,
      "arrow-down" => :arrow_down,
      "arrow-path" => :arrow_clockwise,
      "arrow-down-tray" => :arrow_down_tray,
      "arrow-up-tray" => :arrow_up_tray,
      "chevron-up" => :chevron_up,
      "chevron-down" => :chevron_down,
      "chevron-up-down" => :chevron_up_down,

      # Chart and data icons
      "chart-bar" => :chart_bar,
      "chart-line" => :chart_line,
      "view-columns" => :columns,

      # Document icons
      "clipboard-document-list" => :clipboard_text,
      "clipboard-document" => :clipboard_text,
      "document-text" => :file_text,
      "file-text" => :file_text,
      "paper-airplane" => :paper_plane,
      "inbox" => :inbox,

      # UI icons
      "ellipsis-vertical" => :dots_three_vertical,
      "hand-thumb-up" => :thumbs_up,
      "exclamation-triangle" => :warning_triangle,
      "information-circle" => :info,
      "question-mark-circle" => :question,
      "shield-check" => :shield_check,
      "truck" => :truck,
      "building-office" => :buildings,
      "banknotes" => :bank,
      "archive-box-x-mark" => :archive_box_x,
      "x-circle" => :x_circle,
      "sparkles" => :sparkle,
      "device-phone-mobile" => :device_mobile,
      "list-bullet" => :list_bullets,
      "arrows-pointing-out" => :arrows_out,
      "folder" => :folder,
      "buildings" => :buildings,
      "users" => :users,
      "calculator" => :calculator,

      # Additional mapped icons (avoiding duplicates)
      "pencil" => :pencil,
      "trash" => :trash,
      "floppy-disk" => :floppy_disk,
      "x" => :x,
      "list" => :list,
      "gear" => :gear,
      "house" => :house,
      "squares_four" => :squares_four,
      "sign_out" => :sign_out,
      "sign_in" => :sign_in,
      "magnifying-glass" => :magnifying_glass,
      "paper_plane" => :paper_plane,
      "clipboard_text" => :clipboard_text,
      "file_text" => :file_text,
      "chart_bar" => :chart_bar,
      "chart_line" => :chart_line,
      "columns" => :columns,
      "dots_three_vertical" => :dots_three_vertical,
      "thumbs_up" => :thumbs_up,
      "warning" => :warning,
      "info" => :info,
      "question" => :question,
      "shield_check" => :shield_check,
      "bank" => :bank,
      "archive_box_x" => :archive_box_x,
      "x_circle" => :x_circle,
      "sparkle" => :sparkle,
      "device_mobile" => :device_mobile,
      "list_bullets" => :list_bullets,
      "arrows_out" => :arrows_out
    }

    # Use mapped name or convert string to symbol
    phosphor_name = icon_mapping[name] || name.to_sym

    # Convert Tailwind size classes to numeric sizes
    size = 20 # default
    if css_class
      size_match = css_class.match(/w-(\d+)/)
      size = size_match[1].to_i if size_match
    end

    phosphor_icon(phosphor_name, css_class: css_class, size: size, **options)
  end

  def phosphor_icon(name, variant: :regular, size: 20, css_class: nil, **options)
    # Convert symbol names to strings for the gem
    name = name.to_s if name.is_a?(Symbol)
    variant = variant.to_s if variant.is_a?(Symbol)

    # Default CSS classes
    classes = [ "w-#{size_to_class(size)}", "h-#{size_to_class(size)}" ]
    classes << css_class if css_class.present?

    # Set default attributes
    svg_options = {
      class: classes.join(" ")
    }.merge(options)

    # Generate the icon using the phosphor_icons gem
    super(name, style: variant, **svg_options)
  rescue StandardError
    # Fallback to a default icon if the requested icon doesn't exist
    content_tag(:div, "?", class: "w-#{size_to_class(size)} h-#{size_to_class(size)} flex items-center justify-center bg-gray-200 rounded text-xs")
  end

  def menu_icon(name, variant: :regular, size: 5)
    phosphor_icon(name, variant: variant, size: size, css_class: "text-current")
  end

  def button_icon(name, variant: :regular, size: 4)
    phosphor_icon(name, variant: variant, size: size, css_class: "text-current")
  end

  def nav_icon(name, variant: :regular, size: 5)
    phosphor_icon(name, variant: variant, size: size, css_class: "text-current mr-3")
  end

  private

  def size_to_class(size)
    case size
    when 0..4 then size
    when 5..6 then size
    when 8 then 8
    when 10 then 10
    when 12 then 12
    when 16 then 16
    when 20 then 20
    when 24 then 24
    else 5 # default to w-5 h-5
    end
  end
end
