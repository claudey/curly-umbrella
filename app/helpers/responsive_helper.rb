module ResponsiveHelper

  # Responsive utility classes for common patterns
  def responsive_classes(options = {})
    classes = []
    
    # Padding
    if options[:padding]
      case options[:padding]
      when :responsive
        classes << "p-4 md:p-6 lg:p-8"
      when :section
        classes << "py-8 md:py-12 lg:py-16"
      else
        classes << "p-#{options[:padding]}"
      end
    end

    # Margins
    if options[:margin]
      case options[:margin]
      when :responsive
        classes << "m-4 md:m-6 lg:m-8"
      when :section
        classes << "my-8 md:my-12 lg:my-16"
      else
        classes << "m-#{options[:margin]}"
      end
    end

    # Text sizes
    if options[:text_size]
      case options[:text_size]
      when :responsive_heading
        classes << "text-xl md:text-2xl lg:text-3xl xl:text-4xl"
      when :responsive_body
        classes << "text-sm md:text-base lg:text-lg"
      else
        classes << "text-#{options[:text_size]}"
      end
    end

    # Grid columns
    if options[:grid_cols]
      cols = options[:grid_cols]
      case cols
      when 1
        classes << "grid-cols-1"
      when 2
        classes << "grid-cols-1 md:grid-cols-2"
      when 3
        classes << "grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
      when 4
        classes << "grid-cols-1 md:grid-cols-2 lg:grid-cols-4"
      when 6
        classes << "grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6"
      else
        classes << "grid-cols-#{cols}"
      end
    end

    # Flex direction
    if options[:flex_direction]
      case options[:flex_direction]
      when :responsive_column
        classes << "flex-col lg:flex-row"
      when :responsive_row
        classes << "flex-row lg:flex-col"
      end
    end

    classes.join(" ")
  end

  # Container classes for different content types
  def container_classes(type = :default, size: :default)
    base_classes = ["mx-auto", "px-4", "sm:px-6"]
    
    case size
    when :xs
      base_classes << "max-w-xs"
    when :sm
      base_classes << "max-w-sm"
    when :md
      base_classes << "max-w-md"
    when :lg
      base_classes << "max-w-lg lg:px-8"
    when :xl
      base_classes << "max-w-xl lg:px-8"
    when :full_width
      base_classes = ["w-full", "px-4", "sm:px-6", "lg:px-8"]
    when :wide
      base_classes << "max-w-7xl lg:px-8"
    else
      case type
      when :article
        base_classes << "max-w-3xl lg:px-8"
      when :dashboard
        base_classes << "max-w-7xl lg:px-8"
      when :form
        base_classes << "max-w-lg lg:px-8"
      else
        base_classes << "max-w-6xl lg:px-8"
      end
    end

    base_classes.join(" ")
  end

  # Responsive spacing between elements
  def responsive_spacing(size = :default)
    case size
    when :xs
      "space-y-2 md:space-y-3"
    when :sm
      "space-y-4 md:space-y-6"
    when :lg
      "space-y-8 md:space-y-12"
    when :xl
      "space-y-12 md:space-y-16"
    else
      "space-y-6 md:space-y-8"
    end
  end

  # Responsive typography classes
  def responsive_typography(type)
    case type
    when :display
      "text-3xl md:text-4xl lg:text-5xl xl:text-6xl font-bold"
    when :heading_1
      "text-2xl md:text-3xl lg:text-4xl font-bold"
    when :heading_2
      "text-xl md:text-2xl lg:text-3xl font-semibold"
    when :heading_3
      "text-lg md:text-xl lg:text-2xl font-semibold"
    when :heading_4
      "text-base md:text-lg lg:text-xl font-medium"
    when :body_large
      "text-base md:text-lg"
    when :body
      "text-sm md:text-base"
    when :body_small
      "text-xs md:text-sm"
    when :caption
      "text-xs"
    else
      "text-sm md:text-base"
    end
  end

  # Check current breakpoint (for use in views)
  def current_breakpoint_classes(breakpoint)
    case breakpoint.to_sym
    when :sm
      "block sm:hidden"
    when :md
      "hidden sm:block md:hidden"
    when :lg
      "hidden md:block lg:hidden"
    when :xl
      "hidden lg:block xl:hidden"
    when :xxl
      "hidden xl:block"
    else
      ""
    end
  end

  # Hide/show at specific breakpoints
  def breakpoint_visibility(show_at: [], hide_at: [])
    classes = []
    
    # Default to hidden
    classes << "hidden" if show_at.any?
    
    show_at.each do |breakpoint|
      case breakpoint.to_sym
      when :sm
        classes << "sm:block"
      when :md
        classes << "md:block"
      when :lg
        classes << "lg:block"
      when :xl
        classes << "xl:block"
      when :mobile
        classes << "sm:hidden"
      end
    end

    hide_at.each do |breakpoint|
      case breakpoint.to_sym
      when :sm
        classes << "sm:hidden"
      when :md
        classes << "md:hidden"
      when :lg
        classes << "lg:hidden"
      when :xl
        classes << "xl:hidden"
      when :desktop
        classes << "sm:hidden"
      end
    end

    classes.join(" ")
  end

  # Responsive image classes
  def responsive_image_classes(aspect_ratio: :auto, object_fit: :cover)
    classes = ["w-full"]
    
    case aspect_ratio
    when :square
      classes << "aspect-square"
    when :video
      classes << "aspect-video"
    when :photo
      classes << "aspect-[4/3]"
    when :portrait
      classes << "aspect-[3/4]"
    end

    case object_fit
    when :cover
      classes << "object-cover"
    when :contain
      classes << "object-contain"
    when :fill
      classes << "object-fill"
    end

    classes.join(" ")
  end

  # Mobile-first responsive button sizing
  def responsive_button_size(size = :md)
    case size
    when :sm
      "px-3 py-1.5 text-sm md:px-4 md:py-2"
    when :lg
      "px-6 py-3 text-base md:px-8 md:py-4 md:text-lg"
    when :xl
      "px-8 py-4 text-lg md:px-10 md:py-5 md:text-xl"
    else
      "px-4 py-2 text-sm md:px-6 md:py-3 md:text-base"
    end
  end
end