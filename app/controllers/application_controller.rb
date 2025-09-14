class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Set up acts_as_tenant for multi-tenancy
  set_current_tenant_through_filter
  before_action :set_current_tenant

  private

  def set_current_tenant
    # For now, we'll set tenant based on subdomain or a parameter
    # This will be enhanced when we add authentication
    if params[:organization_id].present?
      ActsAsTenant.current_tenant = Organization.find(params[:organization_id])
    elsif request.subdomain.present? && request.subdomain != 'www'
      ActsAsTenant.current_tenant = Organization.find_by(name: request.subdomain.humanize)
    end
  end
end
