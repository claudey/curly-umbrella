class Ui::GridComponent < ViewComponent::Base
  include Ui::DesignSystem

  renders_many :columns, "Ui::GridComponent::ColumnComponent"

  def initialize(
    cols: 12,
    gap: 4,
    responsive: true,
    auto_fit: false,
    min_width: nil,
    class: nil,
    **options
  )
    @cols = cols
    @gap = gap
    @responsive = responsive
    @auto_fit = auto_fit
    @min_width = min_width
    @additional_classes = binding.local_variable_get(:class)
    @options = options
  end

  private

  attr_reader :cols, :gap, :responsive, :auto_fit, :min_width, :additional_classes, :options

  def grid_classes
    base_classes = [ "grid" ]

    if auto_fit && min_width
      base_classes << "grid-cols-[repeat(auto-fit,minmax(#{min_width},1fr))]"
    elsif responsive
      # Mobile-first responsive grid
      case cols
      when 1
        base_classes << "grid-cols-1"
      when 2
        base_classes << "grid-cols-1 sm:grid-cols-2"
      when 3
        base_classes << "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
      when 4
        base_classes << "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4"
      when 6
        base_classes << "grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-6"
      when 12
        base_classes << "grid-cols-1 sm:grid-cols-2 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-12"
      else
        base_classes << "grid-cols-1 md:grid-cols-#{[ cols, 6 ].min} lg:grid-cols-#{cols}"
      end
    else
      base_classes << "grid-cols-#{cols}"
    end

    # Gap classes
    base_classes << "gap-#{gap}"
    base_classes << additional_classes if additional_classes

    base_classes.join(" ")
  end

  class ColumnComponent < ViewComponent::Base
    def initialize(
      span: 1,
      span_sm: nil,
      span_md: nil,
      span_lg: nil,
      span_xl: nil,
      offset: nil,
      offset_sm: nil,
      offset_md: nil,
      offset_lg: nil,
      offset_xl: nil,
      order: nil,
      order_sm: nil,
      order_md: nil,
      order_lg: nil,
      order_xl: nil,
      class: nil,
      **options
    )
      @span = span
      @span_sm = span_sm
      @span_md = span_md
      @span_lg = span_lg
      @span_xl = span_xl
      @offset = offset
      @offset_sm = offset_sm
      @offset_md = offset_md
      @offset_lg = offset_lg
      @offset_xl = offset_xl
      @order = order
      @order_sm = order_sm
      @order_md = order_md
      @order_lg = order_lg
      @order_xl = order_xl
      @additional_classes = binding.local_variable_get(:class)
      @options = options
    end

    private

    attr_reader :span, :span_sm, :span_md, :span_lg, :span_xl,
                :offset, :offset_sm, :offset_md, :offset_lg, :offset_xl,
                :order, :order_sm, :order_md, :order_lg, :order_xl,
                :additional_classes, :options

    def column_classes
      classes = []

      # Span classes
      classes << "col-span-#{span}" if span
      classes << "sm:col-span-#{span_sm}" if span_sm
      classes << "md:col-span-#{span_md}" if span_md
      classes << "lg:col-span-#{span_lg}" if span_lg
      classes << "xl:col-span-#{span_xl}" if span_xl

      # Offset classes
      classes << "col-start-#{offset + 1}" if offset
      classes << "sm:col-start-#{offset_sm + 1}" if offset_sm
      classes << "md:col-start-#{offset_md + 1}" if offset_md
      classes << "lg:col-start-#{offset_lg + 1}" if offset_lg
      classes << "xl:col-start-#{offset_xl + 1}" if offset_xl

      # Order classes
      classes << "order-#{order}" if order
      classes << "sm:order-#{order_sm}" if order_sm
      classes << "md:order-#{order_md}" if order_md
      classes << "lg:order-#{order_lg}" if order_lg
      classes << "xl:order-#{order_xl}" if order_xl

      classes << additional_classes if additional_classes
      classes.join(" ")
    end

    def call
      content_tag :div, content, class: column_classes, **options
    end
  end
end
