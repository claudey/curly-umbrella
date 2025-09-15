class DashboardGridComponent < ApplicationComponent
  option :columns, Types::Integer, default: proc { 4 }
  option :gap, Types::String, default: proc { '4' } # Tailwind gap class number
  option :min_height, Types::String, default: proc { '200px' }
  option :responsive, Types::Bool, default: proc { true }
  option :sortable, Types::Bool, default: proc { false }
  option :customizable, Types::Bool, default: proc { false }
  option :grid_id, Types::String, default: proc { 'dashboard-grid' }

  private

  def grid_classes
    base = "dashboard-grid grid auto-rows-min"
    base += " gap-#{@gap}"
    
    if @responsive
      base += " grid-cols-1 md:grid-cols-2 lg:grid-cols-#{@columns}"
    else
      base += " grid-cols-#{@columns}"
    end
    
    base += " sortable-grid" if @sortable
    base
  end

  def grid_styles
    styles = ["min-height: #{@min_height}"]
    styles.join('; ')
  end

  def stimulus_controllers
    controllers = ['dashboard-grid']
    controllers << 'sortable' if @sortable
    controllers.join(' ')
  end

  def stimulus_data
    data = {
      'dashboard-grid-columns-value' => @columns,
      'dashboard-grid-sortable-value' => @sortable,
      'dashboard-grid-customizable-value' => @customizable
    }

    if @sortable
      data['sortable-options-value'] = {
        animation: 150,
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'sortable-drag'
      }.to_json
    end

    data
  end
end