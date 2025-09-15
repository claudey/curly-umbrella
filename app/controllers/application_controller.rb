class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Set up acts_as_tenant for multi-tenancy
  set_current_tenant_through_filter
  before_action :set_current_tenant
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone, :role])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone, :phone_number, :sms_enabled, :whatsapp_number, :whatsapp_enabled])
  end

  private

  def set_current_tenant
    return if skip_tenant_for_admin?
    
    if user_signed_in? && current_user.organization.present?
      ActsAsTenant.current_tenant = current_user.organization
    elsif params[:organization_id].present?
      ActsAsTenant.current_tenant = Organization.find(params[:organization_id])
    elsif request.subdomain.present? && request.subdomain != 'www' && request.subdomain != 'admin'
      ActsAsTenant.current_tenant = Organization.find_by(subdomain: request.subdomain)
    end
  end

  def skip_tenant_for_admin?
    # Skip tenant setting for super admin and admin controllers
    (user_signed_in? && current_user.super_admin?) || 
    controller_path.start_with?('admin/') ||
    controller_name == 'home'
  end
end
