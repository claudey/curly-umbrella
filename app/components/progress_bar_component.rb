class ProgressBarComponent < ApplicationComponent
  option :current_step, Types::Integer
  option :total_steps, Types::Integer
  option :steps, Types::Array.optional, default: proc { [] }
  option :color, Types::String, default: proc { "primary" }
  option :size, Types::String, default: proc { "normal" }
  option :show_labels, Types::Bool, default: proc { true }
  option :show_percentage, Types::Bool, default: proc { false }
  option :animated, Types::Bool, default: proc { true }

  private

  def progress_percentage
    return 0 if @total_steps == 0
    ((@current_step.to_f / @total_steps) * 100).round(1)
  end

  def progress_classes
    base = "progress"
    base += " progress-#{@color}"
    base += case @size
    when "xs" then " progress-xs"
    when "sm" then " progress-sm"
    when "lg" then " progress-lg"
    else ""
    end
    base += " transition-all duration-500 ease-out" if @animated
    base
  end

  def step_classes(index)
    step_number = index + 1
    base = "flex items-center justify-center w-8 h-8 rounded-full text-sm font-medium"

    if step_number <= @current_step
      base += " bg-#{@color} text-#{@color}-content"
    elsif step_number == @current_step + 1
      base += " bg-#{@color}/20 text-#{@color} border-2 border-#{@color}"
    else
      base += " bg-base-300 text-base-content/60"
    end

    base
  end

  def connector_classes(index)
    step_number = index + 1
    base = "flex-1 h-1 mx-2"

    if step_number <= @current_step
      base += " bg-#{@color}"
    else
      base += " bg-base-300"
    end

    base
  end

  def step_icon(index)
    step_number = index + 1

    if step_number < @current_step
      "check"
    elsif step_number == @current_step
      "clock"
    else
      step_number.to_s
    end
  end

  def step_label(index)
    if @steps.present? && @steps[index]
      @steps[index]
    else
      "Step #{index + 1}"
    end
  end

  def step_description(index)
    step_number = index + 1

    if step_number < @current_step
      "Completed"
    elsif step_number == @current_step
      "In Progress"
    else
      "Pending"
    end
  end
end
