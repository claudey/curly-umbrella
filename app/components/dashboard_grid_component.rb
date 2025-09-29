class DashboardGridComponent < ApplicationComponent
  def initialize(columns: 4, gap: "4", min_height: "200px", responsive: true, sortable: false, customizable: false, grid_id: "dashboard-grid")
    @columns = columns
    @gap = gap
    @min_height = min_height
    @responsive = responsive
    @sortable = sortable
    @customizable = customizable
    @grid_id = grid_id
  end

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
    styles = [ "min-height: #{@min_height}" ]
    styles.join("; ")
  end

  def stimulus_controllers
    controllers = [ "dashboard-grid" ]
    controllers << "sortable" if @sortable
    controllers.join(" ")
  end

  def stimulus_data
    data = {
      "dashboard-grid-columns-value" => @columns,
      "dashboard-grid-sortable-value" => @sortable,
      "dashboard-grid-customizable-value" => @customizable
    }

    if @sortable
      data["sortable-options-value"] = {
        animation: 150,
        ghostClass: "sortable-ghost",
        chosenClass: "sortable-chosen",
        dragClass: "sortable-drag"
      }.to_json
    end

    data
  end
end
