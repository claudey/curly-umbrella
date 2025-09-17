class Api::V1::FeatureFlagsController < Api::V1::BaseController
  before_action :authenticate_api_user!
  before_action :set_feature_flag, only: [:show, :update, :destroy]
  
  # GET /api/v1/feature_flags
  def index
    @feature_flags = FeatureFlag.includes(:created_by, :updated_by)
                                .order(:name)
                                .page(params[:page])
                                .per(50)
    
    render json: {
      feature_flags: serialize_feature_flags(@feature_flags),
      pagination: pagination_meta(@feature_flags),
      stats: FeatureFlagService.instance.flags_by_status
    }
  end
  
  # GET /api/v1/feature_flags/:id
  def show
    render json: {
      feature_flag: serialize_feature_flag(@feature_flag),
      usage_stats: calculate_usage_stats(@feature_flag)
    }
  end
  
  # POST /api/v1/feature_flags
  def create
    @feature_flag = FeatureFlag.new(feature_flag_params)
    @feature_flag.created_by = current_api_user
    @feature_flag.updated_by = current_api_user
    
    if @feature_flag.save
      FeatureFlagService.instance.clear_cache
      render json: {
        feature_flag: serialize_feature_flag(@feature_flag),
        message: 'Feature flag created successfully'
      }, status: :created
    else
      render json: {
        errors: @feature_flag.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/feature_flags/:id
  def update
    @feature_flag.updated_by = current_api_user
    
    if @feature_flag.update(feature_flag_params)
      FeatureFlagService.instance.clear_cache
      render json: {
        feature_flag: serialize_feature_flag(@feature_flag),
        message: 'Feature flag updated successfully'
      }
    else
      render json: {
        errors: @feature_flag.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/feature_flags/:id
  def destroy
    key = @feature_flag.key
    @feature_flag.destroy
    FeatureFlagService.instance.clear_cache
    
    render json: {
      message: "Feature flag '#{key}' deleted successfully"
    }
  end
  
  # POST /api/v1/feature_flags/:id/toggle
  def toggle
    @feature_flag = FeatureFlag.find(params[:id])
    @feature_flag.toggle!
    @feature_flag.update!(updated_by: current_api_user)
    FeatureFlagService.instance.clear_cache
    
    status = @feature_flag.enabled? ? 'enabled' : 'disabled'
    
    render json: {
      feature_flag: serialize_feature_flag(@feature_flag),
      message: "Feature flag is now #{status}"
    }
  end
  
  # GET /api/v1/feature_flags/check
  # Check multiple feature flags for a user
  def check
    keys = params[:keys] || []
    user_id = params[:user_id]
    context = params[:context] || {}
    
    return render json: { error: 'Keys parameter is required' }, status: :bad_request if keys.empty?
    
    user = user_id ? User.find_by(id: user_id) : nil
    
    results = {}
    keys.each do |key|
      results[key] = FeatureFlagService.instance.enabled?(key, user, context)
    end
    
    render json: {
      results: results,
      user_id: user&.id,
      context: context,
      checked_at: Time.current
    }
  end
  
  # GET /api/v1/feature_flags/health
  def health
    health_data = FeatureFlagService.instance.health_check
    
    render json: {
      health: health_data,
      status: health_data[:system_healthy] ? 'healthy' : 'unhealthy',
      timestamp: Time.current
    }
  end
  
  # POST /api/v1/feature_flags/bulk_update
  def bulk_update
    updates = params[:updates] || []
    
    return render json: { error: 'Updates parameter is required' }, status: :bad_request if updates.empty?
    
    results = []
    errors = []
    
    updates.each do |update|
      begin
        flag = FeatureFlag.find_by!(key: update[:key])
        flag.update!(update.except(:key).merge(updated_by: current_api_user))
        results << { key: flag.key, status: 'updated' }
      rescue ActiveRecord::RecordNotFound
        errors << { key: update[:key], error: 'Feature flag not found' }
      rescue => e
        errors << { key: update[:key], error: e.message }
      end
    end
    
    FeatureFlagService.instance.clear_cache if results.any?
    
    render json: {
      results: results,
      errors: errors,
      summary: {
        total: updates.length,
        updated: results.length,
        failed: errors.length
      }
    }
  end
  
  # GET /api/v1/feature_flags/export
  def export
    flags_data = FeatureFlagService.instance.export_flags
    
    render json: {
      flags: flags_data,
      exported_at: Time.current,
      total_count: flags_data.length
    }
  end
  
  # POST /api/v1/feature_flags/import
  def import
    flags_data = params[:flags] || []
    
    return render json: { error: 'Flags parameter is required' }, status: :bad_request if flags_data.empty?
    
    begin
      FeatureFlagService.instance.import_flags(flags_data)
      
      render json: {
        message: "Successfully imported #{flags_data.length} feature flags",
        imported_count: flags_data.length
      }
    rescue => e
      render json: {
        error: "Import failed: #{e.message}"
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_feature_flag
    @feature_flag = FeatureFlag.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Feature flag not found' }, status: :not_found
  end
  
  def feature_flag_params
    params.require(:feature_flag).permit(
      :key, :name, :description, :enabled, :percentage,
      :metadata, user_groups: [], conditions: {}
    )
  end
  
  def serialize_feature_flag(flag)
    {
      id: flag.id,
      key: flag.key,
      name: flag.name,
      description: flag.description,
      enabled: flag.enabled,
      percentage: flag.percentage,
      user_groups: flag.user_groups,
      conditions: flag.conditions,
      metadata: flag.metadata,
      created_by: flag.created_by&.email,
      updated_by: flag.updated_by&.email,
      created_at: flag.created_at,
      updated_at: flag.updated_at
    }
  end
  
  def serialize_feature_flags(flags)
    flags.map { |flag| serialize_feature_flag(flag) }
  end
  
  def calculate_usage_stats(feature_flag)
    total_users = User.count
    eligible_users = 0
    
    if feature_flag.enabled?
      eligible_users = total_users
      
      # Filter by user groups if specified
      if feature_flag.user_groups.present?
        eligible_users = User.joins(:groups)
                            .where(groups: { name: feature_flag.user_groups })
                            .distinct
                            .count
      end
      
      # Apply percentage if specified
      if feature_flag.percentage.present?
        eligible_users = (eligible_users * feature_flag.percentage / 100.0).round
      end
    end
    
    {
      total_users: total_users,
      eligible_users: eligible_users,
      rollout_percentage: feature_flag.enabled_percentage
    }
  end
  
  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end