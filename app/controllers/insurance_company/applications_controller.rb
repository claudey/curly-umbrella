class InsuranceCompany::ApplicationsController < ApplicationController
  include AuthorizationController
  
  before_action :ensure_insurance_company_user
  before_action :set_insurance_company
  before_action :set_application_distribution, only: [:show, :mark_viewed, :ignore]
  
  def index
    @filter_params = filter_params
    @distributions = load_applications
    @summary_stats = calculate_summary_stats
  end

  def show
    @application = @distribution.insurance_application
    @client = @application.client
    @existing_quote = @insurance_company.quotes.find_by(insurance_application: @application)
    
    # Mark as viewed if not already
    @distribution.mark_as_viewed! if @distribution.pending?
    
    # Track view analytics
    track_application_view
  end

  def mark_viewed
    @distribution.mark_as_viewed!
    redirect_back(fallback_location: insurance_company_applications_path)
  end

  def ignore
    reason = params[:reason] || 'Not interested'
    @distribution.mark_as_ignored!(reason)
    
    redirect_to insurance_company_applications_path, 
                notice: 'Application marked as ignored'
  end

  private

  def ensure_insurance_company_user
    unless current_user.insurance_company_id.present?
      redirect_to root_path, alert: 'Access denied. Insurance company access required.'
    end
  end

  def set_insurance_company
    @insurance_company = current_user.insurance_company
  end

  def set_application_distribution
    @distribution = @insurance_company.application_distributions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to insurance_company_applications_path, alert: 'Application not found'
  end

  def filter_params
    params.permit(:status, :insurance_type, :match_score, :sort, :search)
  end

  def load_applications
    distributions = @insurance_company.application_distributions
                                    .includes(insurance_application: [:client, :user])
    
    # Apply filters
    distributions = apply_status_filter(distributions)
    distributions = apply_insurance_type_filter(distributions)
    distributions = apply_match_score_filter(distributions)
    distributions = apply_search_filter(distributions)
    distributions = apply_sorting(distributions)
    
    # Paginate if needed (using kaminari or similar)
    distributions.limit(50)
  end

  def apply_status_filter(distributions)
    return distributions unless @filter_params[:status].present?
    
    case @filter_params[:status]
    when 'pending'
      distributions.pending
    when 'viewed'
      distributions.viewed
    when 'quoted'
      distributions.quoted
    when 'ignored'
      distributions.ignored
    when 'active'
      distributions.active
    else
      distributions
    end
  end

  def apply_insurance_type_filter(distributions)
    return distributions unless @filter_params[:insurance_type].present?
    
    distributions.joins(:insurance_application)
                .where(insurance_applications: { insurance_type: @filter_params[:insurance_type] })
  end

  def apply_match_score_filter(distributions)
    return distributions unless @filter_params[:match_score].present?
    
    case @filter_params[:match_score]
    when 'high'
      distributions.where('match_score >= ?', 70)
    when 'medium'
      distributions.where('match_score >= ? AND match_score < ?', 40, 70)
    when 'low'
      distributions.where('match_score < ?', 40)
    else
      distributions
    end
  end

  def apply_search_filter(distributions)
    return distributions unless @filter_params[:search].present?
    
    search_term = "%#{@filter_params[:search]}%"
    distributions.joins(insurance_application: :client)
                .where(
                  'clients.first_name ILIKE ? OR clients.last_name ILIKE ? OR insurance_applications.application_number ILIKE ?',
                  search_term, search_term, search_term
                )
  end

  def apply_sorting(distributions)
    case @filter_params[:sort]
    when 'match_score_desc'
      distributions.order(match_score: :desc)
    when 'match_score_asc'
      distributions.order(match_score: :asc)
    when 'created_desc'
      distributions.order(created_at: :desc)
    when 'created_asc'
      distributions.order(created_at: :asc)
    when 'type'
      distributions.joins(:insurance_application).order('insurance_applications.insurance_type')
    else
      distributions.order(created_at: :desc)
    end
  end

  def calculate_summary_stats
    all_distributions = @insurance_company.application_distributions
    
    {
      total: all_distributions.count,
      pending: all_distributions.pending.count,
      viewed: all_distributions.viewed.count,
      quoted: all_distributions.quoted.count,
      ignored: all_distributions.ignored.count,
      high_match: all_distributions.where('match_score >= ?', 70).count,
      medium_match: all_distributions.where('match_score >= ? AND match_score < ?', 40, 70).count,
      low_match: all_distributions.where('match_score < ?', 40).count
    }
  end

  def track_application_view
    # Create analytics entry for application view
    DistributionAnalytics.create!(
      insurance_application: @application,
      insurance_company: @insurance_company,
      event_type: 'application_viewed',
      event_data: {
        distribution_id: @distribution.id,
        user_id: current_user.id,
        view_duration: nil, # Could be tracked with JS
        device_type: request.user_agent
      },
      occurred_at: Time.current
    )
  end
end
