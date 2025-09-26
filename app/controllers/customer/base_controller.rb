class Customer::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_customer_access
  
  layout 'customer_portal'
  
  protected
  
  def ensure_customer_access
    # Ensure the user has customer-level access
    # This could be based on user roles, organization type, etc.
    unless current_user.can_access_customer_portal?
      redirect_to root_path, alert: "Access denied. Customer portal access required."
    end
  end
  
  def current_customer
    @current_customer ||= current_user
  end
  helper_method :current_customer
  
  def customer_policies
    @customer_policies ||= current_user.insurance_applications.includes(:client, :organization)
  end
  helper_method :customer_policies
  
  def customer_documents
    @customer_documents ||= current_user.documents.includes(:organization)
  end
  helper_method :customer_documents
end