class Ui::ModalComponent < ViewComponent::Base
  include Ui::DesignSystem

  renders_one :header
  renders_one :body
  renders_one :footer

  SIZES = %w[sm md lg xl full].freeze

  def initialize(
    id:,
    title: nil,
    size: "md",
    closable: true,
    backdrop_closable: true,
    open: false,
    class: nil,
    **options
  )
    @id = id
    @title = title
    @size = size.to_s
    @closable = closable
    @backdrop_closable = backdrop_closable
    @open = open
    @additional_classes = binding.local_variable_get(:class)
    @options = options

    validate_size!
  end

  private

  attr_reader :id, :title, :size, :closable, :backdrop_closable, :open, :additional_classes, :options

  def modal_classes
    base_classes = [
      "fixed", "inset-0", "z-50", "flex", "items-center", "justify-center",
      "p-4", "transition-opacity", "duration-300"
    ]

    base_classes << (open ? "opacity-100" : "opacity-0 pointer-events-none")
    base_classes.join(" ")
  end

  def backdrop_classes
    "fixed inset-0 bg-black bg-opacity-50 transition-opacity duration-300"
  end

  def dialog_classes
    base_classes = [
      "relative", "bg-white", "rounded-xl", "shadow-2xl",
      "transform", "transition-all", "duration-300", "max-h-full", "overflow-hidden"
    ]

    # Size classes
    size_classes = case size
    when "sm" then [ "w-full", "max-w-sm" ]
    when "md" then [ "w-full", "max-w-md" ]
    when "lg" then [ "w-full", "max-w-lg" ]
    when "xl" then [ "w-full", "max-w-2xl" ]
    when "full" then [ "w-full", "h-full", "max-w-none", "rounded-none" ]
    else [ "w-full", "max-w-md" ]
    end

    base_classes.concat(size_classes)
    base_classes << (open ? "scale-100" : "scale-95")
    base_classes << additional_classes if additional_classes

    base_classes.join(" ")
  end

  def header_classes
    "flex items-center justify-between p-6 border-b border-neutral-200"
  end

  def body_classes
    "p-6 overflow-y-auto flex-1"
  end

  def footer_classes
    "flex items-center justify-end space-x-3 p-6 border-t border-neutral-200 bg-neutral-50"
  end

  def close_button_classes
    [
      "text-neutral-400", "hover:text-neutral-600", "focus:outline-none",
      "focus:text-neutral-600", "transition-colors", "duration-200"
    ].join(" ")
  end

  def backdrop_attributes
    attrs = { class: backdrop_classes }
    attrs[:onclick] = "document.getElementById('#{id}').style.display = 'none'" if backdrop_closable
    attrs
  end

  def show_header?
    title.present? || header? || closable
  end

  def show_footer?
    footer?
  end

  def validate_size!
    return if SIZES.include?(size)

    raise ArgumentError, "Invalid size: #{size}. Must be one of #{SIZES.join(', ')}"
  end
end
