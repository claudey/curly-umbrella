class Ui::AdvancedCardComponent < ApplicationComponent
  renders_one :header
  renders_one :body
  renders_one :footer
  renders_many :actions

  VARIANTS = %w[default compact image-top bordered glass].freeze
  SIZES = %w[xs sm md lg xl].freeze

  def initialize(
    variant: "default",
    size: "md",
    title: nil,
    subtitle: nil,
    image: nil,
    badge: nil,
    draggable: false,
    collapsible: false,
    expanded: true,
    hover: false,
    shadow: true,
    class: nil,
    **options
  )
    @variant = variant.to_s
    @size = size.to_s
    @title = title
    @subtitle = subtitle
    @image = image
    @badge = badge
    @draggable = draggable
    @collapsible = collapsible
    @expanded = expanded
    @hover = hover
    @shadow = shadow
    @additional_classes = binding.local_variable_get(:class)
    @options = options

    validate_variant!
    validate_size!
  end

  private

  attr_reader :variant, :size, :title, :subtitle, :image, :badge, :draggable, 
              :collapsible, :expanded, :hover, :shadow, :additional_classes, :options

  def card_classes
    classes = ["card"]
    
    # DaisyUI size variants
    case size
    when "xs" then classes << "card-compact"
    when "sm" then classes << "card-compact"
    when "lg", "xl" then classes << "card-normal"
    else
      classes << "card-normal"
    end

    # DaisyUI variant classes
    case variant
    when "compact"
      classes << "card-compact"
    when "image-top"
      classes << "image-full" if image.present?
    when "bordered"
      classes << "card-bordered"
    when "glass"
      classes << "glass"
    end

    # DaisyUI utility classes
    classes << "shadow-xl" if shadow && variant != "glass"
    classes << "hover:shadow-2xl" if hover
    classes << "bg-base-100" unless variant == "glass"
    
    # Custom enhancement classes
    classes << "transition-all duration-300" if hover || collapsible
    classes << "cursor-move" if draggable
    classes << "collapse" if collapsible
    classes << "collapse-open" if collapsible && expanded
    classes << "collapse-close" if collapsible && !expanded
    
    classes << additional_classes if additional_classes

    classes.compact.join(" ")
  end

  def card_attributes
    attrs = { class: card_classes }
    attrs.merge!(**options)
    attrs[:draggable] = true if draggable
    attrs[:"data-controller"] = "collapsible-card" if collapsible
    attrs[:"data-collapsible-card-expanded-value"] = expanded if collapsible
    attrs
  end

  def body_classes
    classes = ["card-body"]
    
    case size
    when "xs" then classes << "p-4"
    when "sm" then classes << "p-5"
    when "lg" then classes << "p-8"
    when "xl" then classes << "p-10"
    end

    classes.join(" ")
  end

  def show_image?
    image.present?
  end

  def show_header?
    title.present? || subtitle.present? || badge.present? || header?
  end

  def show_actions?
    actions?
  end

  def show_footer?
    footer? || show_actions?
  end

  def validate_variant!
    return if VARIANTS.include?(variant)
    raise ArgumentError, "Invalid variant: #{variant}. Must be one of #{VARIANTS.join(', ')}"
  end

  def validate_size!
    return if SIZES.include?(size)
    raise ArgumentError, "Invalid size: #{size}. Must be one of #{SIZES.join(', ')}"
  end
end