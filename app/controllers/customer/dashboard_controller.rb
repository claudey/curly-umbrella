class Customer::DashboardController < Customer::BaseController
  def index
    @active_nav = "dashboard"
    @policies_count = customer_policies.count
    @active_policies_count = customer_policies.where(status: 'approved').count
    @pending_applications_count = customer_policies.where(status: 'submitted').count
    @documents_count = customer_documents.count
    
    # Recent activities
    @recent_policies = customer_policies.order(created_at: :desc).limit(5)
    @expiring_policies = customer_policies
                        .where(status: 'approved')
                        .where('expiration_date <= ?', 30.days.from_now)
                        .order(:expiration_date)
                        .limit(3)
  end
end