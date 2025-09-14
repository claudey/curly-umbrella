module IconHelper
  def phosphor_icon(name, variant: :regular, size: 20, css_class: nil, **options)
    # Convert string names to symbols for consistency
    name = name.to_sym if name.is_a?(String)
    variant = variant.to_sym if variant.is_a?(String)
    
    # Default CSS classes
    classes = ["w-#{size_to_class(size)}", "h-#{size_to_class(size)}"]
    classes << css_class if css_class.present?
    
    # Set default attributes
    svg_options = {
      class: classes.join(" "),
      fill: "currentColor",
      viewBox: "0 0 256 256"
    }.merge(options)
    
    # Generate the icon using the phosphor_icons gem
    phosphor_icon_tag(name, variant: variant, **svg_options)
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