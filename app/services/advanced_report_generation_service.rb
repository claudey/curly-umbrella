# frozen_string_literal: true

class AdvancedReportGenerationService
  include ActionView::Helpers::NumberHelper
  
  def self.generate_report(analytics_report)
    new(analytics_report).generate
  end
  
  def initialize(analytics_report)
    @report = analytics_report
    @organization = analytics_report.organization
    @config = analytics_report.configuration
  end
  
  def generate
    start_time = Time.current
    
    case @report.report_type
    when 'executive_dashboard'
      data = generate_executive_dashboard
    when 'trend_analysis'
      data = generate_trend_analysis
    when 'risk_assessment'
      data = generate_risk_assessment
    when 'performance_metrics'
      data = generate_performance_metrics
    when 'financial_summary'
      data = generate_financial_summary
    when 'client_analytics'
      data = generate_client_analytics
    when 'quote_analytics'
      data = generate_quote_analytics
    when 'application_analytics'
      data = generate_application_analytics
    when 'custom_query'
      data = generate_custom_query_report
    else
      raise "Unsupported report type: #{@report.report_type}"
    end
    
    generation_time = (Time.current - start_time).round(2)
    
    {
      data: data,
      metadata: {
        generated_at: Time.current.iso8601,
        generation_time_seconds: generation_time,
        organization_id: @organization.id,
        report_type: @report.report_type,
        data_points: count_data_points(data),
        version: '1.0'
      },
      file_size: data.to_json.bytesize
    }
  end
  
  private
  
  def generate_executive_dashboard
    time_range = parse_time_range(@config.dig('dashboard', 'time_range') || '30d')
    
    {
      overview: generate_executive_overview(time_range),
      kpi_metrics: generate_executive_kpis(time_range),
      financial_summary: generate_executive_financial_summary(time_range),
      performance_indicators: generate_performance_indicators(time_range),
      risk_alerts: generate_risk_alerts,
      trend_analysis: generate_executive_trends(time_range),
      comparative_analysis: generate_comparative_analysis(time_range),
      action_items: generate_action_items,
      forecast: generate_executive_forecast(time_range)
    }
  end
  
  def generate_trend_analysis
    metrics = @config.dig('analysis', 'metrics') || ['applications', 'quotes', 'revenue']
    time_range = parse_time_range(@config.dig('analysis', 'time_range') || '90d')
    granularity = @config.dig('analysis', 'granularity') || 'daily'
    
    analysis_data = {}
    
    metrics.each do |metric|
      analysis_data[metric] = analyze_metric_trends(metric, time_range, granularity)
    end
    
    {
      metrics_analysis: analysis_data,
      cross_correlation: analyze_cross_correlations(metrics, time_range),
      seasonal_patterns: detect_seasonal_patterns(metrics, time_range),
      trend_summary: summarize_trends(analysis_data),
      predictions: generate_trend_predictions(analysis_data, time_range),
      anomalies: detect_trend_anomalies(analysis_data),
      recommendations: generate_trend_recommendations(analysis_data)
    }
  end
  
  def generate_risk_assessment
    risk_factors = @config.dig('assessment', 'risk_factors') || ['default']
    time_range = parse_time_range(@config.dig('assessment', 'time_range') || '30d')
    threshold = @config.dig('assessment', 'threshold') || 70
    
    {
      overall_risk_score: calculate_overall_risk_score(time_range),
      risk_factors_analysis: analyze_individual_risk_factors(risk_factors, time_range),
      risk_distribution: analyze_risk_distribution(time_range),
      high_risk_items: identify_high_risk_items(threshold, time_range),
      risk_trends: analyze_risk_trends(time_range),
      mitigation_strategies: generate_mitigation_strategies,
      risk_forecast: forecast_risk_levels(time_range),
      compliance_status: assess_compliance_status
    }
  end
  
  def generate_performance_metrics
    time_range = parse_time_range(@config.dig('performance', 'time_range') || '30d')
    
    {
      operational_metrics: calculate_operational_metrics(time_range),
      efficiency_metrics: calculate_efficiency_metrics(time_range),
      quality_metrics: calculate_quality_metrics(time_range),
      customer_satisfaction: calculate_customer_satisfaction_metrics(time_range),
      team_performance: calculate_team_performance_metrics(time_range),
      process_optimization: identify_process_optimization_opportunities(time_range),
      benchmarking: generate_performance_benchmarks(time_range),
      improvement_recommendations: generate_performance_recommendations(time_range)
    }
  end
  
  def generate_financial_summary
    time_range = parse_time_range(@config.dig('financial', 'time_range') || '30d')
    
    {
      revenue_analysis: analyze_revenue_metrics(time_range),
      profitability_analysis: analyze_profitability(time_range),
      cost_analysis: analyze_cost_metrics(time_range),
      commission_analysis: analyze_commission_structure(time_range),
      financial_trends: analyze_financial_trends(time_range),
      budget_variance: analyze_budget_variance(time_range),
      cash_flow_analysis: analyze_cash_flow(time_range),
      financial_forecasting: generate_financial_forecast(time_range)
    }
  end
  
  def generate_client_analytics
    time_range = parse_time_range(@config.dig('client', 'time_range') || '90d')
    
    {
      client_demographics: analyze_client_demographics(time_range),
      client_behavior: analyze_client_behavior(time_range),
      client_lifetime_value: calculate_client_lifetime_value(time_range),
      client_retention: analyze_client_retention(time_range),
      client_acquisition: analyze_client_acquisition(time_range),
      client_segmentation: perform_client_segmentation(time_range),
      client_satisfaction: measure_client_satisfaction(time_range),
      churn_analysis: analyze_client_churn(time_range)
    }
  end
  
  def generate_quote_analytics
    time_range = parse_time_range(@config.dig('quote', 'time_range') || '30d')
    
    {
      quote_volume_analysis: analyze_quote_volume(time_range),
      quote_conversion_rates: analyze_quote_conversion(time_range),
      quote_value_analysis: analyze_quote_values(time_range),
      quote_processing_efficiency: analyze_quote_processing(time_range),
      competitive_analysis: analyze_quote_competitiveness(time_range),
      pricing_optimization: analyze_pricing_optimization(time_range),
      quote_quality_metrics: assess_quote_quality(time_range),
      rejection_analysis: analyze_quote_rejections(time_range)
    }
  end
  
  def generate_application_analytics
    time_range = parse_time_range(@config.dig('application', 'time_range') || '30d')
    
    {
      application_volume_trends: analyze_application_volume(time_range),
      application_processing_metrics: analyze_application_processing(time_range),
      application_approval_rates: analyze_approval_rates(time_range),
      application_types_analysis: analyze_application_types(time_range),
      document_completeness: analyze_document_completeness(time_range),
      processing_bottlenecks: identify_processing_bottlenecks(time_range),
      quality_indicators: assess_application_quality(time_range),
      automation_opportunities: identify_automation_opportunities(time_range)
    }
  end
  
  def generate_custom_query_report
    query = @config.dig('query', 'sql')
    parameters = @config.dig('query', 'parameters') || {}
    
    # Security: Only allow SELECT statements and sanitize parameters
    unless query&.strip&.downcase&.start_with?('select')
      raise 'Only SELECT queries are allowed for custom reports'
    end
    
    # Execute query with proper parameter binding
    result = execute_safe_query(query, parameters)
    
    {
      query_results: result,
      row_count: result.length,
      column_info: extract_column_info(result),
      execution_summary: {
        query: query,
        parameters: parameters,
        executed_at: Time.current.iso8601
      }
    }
  end
  
  def generate_executive_overview(time_range)
    start_date = time_range.ago
    
    applications = @organization.insurance_applications.where(created_at: start_date..Time.current)
    quotes = @organization.quotes.where(created_at: start_date..Time.current)
    
    {
      period: format_time_range(time_range),
      total_applications: applications.count,
      total_quotes: quotes.count,
      total_revenue: quotes.where(status: 'accepted').sum(:total_premium),
      active_clients: @organization.clients.joins(:insurance_applications)
                                .where(insurance_applications: { created_at: start_date..Time.current })
                                .distinct.count,
      conversion_rate: calculate_conversion_rate(applications, quotes),
      average_quote_value: quotes.where(status: 'accepted').average(:total_premium)&.round(2) || 0,
      growth_metrics: calculate_growth_metrics(start_date)
    }
  end
  
  def generate_executive_kpis(time_range)
    start_date = time_range.ago
    
    {
      application_processing_time: calculate_average_processing_time(start_date),
      quote_response_time: calculate_average_quote_response_time(start_date),
      client_satisfaction_score: calculate_client_satisfaction_score(start_date),
      revenue_per_client: calculate_revenue_per_client(start_date),
      market_penetration: calculate_market_penetration(start_date),
      operational_efficiency: calculate_operational_efficiency(start_date),
      risk_adjusted_returns: calculate_risk_adjusted_returns(start_date),
      digital_adoption_rate: calculate_digital_adoption_rate(start_date)
    }
  end
  
  def analyze_metric_trends(metric, time_range, granularity)
    start_date = time_range.ago
    
    case metric
    when 'applications'
      data = @organization.insurance_applications
                         .where(created_at: start_date..Time.current)
                         .send("group_by_#{granularity}", :created_at)
                         .count
    when 'quotes'
      data = @organization.quotes
                         .where(created_at: start_date..Time.current)
                         .send("group_by_#{granularity}", :created_at)
                         .count
    when 'revenue'
      data = @organization.quotes
                         .where(status: 'accepted', accepted_at: start_date..Time.current)
                         .send("group_by_#{granularity}", :accepted_at)
                         .sum(:total_premium)
    else
      data = {}
    end
    
    {
      raw_data: data,
      trend_direction: StatisticalAnalysisService.new.send(:determine_trend_direction, data.values),
      growth_rate: StatisticalAnalysisService.new.send(:calculate_growth_rate, data.values),
      volatility: StatisticalAnalysisService.new.send(:calculate_volatility, data.values),
      moving_average: calculate_moving_average(data.values, 7),
      seasonal_index: calculate_seasonal_index(data)
    }
  end
  
  def parse_time_range(range_string)
    case range_string
    when /(\d+)d/ then $1.to_i.days
    when /(\d+)w/ then $1.to_i.weeks
    when /(\d+)m/ then $1.to_i.months
    when /(\d+)y/ then $1.to_i.years
    else 30.days
    end
  end
  
  def format_time_range(time_range)
    case time_range
    when (1.day)..(6.days) then "#{time_range.in_days.to_i} days"
    when (1.week)..(3.weeks) then "#{time_range.in_weeks.to_i} weeks"
    when (1.month)..(11.months) then "#{time_range.in_months.to_i} months"
    else "#{time_range.in_years.to_i} years"
    end
  end
  
  def calculate_conversion_rate(applications, quotes)
    return 0 if applications.count.zero?
    accepted_quotes = quotes.where(status: 'accepted').count
    ((accepted_quotes.to_f / applications.count) * 100).round(2)
  end
  
  def calculate_moving_average(values, window_size)
    return [] if values.length < window_size
    
    moving_averages = []
    values.each_cons(window_size) do |window|
      moving_averages << (window.sum.to_f / window_size).round(2)
    end
    moving_averages
  end
  
  def calculate_seasonal_index(data)
    return {} if data.empty?
    
    # Group by month if we have enough data
    if data.keys.first.respond_to?(:month)
      monthly_data = data.group_by { |date, _| date.month }
      overall_average = data.values.sum.to_f / data.values.length
      
      seasonal_indices = {}
      monthly_data.each do |month, month_data|
        month_average = month_data.map(&:last).sum.to_f / month_data.length
        seasonal_indices[month] = overall_average.zero? ? 1.0 : (month_average / overall_average).round(3)
      end
      
      seasonal_indices
    else
      {}
    end
  end
  
  def execute_safe_query(query, parameters)
    # Implement safe query execution with parameter binding
    # This is a simplified version - in production, you'd want more robust security
    begin
      sanitized_query = ActiveRecord::Base.sanitize_sql([query, parameters])
      ActiveRecord::Base.connection.execute(sanitized_query).to_a
    rescue => e
      Rails.logger.error "Custom query execution failed: #{e.message}"
      raise "Query execution failed: #{e.message}"
    end
  end
  
  def count_data_points(data)
    case data
    when Hash
      data.values.sum { |v| count_data_points(v) }
    when Array
      data.length
    else
      1
    end
  end
  
  def extract_column_info(result)
    return [] if result.empty?
    
    first_row = result.first
    first_row.keys.map do |key|
      {
        name: key,
        type: infer_column_type(first_row[key])
      }
    end
  end
  
  def infer_column_type(value)
    case value
    when Integer then 'integer'
    when Float, BigDecimal then 'decimal'
    when Date then 'date'
    when Time, DateTime then 'datetime'
    when TrueClass, FalseClass then 'boolean'
    else 'string'
    end
  end
end