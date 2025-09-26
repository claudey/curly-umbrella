class Customer::PoliciesController < Customer::BaseController
  def index
    @active_nav = "policies"
    @policies = customer_policies.includes(:client)
    
    # Filter by status if provided
    if params[:status].present?
      @policies = @policies.where(status: params[:status])
    end
    
    # Search functionality
    if params[:search].present?
      @policies = @policies.where(
        "application_number ILIKE ? OR policy_number ILIKE ?", 
        "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end
    
    @policies = @policies.order(created_at: :desc).page(params[:page]).per(10)
    
    # Stats for the filter tabs
    @all_count = customer_policies.count
    @active_count = customer_policies.where(status: 'approved').count
    @pending_count = customer_policies.where(status: 'submitted').count
    @expired_count = customer_policies.where(status: 'expired').count
  end
  
  def show
    @active_nav = "policies"
    @policy = customer_policies.find(params[:id])
  end
  
  def renew
    @policy = customer_policies.find(params[:id])
    
    # Create a renewal application based on the existing policy
    # This would typically create a new application with pre-filled data
    redirect_to new_customer_application_path(renew_from: @policy.id), 
                notice: "Renewal process started for policy #{@policy.policy_number || @policy.application_number}"
  end
end