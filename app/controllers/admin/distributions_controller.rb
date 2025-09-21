class Admin::DistributionsController < ApplicationController
  include AuthorizationController

  before_action :require_admin
  before_action :set_application, only: [ :show, :redistribute, :manual_assign ]
  before_action :set_distribution, only: [ :expire_distribution, :reactivate_distribution ]

  def index
    @filter_params = filter_params
    @applications = load_applications
    @summary_stats = calculate_summary_stats
    @recent_distributions = recent_distributions
  end

  def show
    @distributions = @application.application_distributions
                                .includes(:insurance_company)
                                .order(:created_at)
    @distribution_stats = calculate_distribution_stats
    @eligible_companies = find_eligible_companies_for_manual_assignment
  end

  def redistribute
    if request.post?
      options = {
        distributed_by: current_user,
        method: "manual",
        exclude_companies: params[:exclude_companies]&.compact_blank,
        include_companies: params[:include_companies]&.compact_blank,
        max_companies: params[:max_companies]&.to_i || 5
      }

      result = ApplicationDistributionService.redistribute_application(@application, options)

      if result[:success]
        redirect_to admin_distribution_path(@application),
                    notice: "Application redistributed to #{result[:distributions_created]} companies"
      else
        flash.now[:alert] = "Failed to redistribute: #{result[:error]}"
        render :show
      end
    end
  end

  def manual_assign
    company_ids = params[:company_ids]&.compact_blank

    if company_ids.blank?
      redirect_to admin_distribution_path(@application),
                  alert: "Please select at least one insurance company"
      return
    end

    # Create manual distributions
    companies = InsuranceCompany.where(id: company_ids)
    distributions_created = 0

    companies.each do |company|
      # Skip if already distributed to this company
      next if @application.application_distributions.exists?(insurance_company: company)

      match_score = ApplicationDistribution.calculate_match_score(@application, company)
      criteria = ApplicationDistribution.build_criteria(@application, company)

      ApplicationDistribution.create!(
        insurance_application: @application,
        insurance_company: company,
        distributed_by: current_user,
        distribution_method: "manual",
        match_score: match_score,
        distribution_criteria: criteria
      )

      distributions_created += 1
    end

    redirect_to admin_distribution_path(@application),
                notice: "Manually assigned to #{distributions_created} additional companies"
  end

  def expire_distribution
    @distribution.expire!
    redirect_back(fallback_location: admin_distributions_path,
                  notice: "Distribution expired successfully")
  end

  def reactivate_distribution
    if @distribution.update(status: "pending")
      redirect_back(fallback_location: admin_distributions_path,
                    notice: "Distribution reactivated successfully")
    else
      redirect_back(fallback_location: admin_distributions_path,
                    alert: "Failed to reactivate distribution")
    end
  end

  def bulk_actions
    action = params[:bulk_action]
    selected_ids = params[:selected_ids]&.split(",")&.map(&:to_i) || []

    if selected_ids.empty?
      redirect_to admin_distributions_path, alert: "No applications selected"
      return
    end

    case action
    when "redistribute"
      bulk_redistribute(selected_ids)
    when "expire"
      bulk_expire(selected_ids)
    when "send_reminders"
      bulk_send_reminders(selected_ids)
    else
      redirect_to admin_distributions_path, alert: "Invalid action"
    end
  end

  def auto_distribute_pending
    results = ApplicationDistributionService.auto_distribute_pending_applications

    success_count = results.count { |r| r[:result][:success] }
    total_count = results.count

    if success_count > 0
      redirect_to admin_distributions_path,
                  notice: "Auto-distributed #{success_count} of #{total_count} applications"
    else
      redirect_to admin_distributions_path,
                  alert: "No applications were distributed. #{total_count} applications processed."
    end
  end

  def distribution_analytics
    @date_range = parse_date_range
    @analytics_data = build_analytics_data
  end

  def manage_deadlines
    @approaching_deadlines = ApplicationDistribution.active
                                                   .select(&:deadline_approaching?)
                                                   .includes(:insurance_application, :insurance_company)
    @expired_deadlines = ApplicationDistribution.where(status: "expired")
                                               .where("expired_at >= ?", 7.days.ago)
                                               .includes(:insurance_application, :insurance_company)
    @deadline_stats = calculate_deadline_stats
  end

  def extend_deadline
    distribution = ApplicationDistribution.find(params[:distribution_id])
    days_to_extend = params[:extend_days]&.to_i || 7

    if QuoteDeadlineService.extend_deadline(distribution, days_to_extend)
      redirect_back(fallback_location: manage_deadlines_admin_distributions_path,
                    notice: "Deadline extended by #{days_to_extend} days")
    else
      redirect_back(fallback_location: manage_deadlines_admin_distributions_path,
                    alert: "Failed to extend deadline")
    end
  end

  def bulk_extend_deadlines
    distribution_ids = params[:distribution_ids]&.split(",")&.map(&:to_i) || []
    days_to_extend = params[:extend_days]&.to_i || 7

    if distribution_ids.empty?
      redirect_to manage_deadlines_admin_distributions_path, alert: "No distributions selected"
      return
    end

    extended_count = QuoteDeadlineService.bulk_extend_deadlines(distribution_ids, days_to_extend)

    redirect_to manage_deadlines_admin_distributions_path,
                notice: "Extended deadlines for #{extended_count} distributions by #{days_to_extend} days"
  end

  def process_expired_deadlines
    result = QuoteDeadlineService.process_expired_deadlines!

    redirect_to manage_deadlines_admin_distributions_path,
                notice: "Processed deadlines: #{result[:expired]} expired, #{result[:reminders_sent]} reminders sent"
  end

  private

  def set_application
    @application = InsuranceApplication.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_distributions_path, alert: "Application not found"
  end

  def set_distribution
    @distribution = ApplicationDistribution.find(params[:distribution_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_distributions_path, alert: "Distribution not found"
  end

  def filter_params
    params.permit(:status, :insurance_type, :distribution_status, :sort, :search, :date_range)
  end

  def load_applications
    applications = InsuranceApplication.includes(:client, :application_distributions)

    # Apply filters
    applications = applications.where(status: @filter_params[:status]) if @filter_params[:status].present?
    applications = applications.where(insurance_type: @filter_params[:insurance_type]) if @filter_params[:insurance_type].present?

    # Distribution status filter
    case @filter_params[:distribution_status]
    when "distributed"
      applications = applications.where.not(distributed_at: nil)
    when "pending_distribution"
      applications = applications.where(distributed_at: nil, status: "submitted")
    when "no_responses"
      applications = applications.joins(:application_distributions)
                                .where(application_distributions: { status: "pending" })
                                .where("application_distributions.created_at < ?", 2.days.ago)
    end

    # Search
    if @filter_params[:search].present?
      search_term = "%#{@filter_params[:search]}%"
      applications = applications.joins(:client)
                                .where("clients.first_name ILIKE ? OR clients.last_name ILIKE ? OR insurance_applications.application_number ILIKE ?",
                                       search_term, search_term, search_term)
    end

    # Sorting
    case @filter_params[:sort]
    when "created_desc"
      applications = applications.order(created_at: :desc)
    when "created_asc"
      applications = applications.order(created_at: :asc)
    when "distributed_desc"
      applications = applications.order(distributed_at: :desc)
    when "status"
      applications = applications.order(:status)
    else
      applications = applications.order(created_at: :desc)
    end

    applications.limit(100)
  end

  def calculate_summary_stats
    all_applications = InsuranceApplication.all

    {
      total_applications: all_applications.count,
      distributed_applications: all_applications.where.not(distributed_at: nil).count,
      pending_distribution: all_applications.where(distributed_at: nil, status: "submitted").count,
      total_distributions: ApplicationDistribution.count,
      pending_distributions: ApplicationDistribution.pending.count,
      responded_distributions: ApplicationDistribution.where.not(status: "pending").count,
      avg_response_time: calculate_avg_response_time,
      companies_with_pending: companies_with_pending_count
    }
  end

  def recent_distributions
    ApplicationDistribution.includes(:insurance_application, :insurance_company)
                          .order(created_at: :desc)
                          .limit(10)
  end

  def find_eligible_companies_for_manual_assignment
    # Get companies not yet assigned to this application
    already_assigned = @application.application_distributions.pluck(:insurance_company_id)

    InsuranceCompany.active
                   .where.not(id: already_assigned)
                   .order(:name)
  end

  def calculate_distribution_stats
    distributions = @application.application_distributions

    {
      total_distributed: distributions.count,
      pending: distributions.pending.count,
      viewed: distributions.viewed.count,
      quoted: distributions.quoted.count,
      ignored: distributions.ignored.count,
      expired: distributions.expired.count,
      avg_match_score: distributions.average(:match_score)&.round(1) || 0,
      best_match_score: distributions.maximum(:match_score) || 0,
      response_rate: calculate_response_rate(distributions)
    }
  end

  def calculate_response_rate(distributions)
    total = distributions.count
    return 0 if total.zero?

    responded = distributions.where.not(status: "pending").count
    ((responded.to_f / total) * 100).round(1)
  end

  def calculate_avg_response_time
    distributions = ApplicationDistribution.where.not(viewed_at: nil)
    return 0 if distributions.empty?

    total_time = distributions.sum { |d| (d.viewed_at - d.created_at).to_i }
    (total_time / distributions.count / 3600.0).round(1) # Convert to hours
  end

  def companies_with_pending_count
    ApplicationDistribution.pending
                          .distinct
                          .count(:insurance_company_id)
  end

  def bulk_redistribute(application_ids)
    applications = InsuranceApplication.where(id: application_ids)
    success_count = 0

    applications.each do |application|
      result = ApplicationDistributionService.redistribute_application(application,
                                                                      distributed_by: current_user,
                                                                      method: "manual")
      success_count += 1 if result[:success]
    end

    redirect_to admin_distributions_path,
                notice: "Redistributed #{success_count} of #{applications.count} applications"
  end

  def bulk_expire(application_ids)
    expired_count = ApplicationDistribution.joins(:insurance_application)
                                          .where(insurance_applications: { id: application_ids })
                                          .pending
                                          .update_all(status: "expired", expired_at: Time.current)

    redirect_to admin_distributions_path,
                notice: "Expired #{expired_count} distributions"
  end

  def bulk_send_reminders(application_ids)
    distributions = ApplicationDistribution.joins(:insurance_application)
                                          .where(insurance_applications: { id: application_ids })
                                          .pending

    distributions.each do |distribution|
      InsuranceCompanyMailer.application_reminder(distribution).deliver_later
    end

    redirect_to admin_distributions_path,
                notice: "Sent reminders for #{distributions.count} distributions"
  end

  def parse_date_range
    case params[:date_range]
    when "today"
      Date.current.beginning_of_day..Date.current.end_of_day
    when "week"
      1.week.ago..Time.current
    when "month"
      1.month.ago..Time.current
    else
      7.days.ago..Time.current
    end
  end

  def build_analytics_data
    {
      distributions_over_time: distributions_over_time_data,
      response_rates_by_company: response_rates_by_company_data,
      match_score_distribution: match_score_distribution_data,
      insurance_type_performance: insurance_type_performance_data
    }
  end

  def distributions_over_time_data
    ApplicationDistribution.where(created_at: @date_range)
                          .group_by_day(:created_at)
                          .count
  end

  def response_rates_by_company_data
    InsuranceCompany.joins(:application_distributions)
                   .where(application_distributions: { created_at: @date_range })
                   .group("insurance_companies.name")
                   .group("application_distributions.status")
                   .count
  end

  def match_score_distribution_data
    ApplicationDistribution.where(created_at: @date_range)
                          .group('CASE
                                   WHEN match_score >= 70 THEN \'High (70+)\'
                                   WHEN match_score >= 40 THEN \'Medium (40-69)\'
                                   ELSE \'Low (<40)\'
                                 END')
                          .count
  end

  def insurance_type_performance_data
    InsuranceApplication.joins(:application_distributions)
                       .where(application_distributions: { created_at: @date_range })
                       .group(:insurance_type)
                       .group("application_distributions.status")
                       .count
  end

  def calculate_deadline_stats
    all_distributions = ApplicationDistribution.active

    {
      total_active: all_distributions.count,
      approaching_deadline: all_distributions.select(&:deadline_approaching?).count,
      overdue: all_distributions.select(&:deadline_expired?).count,
      with_quotes: all_distributions.select(&:has_submitted_quote?).count,
      avg_response_time: calculate_avg_distribution_response_time
    }
  end

  def calculate_avg_distribution_response_time
    distributions = ApplicationDistribution.where.not(viewed_at: nil)
    return 0 if distributions.empty?

    total_time = distributions.sum { |d| (d.viewed_at - d.created_at).to_i }
    (total_time / distributions.count / 3600.0).round(1) # Convert to hours
  end
end
