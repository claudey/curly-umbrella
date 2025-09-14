class Ui::CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :body
  renders_one :footer
  renders_many :actions

  def initialize(
    title: nil,
    subtitle: nil,
    image: nil,
    compact: false,
    bordered: false,
    shadow: true,
    glass: false,
    **options
  )
    @title = title
    @subtitle = subtitle
    @image = image
    @compact = compact
    @bordered = bordered
    @shadow = shadow
    @glass = glass
    @options = options
  end

  private

  attr_reader :title, :subtitle, :image, :compact, :bordered, :shadow, :glass, :options

  def card_classes
    classes = ["card"]
    classes << "card-compact" if compact
    classes << "card-bordered" if bordered
    classes << "shadow-xl" if shadow
    classes << "glass" if glass
    classes << options[:class] if options[:class]

    classes.join(" ")
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
end