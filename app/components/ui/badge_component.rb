class Ui::BadgeComponent < ViewComponent::Base
  include Ui::DesignSystem

  VARIANTS = %w[default primary success warning error info].freeze
  SIZES = %w[sm md lg].freeze

  def initialize(
    variant: "default",
    size: "md",
    icon: nil,
    removable: false,
    href: nil,
    class: nil,
    **options
  )
    @variant = variant.to_s
    @size = size.to_s
    @icon = icon
    @removable = removable
    @href = href
    @additional_classes = binding.local_variable_get(:class)
    @options = options

    validate_variant!
    validate_size!
  end

  private

  attr_reader :variant, :size, :icon, :removable, :href, :additional_classes, :options

  def tag_name
    href ? :a : :span
  end

  def tag_options
    base_options = {
      class: badge_classes,
      **options
    }

    base_options[:href] = href if href

    base_options
  end

  def badge_classes
    base_classes = Ui::DesignSystem.badge_classes(
      variant: variant.to_sym,
      size: size.to_sym
    )

    additional_classes_array = []
    additional_classes_array << "cursor-pointer hover:opacity-80" if href
    additional_classes_array << additional_classes if additional_classes

    [base_classes, *additional_classes_array].compact.join(" ")
  end

  def icon_size
    case size
    when "sm" then Ui::DesignSystem::ICON_SIZES[:xs]
    when "md" then Ui::DesignSystem::ICON_SIZES[:sm]
    when "lg" then Ui::DesignSystem::ICON_SIZES[:md]
    else Ui::DesignSystem::ICON_SIZES[:sm]
    end
  end

  def show_icon?
    icon.present?
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