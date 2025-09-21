class Ui::CardComponent < ViewComponent::Base
  include Ui::DesignSystem

  renders_one :header
  renders_one :body
  renders_one :footer
  renders_many :actions

  VARIANTS = %w[default elevated outlined filled].freeze

  def initialize(
    variant: "default",
    title: nil,
    subtitle: nil,
    image: nil,
    padding: true,
    hover_effect: false,
    clickable: false,
    href: nil,
    class: nil,
    **options
  )
    @variant = variant.to_s
    @title = title
    @subtitle = subtitle
    @image = image
    @padding = padding
    @hover_effect = hover_effect
    @clickable = clickable
    @href = href
    @additional_classes = binding.local_variable_get(:class)
    @options = options

    validate_variant!
  end

  private

  attr_reader :variant, :title, :subtitle, :image, :padding, :hover_effect, :clickable, :href, :additional_classes, :options

  def tag_name
    href || clickable ? :a : :div
  end

  def tag_options
    base_options = {
      class: card_classes,
      **options
    }

    if href
      base_options[:href] = href
    elsif clickable
      base_options[:role] = "button"
      base_options[:tabindex] = "0"
    end

    base_options
  end

  def card_classes
    base_classes = Ui::DesignSystem.card_classes(variant: variant.to_sym)

    additional_classes_array = []
    additional_classes_array << padding_classes if padding
    additional_classes_array << hover_classes if hover_effect || clickable
    additional_classes_array << "cursor-pointer" if clickable || href
    additional_classes_array << additional_classes if additional_classes

    [ base_classes, *additional_classes_array ].compact.join(" ")
  end

  def padding_classes
    case variant
    when "elevated", "filled" then "p-6"
    else "p-4"
    end
  end

  def hover_classes
    "transition-all duration-200 hover:shadow-md hover:-translate-y-0.5"
  end

  def show_image?
    image.present?
  end

  def show_header?
    title.present? || subtitle.present? || header?
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
end
