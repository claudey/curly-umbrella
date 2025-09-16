# frozen_string_literal: true

class ExecutiveDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_executive_access
  before_action :set_time_period
  
  def index
    @dashboard_data = generate_executive_dashboard_data
    @analytics_reports = current_organization.analytics_reports
                                           .where(report_type: 'executive_dashboard')
                                           .active
                                           .order(created_at: :desc)
                                           .limit(5)
    
    @quick_actions = generate_quick_actions
    @alerts = generate_executive_alerts
    
    respond_to do |format|
      format.html
      format.json { render json: @dashboard_data }
    end
  end
  
  def analytics
    @report_types = AnalyticsReport::REPORT_TYPES
    @reports = current_organization.analytics_reports
                                 .active
                                 .order(created_at: :desc)
                                 .page(params[:page])
                                 .per(25)
    
    @recent_reports = @reports.completed.limit(10)
    @scheduled_reports = @reports.scheduled.limit(10)
  end
  
  def trends
    @trend_analysis = StatisticalAnalysisService.analyze_application_trends(
      current_organization, 
      @time_period
    )
    
    @risk_analysis = StatisticalAnalysisService.calculate_risk_scores(
      current_organization
    )
    
    @anomalies = StatisticalAnalysisService.detect_anomalies(
      current_organization,
      params[:metric] || 'applications',
      @time_period
    )
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          trends: @trend_analysis,
          risks: @risk_analysis,
          anomalies: @anomalies
        }
      end
    end
  end
  
  def forecasting
    @forecasts = {}
    
    %w[applications quotes revenue].each do |metric|
      @forecasts[metric] = StatisticalAnalysisService.forecast_business_metrics(
        current_organization,
        metric,
        12 # 12 periods ahead
      )
    end
    
    @predictions = generate_business_predictions
    @recommendations = generate_strategic_recommendations
    
    respond_to do |format|
      format.html
      format.json { render json: { forecasts: @forecasts, predictions: @predictions } }
    end
  end
  
  def performance
    @performance_metrics = calculate_comprehensive_performance_metrics
    @benchmarks = calculate_industry_benchmarks
    @improvement_areas = identify_improvement_opportunities
    @performance_trends = analyze_performance_trends
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          metrics: @performance_metrics,
          benchmarks: @benchmarks,
          improvements: @improvement_areas,
          trends: @performance_trends
        }
      end
    end
  end
  
  def reports
    @report = current_organization.analytics_reports.find(params[:id])
    authorize_report_access!(@report)
    
    @report_data = @report.data
    @report_metadata = @report.metadata
    
    respond_to do |format|
      format.html
      format.json { render json: { data: @report_data, metadata: @report_metadata } }
      format.pdf { generate_pdf_report(@report) }
      format.xlsx { generate_excel_report(@report) }
    end
  end
  
  def create_report
    @report = current_organization.analytics_reports.build(report_params)
    @report.created_by = current_user
    
    if @report.save
      if params[:generate_now] == 'true'
        ReportGenerationJob.perform_later(@report)
        flash[:success] = 'Report created and generation started.'
      else
        flash[:success] = 'Report created successfully.'
      end
      
      redirect_to executive_dashboard_analytics_path
    else
      @report_types = AnalyticsReport::REPORT_TYPES
      flash[:error] = 'Failed to create report.'
      render :analytics, status: :unprocessable_entity
    end
  end
  
  def generate_report
    @report = current_organization.analytics_reports.find(params[:id])
    authorize_report_access!(@report)
    
    if @report.can_be_regenerated?
      ReportGenerationJob.perform_later(@report)
      render json: { 
        success: true, 
        message: 'Report generation started.',
        status: 'processing'
      }
    else
      render json: { 
        success: false, 
        message: 'Report cannot be regenerated at this time.',
        status: @report.status
      }, status: :unprocessable_entity
    end
  end
  
  def live_metrics
    metrics = {
      current_time: Time.current.iso8601,
      applications_today: current_organization.insurance_applications
                                            .where(created_at: Date.current.beginning_of_day..Time.current)
                                            .count,
      quotes_today: current_organization.quotes
                                       .where(created_at: Date.current.beginning_of_day..Time.current)
                                       .count,
      revenue_today: current_organization.quotes
                                        .where(status: 'accepted', 
                                              accepted_at: Date.current.beginning_of_day..Time.current)
                                        .sum(:total_premium),
      active_users: calculate_active_users_count,
      system_health: calculate_system_health_score,
      alerts_count: calculate_active_alerts_count
    }
    
    render json: metrics
  end
  
  def export_dashboard
    format = params[:format] || 'pdf'
    time_period = params[:time_period] || '30d'
    
    case format
    when 'pdf'
      generate_dashboard_pdf(time_period)
    when 'excel'
      generate_dashboard_excel(time_period)
    when 'csv'
      generate_dashboard_csv(time_period)
    else
      head :bad_request
    end
  end
  
  private
  
  def ensure_executive_access
    unless current_user.executive? || current_user.admin?
      redirect_to root_path, alert: 'Access denied. Executive privileges required.'
    end
  end
  
  def set_time_period
    @time_period = case params[:period]
                   when '7d' then 7.days
                   when '30d' then 30.days
                   when '90d' then 90.days
                   when '1y' then 1.year
                   else 30.days
                   end
  end
  
  def generate_executive_dashboard_data
    {
      overview: generate_overview_metrics,
      kpi_summary: generate_kpi_summary,
      financial_metrics: generate_financial_metrics,
      operational_metrics: generate_operational_metrics,
      charts_data: generate_charts_data,
      recent_activity: generate_recent_activity,
      performance_indicators: generate_performance_indicators
    }
  end
  
  def generate_overview_metrics
    start_date = @time_period.ago
    
    applications = current_organization.insurance_applications
                                     .where(created_at: start_date..Time.current)
    quotes = current_organization.quotes
                                .where(created_at: start_date..Time.current)
    
    {
      total_applications: applications.count,
      total_quotes: quotes.count,
      conversion_rate: calculate_conversion_rate(applications, quotes),
      total_revenue: quotes.where(status: 'accepted').sum(:total_premium),
      active_clients: calculate_active_clients(start_date),
      average_quote_value: quotes.where(status: 'accepted').average(:total_premium)&.round(2) || 0,
      growth_metrics: calculate_period_growth_metrics(start_date)
    }
  end
  
  def generate_kpi_summary
    start_date = @time_period.ago
    
    {
      application_processing_time: calculate_avg_processing_time(start_date),
      quote_response_time: calculate_avg_quote_response_time(start_date),
      client_satisfaction: calculate_client_satisfaction_score(start_date),
      revenue_per_client: calculate_revenue_per_client(start_date),
      operational_efficiency: calculate_operational_efficiency(start_date),
      digital_adoption: calculate_digital_adoption_rate(start_date)
    }
  end
  
  def generate_financial_metrics
    start_date = @time_period.ago
    
    quotes = current_organization.quotes.where(accepted_at: start_date..Time.current, status: 'accepted')
    
    {
      total_revenue: quotes.sum(:total_premium),
      revenue_by_type: quotes.joins(:insurance_application)
                            .group('insurance_applications.application_type')
                            .sum(:total_premium),
      monthly_revenue_trend: quotes.group_by_month(:accepted_at).sum(:total_premium),
      average_premium: quotes.average(:total_premium)&.round(2) || 0,
      commission_earned: calculate_total_commission(quotes),
      revenue_forecast: calculate_revenue_forecast(quotes)
    }
  end
  
  def generate_operational_metrics
    start_date = @time_period.ago
    
    {
      processing_efficiency: calculate_processing_efficiency_metrics(start_date),
      team_productivity: calculate_team_productivity_metrics(start_date),
      quality_metrics: calculate_quality_metrics(start_date),
      customer_service: calculate_customer_service_metrics(start_date),
      technology_adoption: calculate_technology_adoption_metrics(start_date)
    }
  end
  
  def generate_charts_data
    start_date = @time_period.ago
    
    {
      applications_timeline: current_organization.insurance_applications
                                               .where(created_at: start_date..Time.current)
                                               .group_by_day(:created_at)
                                               .count,
      quotes_timeline: current_organization.quotes
                                         .where(created_at: start_date..Time.current)
                                         .group_by_day(:created_at)
                                         .count,
      revenue_timeline: current_organization.quotes
                                          .where(status: 'accepted', accepted_at: start_date..Time.current)
                                          .group_by_day(:accepted_at)
                                          .sum(:total_premium),
      application_types_distribution: current_organization.insurance_applications
                                                        .where(created_at: start_date..Time.current)
                                                        .group(:application_type)
                                                        .count,
      quote_status_distribution: current_organization.quotes
                                                   .where(created_at: start_date..Time.current)
                                                   .group(:status)
                                                   .count
    }
  end
  
  def generate_quick_actions
    [
      {
        title: 'Generate Monthly Report',
        description: 'Create comprehensive monthly performance report',
        action: 'generate_monthly_report',
        icon: 'chart-bar',
        priority: 'high'
      },
      {
        title: 'Review Risk Alerts',
        description: 'Check high-risk applications and claims',
        action: 'review_risk_alerts',
        icon: 'exclamation-triangle',
        priority: 'medium'
      },
      {
        title: 'Team Performance Review',
        description: 'Analyze team productivity and efficiency',
        action: 'team_performance',
        icon: 'users',
        priority: 'medium'
      },
      {
        title: 'Financial Forecast',
        description: 'View revenue projections and budget analysis',
        action: 'financial_forecast',
        icon: 'trending-up',
        priority: 'low'
      }
    ]
  end
  
  def generate_executive_alerts
    alerts = []
    
    # Check for high-risk applications
    high_risk_count = current_organization.insurance_applications
                                        .where(created_at: 24.hours.ago..Time.current)
                                        .select { |app| 
                                          StatisticalAnalysisService.predict_claim_likelihood(app)[:claim_likelihood] > 70 
                                        }.count
    
    if high_risk_count > 0
      alerts << {
        type: 'warning',
        title: 'High Risk Applications',
        message: "#{high_risk_count} high-risk applications submitted in the last 24 hours",
        action_url: applications_path(filter: 'high_risk'),
        created_at: Time.current
      }
    end
    
    # Check for processing delays
    delayed_applications = current_organization.insurance_applications
                                             .where(status: 'submitted')
                                             .where('created_at < ?', 7.days.ago)
                                             .count
    
    if delayed_applications > 0
      alerts << {
        type: 'error',
        title: 'Processing Delays',
        message: "#{delayed_applications} applications have been pending for over 7 days",
        action_url: applications_path(filter: 'delayed'),
        created_at: Time.current
      }
    end
    
    # Check for revenue targets
    monthly_target = 100_000 # This would come from settings
    current_month_revenue = current_organization.quotes
                                              .where(status: 'accepted', 
                                                    accepted_at: Date.current.beginning_of_month..Time.current)
                                              .sum(:total_premium)
    
    if current_month_revenue < (monthly_target * 0.8) && Date.current.day > 20
      alerts << {
        type: 'info',
        title: 'Revenue Target Alert',
        message: "Monthly revenue at #{((current_month_revenue / monthly_target) * 100).round}% of target",
        action_url: executive_dashboard_financial_path,
        created_at: Time.current
      }
    end
    
    alerts
  end
  
  def calculate_conversion_rate(applications, quotes)
    return 0 if applications.count.zero?
    accepted_quotes = quotes.where(status: 'accepted').count
    ((accepted_quotes.to_f / applications.count) * 100).round(2)
  end
  
  def calculate_active_clients(start_date)
    current_organization.clients
                       .joins(:insurance_applications)
                       .where(insurance_applications: { created_at: start_date..Time.current })
                       .distinct
                       .count
  end
  
  def report_params
    params.require(:analytics_report).permit(
      :name, :description, :report_type, :frequency,
      configuration: {}
    )
  end
  
  def authorize_report_access!(report)
    unless current_user.can_access_report?(report)
      raise ActiveRecord::RecordNotFound
    end
  end
end