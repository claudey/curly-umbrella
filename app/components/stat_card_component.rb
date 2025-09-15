class StatCardComponent < ApplicationComponent
  option :title, Types::String
  option :value, Types::Any
  option :description, Types::String.optional, default: proc { nil }
  option :icon, Types::String.optional, default: proc { nil }
  option :color, Types::String, default: proc { 'primary' }
  option :size, Types::String, default: proc { 'normal' }
  option :trend, Types::Hash.optional, default: proc { nil }
  option :link_to, Types::String.optional, default: proc { nil }
  option :classes, Types::String, default: proc { '' }

  private

  def card_classes
    base_classes = "stat bg-base-100 shadow-sm rounded-lg"
    base_classes += " #{size_classes}"
    base_classes += " #{@classes}" if @classes.present?
    base_classes
  end

  def size_classes
    case @size
    when 'compact'
      'stat-compact'
    when 'large'
      'p-6'
    else
      ''
    end
  end

  def figure_classes
    "stat-figure text-#{@color}"
  end

  def value_classes
    base = "stat-value text-#{@color}"
    base += case @size
            when 'compact'
              ' text-lg'
            when 'large'
              ' text-4xl'
            else
              ' text-2xl'
            end
    base
  end

  def trend_color
    return '' unless @trend

    case @trend[:direction]
    when 'up'
      @trend[:positive] ? 'text-success' : 'text-error'
    when 'down'
      @trend[:positive] ? 'text-error' : 'text-success'
    else
      'text-gray-500'
    end
  end

  def trend_icon
    return '' unless @trend

    case @trend[:direction]
    when 'up'
      'arrow-trending-up'
    when 'down'
      'arrow-trending-down'
    else
      'minus'
    end
  end

  def formatted_value
    case @value
    when Numeric
      if @value >= 1_000_000
        "#{(@value / 1_000_000.0).round(1)}M"
      elsif @value >= 1_000
        "#{(@value / 1_000.0).round(1)}K"
      else
        number_with_delimiter(@value)
      end
    when String
      @value
    else
      @value.to_s
    end
  end
end