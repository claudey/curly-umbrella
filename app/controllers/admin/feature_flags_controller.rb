class Admin::FeatureFlagsController < Admin::BaseController
  before_action :set_feature_flag, only: [:show, :edit, :update, :destroy, :toggle]
  before_action :require_admin_permissions
  
  def index
    @feature_flags = FeatureFlag.includes(:created_by, :updated_by)
                                .order(:name)
                                .page(params[:page])
                                .per(20)
    
    @flags_stats = FeatureFlagService.instance.flags_by_status
    @health_check = FeatureFlagService.instance.health_check
    
    respond_to do |format|
      format.html
      format.json { render json: @feature_flags }
    end
  end
  
  def show
    @usage_stats = calculate_usage_stats(@feature_flag)
    
    respond_to do |format|
      format.html
      format.json { render json: @feature_flag }
    end
  end
  
  def new
    @feature_flag = FeatureFlag.new
  end
  
  def create
    @feature_flag = FeatureFlag.new(feature_flag_params)
    @feature_flag.created_by = current_user
    @feature_flag.updated_by = current_user
    
    if @feature_flag.save
      FeatureFlagService.instance.clear_cache
      redirect_to admin_feature_flag_path(@feature_flag), 
                  notice: 'Feature flag was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    @feature_flag.updated_by = current_user
    
    if @feature_flag.update(feature_flag_params)
      FeatureFlagService.instance.clear_cache
      redirect_to admin_feature_flag_path(@feature_flag),
                  notice: 'Feature flag was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    key = @feature_flag.key
    @feature_flag.destroy
    FeatureFlagService.instance.clear_cache
    
    redirect_to admin_feature_flags_path,
                notice: "Feature flag '#{key}' was successfully deleted."
  end
  
  def toggle
    @feature_flag.toggle!
    @feature_flag.update!(updated_by: current_user)
    FeatureFlagService.instance.clear_cache
    
    status = @feature_flag.enabled? ? 'enabled' : 'disabled'
    
    respond_to do |format|
      format.html do
        redirect_to admin_feature_flags_path,
                    notice: "Feature flag '#{@feature_flag.key}' is now #{status}."
      end
      format.json do
        render json: { 
          success: true, 
          enabled: @feature_flag.enabled?,
          message: "Feature flag is now #{status}"
        }
      end
    end
  end
  
  def bulk_toggle
    flag_ids = params[:flag_ids]
    action = params[:bulk_action]
    
    return head :bad_request unless flag_ids.present? && action.in?(['enable', 'disable'])
    
    flags = FeatureFlag.where(id: flag_ids)
    enabled_value = action == 'enable'
    
    flags.update_all(
      enabled: enabled_value,
      updated_at: Time.current
    )
    
    FeatureFlagService.instance.clear_cache
    
    respond_to do |format|
      format.html do
        redirect_to admin_feature_flags_path,
                    notice: "#{flags.count} feature flags were #{action}d."
      end
      format.json do
        render json: {
          success: true,
          count: flags.count,
          action: action
        }
      end
    end
  end
  
  def export
    flags_data = FeatureFlagService.instance.export_flags
    
    respond_to do |format|
      format.json do
        render json: {
          flags: flags_data,
          exported_at: Time.current,
          total_count: flags_data.length
        }
      end
      format.csv do
        send_data generate_csv(flags_data),
                  filename: "feature_flags_#{Date.current}.csv",
                  type: 'text/csv'
      end
    end
  end
  
  def import
    return head :bad_request unless params[:file].present?
    
    begin
      file_content = params[:file].read
      flags_data = JSON.parse(file_content, symbolize_names: true)
      
      if flags_data.is_a?(Hash) && flags_data[:flags]
        flags_data = flags_data[:flags]
      end
      
      FeatureFlagService.instance.import_flags(flags_data)
      
      redirect_to admin_feature_flags_path,
                  notice: "Successfully imported #{flags_data.length} feature flags."
    rescue JSON::ParserError
      redirect_to admin_feature_flags_path,
                  alert: 'Invalid JSON file format.'
    rescue => e
      redirect_to admin_feature_flags_path,
                  alert: "Import failed: #{e.message}"
    end
  end
  
  def health
    health_data = FeatureFlagService.instance.health_check
    
    respond_to do |format|
      format.json { render json: health_data }
    end
  end
  
  def clear_cache
    FeatureFlagService.instance.clear_cache
    
    respond_to do |format|
      format.html do
        redirect_to admin_feature_flags_path,
                    notice: 'Feature flag cache cleared successfully.'
      end
      format.json do
        render json: { success: true, message: 'Cache cleared' }
      end
    end
  end
  
  private
  
  def set_feature_flag
    @feature_flag = FeatureFlag.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_feature_flags_path,
                alert: 'Feature flag not found.'
  end
  
  def feature_flag_params
    params.require(:feature_flag).permit(
      :key, :name, :description, :enabled, :percentage,
      :metadata, user_groups: [], conditions: {}
    )
  end
  
  def require_admin_permissions
    unless current_user.admin?
      redirect_to root_path, alert: 'Access denied. Admin privileges required.'
    end
  end
  
  def calculate_usage_stats(feature_flag)
    {
      total_users: User.count,
      eligible_users: calculate_eligible_users(feature_flag),
      rollout_percentage: feature_flag.enabled_percentage
    }
  end
  
  def calculate_eligible_users(feature_flag)
    return 0 unless feature_flag.enabled?
    
    eligible_count = User.count
    
    # Filter by user groups if specified
    if feature_flag.user_groups.present?
      eligible_count = User.joins(:groups)
                          .where(groups: { name: feature_flag.user_groups })
                          .distinct
                          .count
    end
    
    # Apply percentage if specified
    if feature_flag.percentage.present?
      eligible_count = (eligible_count * feature_flag.percentage / 100.0).round
    end
    
    eligible_count
  end
  
  def generate_csv(flags_data)
    CSV.generate(headers: true) do |csv|
      csv << ['Key', 'Name', 'Description', 'Enabled', 'Percentage', 'User Groups', 'Conditions']
      
      flags_data.each do |flag|
        csv << [
          flag[:key],
          flag[:name],
          flag[:description],
          flag[:enabled],
          flag[:percentage],
          flag[:user_groups]&.join(', '),
          flag[:conditions]&.to_json
        ]
      end
    end
  end
end