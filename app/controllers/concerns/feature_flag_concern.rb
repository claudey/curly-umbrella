module FeatureFlagConcern
  extend ActiveSupport::Concern
  
  included do
    helper_method :feature_enabled?, :feature_disabled?
  end
  
  private
  
  def feature_enabled?(key, user = current_user, context = {})
    FeatureFlagService.instance.enabled?(key, user, context)
  end
  
  def feature_disabled?(key, user = current_user, context = {})
    !feature_enabled?(key, user, context)
  end
  
  def require_feature(key, user = current_user, context = {})
    unless feature_enabled?(key, user, context)
      respond_to do |format|
        format.html do
          redirect_to root_path, alert: 'This feature is not available.'
        end
        format.json do
          render json: { error: 'Feature not available' }, status: :forbidden
        end
      end
    end
  end
  
  def feature_flag_context(additional_context = {})
    base_context = {
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      controller: controller_name,
      action: action_name
    }
    
    base_context.merge(additional_context)
  end
end