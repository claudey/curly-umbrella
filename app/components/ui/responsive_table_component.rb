class Ui::ResponsiveTableComponent < ViewComponent::Base
  include Ui::DesignSystem

  renders_many :columns, "Ui::ResponsiveTableComponent::ColumnComponent"
  renders_many :rows, "Ui::ResponsiveTableComponent::RowComponent"

  def initialize(
    variant: "default",
    striped: false,
    hover: true,
    compact: false,
    mobile_cards: true,
    sticky_header: false,
    sortable: false,
    class: nil,
    **options
  )
    @variant = variant.to_s
    @striped = striped
    @hover = hover
    @compact = compact
    @mobile_cards = mobile_cards
    @sticky_header = sticky_header
    @sortable = sortable
    @additional_classes = binding.local_variable_get(:class)
    @options = options
  end

  private

  attr_reader :variant, :striped, :hover, :compact, :mobile_cards, :sticky_header, :sortable, :additional_classes, :options

  def wrapper_classes
    classes = [ "overflow-hidden" ]
    classes << "shadow ring-1 ring-black ring-opacity-5" if variant == "elevated"
    classes << "border border-neutral-200 rounded-lg" if variant == "bordered"
    classes << additional_classes if additional_classes
    classes.join(" ")
  end

  def table_container_classes
    classes = [ "overflow-x-auto" ]
    classes << "max-h-96" if sticky_header
    classes.join(" ")
  end

  def table_classes
    classes = [ "min-w-full", "divide-y", "divide-neutral-200" ]
    classes << "bg-white" if variant != "transparent"
    classes.join(" ")
  end

  def thead_classes
    classes = [ "bg-neutral-50" ]
    classes << "sticky top-0 z-10" if sticky_header
    classes.join(" ")
  end

  def tbody_classes
    classes = [ "bg-white", "divide-y", "divide-neutral-200" ]
    classes.join(" ")
  end

  def mobile_cards_classes
    "md:hidden space-y-4"
  end

  def desktop_table_classes
    mobile_cards ? "hidden md:block" : ""
  end

  class ColumnComponent < ViewComponent::Base
    def initialize(
      key:,
      sortable: false,
      width: nil,
      align: "left",
      mobile_priority: "normal",
      **options
    )
      @key = key
      @sortable = sortable
      @width = width
      @align = align.to_s
      @mobile_priority = mobile_priority.to_s
      @options = options
    end

    attr_reader :key, :sortable, :width, :align, :mobile_priority, :options

    def header_classes
      classes = [
        "px-6", "py-3", "text-left", "text-xs", "font-medium",
        "text-neutral-500", "uppercase", "tracking-wider"
      ]

      classes[2] = "text-#{align}" if align != "left"
      classes << "cursor-pointer hover:bg-neutral-100" if sortable
      classes << "w-#{width}" if width

      case mobile_priority
      when "high"
        classes << "block"
      when "low"
        classes << "hidden lg:table-cell"
      when "hidden"
        classes << "hidden"
      end

      classes.join(" ")
    end

    def cell_classes
      classes = [ "px-6", "py-4", "whitespace-nowrap", "text-sm" ]
      classes[2] = "text-#{align}" if align != "left"

      case mobile_priority
      when "high"
        classes << "block"
      when "low"
        classes << "hidden lg:table-cell"
      when "hidden"
        classes << "hidden"
      end

      classes.join(" ")
    end
  end

  class RowComponent < ViewComponent::Base
    renders_many :cells, "Ui::ResponsiveTableComponent::CellComponent"

    def initialize(
      clickable: false,
      href: nil,
      variant: "default",
      **options
    )
      @clickable = clickable
      @href = href
      @variant = variant.to_s
      @options = options
    end

    private

    attr_reader :clickable, :href, :variant, :options

    def row_classes
      classes = []

      case variant
      when "success"
        classes << "bg-success-50"
      when "warning"
        classes << "bg-warning-50"
      when "error"
        classes << "bg-error-50"
      else
        classes << "hover:bg-neutral-50" if clickable || href
      end

      classes << "cursor-pointer" if clickable || href
      classes.join(" ")
    end

    def mobile_card_classes
      "bg-white p-4 rounded-lg border border-neutral-200 space-y-2"
    end

    class CellComponent < ViewComponent::Base
      def initialize(
        column_key:,
        primary: false,
        **options
      )
        @column_key = column_key
        @primary = primary
        @options = options
      end

      private

      attr_reader :column_key, :primary, :options

      def cell_classes
        column = parent.parent.columns.find { |col| col.key == column_key }
        return "px-6 py-4 whitespace-nowrap text-sm" unless column

        column.cell_classes
      end

      def mobile_cell_classes
        classes = [ "flex", "justify-between" ]
        classes << "font-medium text-neutral-900" if primary
        classes << "text-neutral-700" unless primary
        classes.join(" ")
      end

      def mobile_label
        column = parent.parent.columns.find { |col| col.key == column_key }
        column&.content || column_key.to_s.humanize
      end
    end
  end
end
