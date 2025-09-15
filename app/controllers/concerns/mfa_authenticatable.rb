module MfaAuthenticatable
  extend ActiveSupport::Concern
  
  included do
    before_action :handle_mfa_requirement, if: :user_signed_in?
  end
  
  private
  
  def handle_mfa_requirement
    return unless mfa_required_for_current_user?
    
    if session[:mfa_verified] == current_user.id
      # MFA already verified for this session
      return
    end
    
    if request.path.start_with?('/mfa') || request.path.start_with?('/users/sign_out')
      # Allow access to MFA routes and sign out
      return
    end
    
    # Redirect to MFA verification
    store_location_for(:user, request.fullpath) unless request.xhr?
    redirect_to new_mfa_verification_path
  end
  
  def mfa_required_for_current_user?
    current_user&.mfa_enabled? || current_user&.mfa_setup_required?
  end
  
  def verify_mfa_session!
    session[:mfa_verified] = current_user.id
  end
  
  def clear_mfa_session!
    session.delete(:mfa_verified)
  end
end