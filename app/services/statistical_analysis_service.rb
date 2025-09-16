# frozen_string_literal: true

class StatisticalAnalysisService
  include Singleton
  
  # Core statistical methods for insurance data analysis
  def self.analyze_application_trends(organization, time_period = 30.days)
    new.analyze_application_trends(organization, time_period)
  end
  
  def self.calculate_risk_scores(organization, application_type = nil)
    new.calculate_risk_scores(organization, application_type)
  end
  
  def self.predict_claim_likelihood(application)
    new.predict_claim_likelihood(application)
  end
  
  def self.detect_anomalies(organization, metric_type, time_period = 7.days)
    new.detect_anomalies(organization, metric_type, time_period)
  end
  
  def self.forecast_business_metrics(organization, metric, periods = 12)
    new.forecast_business_metrics(organization, metric, periods)
  end
  
  def analyze_application_trends(organization, time_period)
    start_date = time_period.ago
    applications = organization.insurance_applications
                             .where(created_at: start_date..Time.current)
    
    return {} if applications.empty?
    
    {
      trend_analysis: calculate_trend_metrics(applications),
      volume_analysis: analyze_application_volume(applications, start_date),
      conversion_analysis: analyze_conversion_rates(applications),
      seasonal_patterns: detect_seasonal_patterns(applications),
      performance_score: calculate_trend_performance_score(applications)
    }
  end
  
  def calculate_risk_scores(organization, application_type = nil)
    applications = organization.insurance_applications
    applications = applications.where(application_type: application_type) if application_type
    
    risk_factors = {
      application_complexity: analyze_application_complexity(applications),
      processing_time_variance: analyze_processing_time_variance(applications),
      rejection_patterns: analyze_rejection_patterns(applications),
      document_completeness: analyze_document_completeness(applications),
      client_history: analyze_client_history(applications)
    }
    
    # Calculate composite risk score (0-100, higher = more risk)
    composite_score = calculate_composite_risk_score(risk_factors)
    
    {
      risk_factors: risk_factors,
      composite_score: composite_score,
      risk_level: categorize_risk_level(composite_score),
      recommendations: generate_risk_recommendations(risk_factors, composite_score)
    }
  end
  
  def predict_claim_likelihood(application)
    return { error: 'Application not found' } unless application
    
    # Gather features for prediction
    features = extract_prediction_features(application)
    
    # Calculate claim likelihood using various factors
    likelihood_score = calculate_claim_likelihood_score(features)
    
    {
      claim_likelihood: likelihood_score,
      risk_level: categorize_claim_risk(likelihood_score),
      contributing_factors: identify_risk_contributors(features),
      recommendations: generate_claim_prevention_recommendations(features, likelihood_score),
      confidence_interval: calculate_prediction_confidence(features)
    }
  end
  
  def detect_anomalies(organization, metric_type, time_period)
    data_points = gather_metric_data(organization, metric_type, time_period)
    return { anomalies: [], message: 'Insufficient data' } if data_points.length < 10
    
    anomalies = []
    
    # Statistical anomaly detection using Z-score and IQR methods
    z_score_anomalies = detect_z_score_anomalies(data_points)
    iqr_anomalies = detect_iqr_anomalies(data_points)
    trend_anomalies = detect_trend_anomalies(data_points)
    
    anomalies = (z_score_anomalies + iqr_anomalies + trend_anomalies).uniq
    
    {
      anomalies: anomalies,
      total_data_points: data_points.length,
      anomaly_rate: (anomalies.length.to_f / data_points.length * 100).round(2),
      detection_methods: {
        z_score: z_score_anomalies.length,
        iqr: iqr_anomalies.length,
        trend: trend_anomalies.length
      },
      severity_analysis: categorize_anomaly_severity(anomalies, data_points)
    }
  end
  
  def forecast_business_metrics(organization, metric, periods)
    historical_data = gather_historical_metric_data(organization, metric, periods * 3)
    return { error: 'Insufficient historical data' } if historical_data.length < periods
    
    # Use simple moving average and trend analysis for forecasting
    forecast_values = calculate_forecast_values(historical_data, periods)
    confidence_intervals = calculate_forecast_confidence_intervals(historical_data, forecast_values)
    
    {
      historical_data: historical_data.last(periods),
      forecast: forecast_values,
      confidence_intervals: confidence_intervals,
      trend_direction: determine_trend_direction(historical_data),
      forecast_accuracy: estimate_forecast_accuracy(historical_data),
      seasonal_adjustments: calculate_seasonal_adjustments(historical_data)
    }
  end
  
  private
  
  def calculate_trend_metrics(applications)
    daily_counts = applications.group_by_day(:created_at).count
    return {} if daily_counts.empty?
    
    values = daily_counts.values
    dates = daily_counts.keys
    
    {
      total_applications: applications.count,
      daily_average: (values.sum.to_f / values.length).round(2),
      growth_rate: calculate_growth_rate(values),
      volatility: calculate_volatility(values),
      trend_direction: determine_trend_direction(values),
      peak_day: dates[values.index(values.max)],
      lowest_day: dates[values.index(values.min)]
    }
  end
  
  def analyze_application_volume(applications, start_date)
    total_days = ((Time.current - start_date) / 1.day).ceil
    daily_volumes = applications.group_by_day(:created_at).count
    
    {
      total_volume: applications.count,
      daily_average: (applications.count.to_f / total_days).round(2),
      peak_volume: daily_volumes.values.max || 0,
      volume_distribution: calculate_volume_distribution(daily_volumes),
      working_day_average: calculate_working_day_average(daily_volumes),
      weekend_average: calculate_weekend_average(daily_volumes)
    }
  end
  
  def analyze_conversion_rates(applications)
    total = applications.count
    return {} if total.zero?
    
    by_status = applications.group(:status).count
    
    {
      submission_rate: calculate_percentage(by_status['submitted'] || 0, total),
      approval_rate: calculate_percentage(by_status['approved'] || 0, total),
      rejection_rate: calculate_percentage(by_status['rejected'] || 0, total),
      pending_rate: calculate_percentage((by_status['draft'] || 0) + (by_status['submitted'] || 0), total),
      conversion_funnel: calculate_conversion_funnel(by_status, total)
    }
  end
  
  def detect_seasonal_patterns(applications)
    monthly_data = applications.group_by_month(:created_at).count
    return {} if monthly_data.empty?
    
    # Analyze patterns by month, day of week, etc.
    {
      monthly_patterns: analyze_monthly_patterns(monthly_data),
      weekly_patterns: analyze_weekly_patterns(applications),
      seasonal_index: calculate_seasonal_index(monthly_data),
      peak_seasons: identify_peak_seasons(monthly_data)
    }
  end
  
  def calculate_trend_performance_score(applications)
    # Calculate a performance score based on various metrics (0-100)
    metrics = {
      volume_consistency: calculate_volume_consistency(applications),
      processing_efficiency: calculate_processing_efficiency(applications),
      quality_score: calculate_quality_score(applications),
      growth_momentum: calculate_growth_momentum(applications)
    }
    
    # Weighted average of different performance aspects
    score = (metrics[:volume_consistency] * 0.25 +
            metrics[:processing_efficiency] * 0.3 +
            metrics[:quality_score] * 0.25 +
            metrics[:growth_momentum] * 0.2).round(2)
    
    {
      overall_score: score,
      component_scores: metrics,
      performance_level: categorize_performance_level(score),
      improvement_areas: identify_improvement_areas(metrics)
    }
  end
  
  def calculate_growth_rate(values)
    return 0 if values.length < 2
    
    first_half = values[0...(values.length / 2)]
    second_half = values[(values.length / 2)..-1]
    
    first_avg = first_half.sum.to_f / first_half.length
    second_avg = second_half.sum.to_f / second_half.length
    
    return 0 if first_avg.zero?
    
    ((second_avg - first_avg) / first_avg * 100).round(2)
  end
  
  def calculate_volatility(values)
    return 0 if values.length < 2
    
    mean = values.sum.to_f / values.length
    variance = values.map { |v| (v - mean) ** 2 }.sum / values.length
    Math.sqrt(variance).round(2)
  end
  
  def determine_trend_direction(values)
    return 'stable' if values.length < 3
    
    # Simple trend analysis using linear regression slope
    n = values.length
    x_values = (1..n).to_a
    
    x_mean = x_values.sum.to_f / n
    y_mean = values.sum.to_f / n
    
    numerator = x_values.zip(values).map { |x, y| (x - x_mean) * (y - y_mean) }.sum
    denominator = x_values.map { |x| (x - x_mean) ** 2 }.sum
    
    return 'stable' if denominator.zero?
    
    slope = numerator / denominator
    
    case
    when slope > 0.1 then 'increasing'
    when slope < -0.1 then 'decreasing'
    else 'stable'
    end
  end
  
  def extract_prediction_features(application)
    {
      application_type: application.application_type,
      coverage_amount: application.coverage_amount || 0,
      client_age: calculate_client_age(application.client),
      client_history: analyze_single_client_history(application.client),
      document_completeness: calculate_application_document_completeness(application),
      processing_time: calculate_application_processing_time(application),
      risk_factors: extract_application_risk_factors(application),
      seasonal_factor: calculate_seasonal_factor(application.created_at),
      geographic_risk: calculate_geographic_risk(application)
    }
  end
  
  def calculate_claim_likelihood_score(features)
    # Weighted scoring system based on various risk factors
    score = 0
    
    # Application type risk weights
    type_weights = {
      'motor' => 15,
      'fire' => 10,
      'liability' => 20,
      'general_accident' => 25,
      'bonds' => 5
    }
    score += type_weights[features[:application_type]] || 10
    
    # Coverage amount impact
    if features[:coverage_amount] > 100_000
      score += 15
    elsif features[:coverage_amount] > 50_000
      score += 10
    else
      score += 5
    end
    
    # Client age factor
    client_age = features[:client_age] || 30
    if client_age < 25 || client_age > 65
      score += 10
    elsif client_age < 35 || client_age > 55
      score += 5
    end
    
    # Historical factors
    score += features[:client_history][:claim_frequency] * 15
    score += (100 - features[:document_completeness]) * 0.2
    
    # Processing time anomalies
    if features[:processing_time] > 30
      score += 10
    end
    
    # Seasonal adjustments
    score += features[:seasonal_factor]
    
    # Geographic risk
    score += features[:geographic_risk]
    
    # Normalize to 0-100 scale
    [score, 100].min.round(2)
  end
  
  def gather_metric_data(organization, metric_type, time_period)
    case metric_type
    when 'applications'
      organization.insurance_applications
                 .where(created_at: time_period.ago..Time.current)
                 .group_by_day(:created_at)
                 .count
                 .values
    when 'quotes'
      organization.quotes
                 .where(created_at: time_period.ago..Time.current)
                 .group_by_day(:created_at)
                 .count
                 .values
    when 'revenue'
      # Calculate daily revenue from accepted quotes
      organization.quotes
                 .where(status: 'accepted', accepted_at: time_period.ago..Time.current)
                 .group_by_day(:accepted_at)
                 .sum(:total_premium)
                 .values
    else
      []
    end
  end
  
  def detect_z_score_anomalies(data_points, threshold = 2.5)
    return [] if data_points.length < 3
    
    mean = data_points.sum.to_f / data_points.length
    std_dev = Math.sqrt(data_points.map { |x| (x - mean) ** 2 }.sum / data_points.length)
    
    return [] if std_dev.zero?
    
    anomalies = []
    data_points.each_with_index do |value, index|
      z_score = (value - mean) / std_dev
      if z_score.abs > threshold
        anomalies << {
          index: index,
          value: value,
          z_score: z_score.round(3),
          type: 'z_score',
          severity: z_score.abs > 3 ? 'high' : 'medium'
        }
      end
    end
    
    anomalies
  end
  
  def detect_iqr_anomalies(data_points)
    return [] if data_points.length < 4
    
    sorted = data_points.sort
    n = sorted.length
    
    q1 = sorted[n / 4]
    q3 = sorted[(3 * n) / 4]
    iqr = q3 - q1
    
    lower_bound = q1 - (1.5 * iqr)
    upper_bound = q3 + (1.5 * iqr)
    
    anomalies = []
    data_points.each_with_index do |value, index|
      if value < lower_bound || value > upper_bound
        anomalies << {
          index: index,
          value: value,
          lower_bound: lower_bound,
          upper_bound: upper_bound,
          type: 'iqr',
          severity: value < (q1 - 3 * iqr) || value > (q3 + 3 * iqr) ? 'high' : 'medium'
        }
      end
    end
    
    anomalies
  end
  
  def calculate_percentage(numerator, denominator)
    return 0 if denominator.zero?
    ((numerator.to_f / denominator) * 100).round(2)
  end
  
  def calculate_client_age(client)
    return 35 unless client&.date_of_birth # Default age if not available
    ((Time.current - client.date_of_birth) / 1.year).floor
  end
  
  def analyze_single_client_history(client)
    previous_apps = client.insurance_applications.where.not(id: client.insurance_applications.last&.id)
    
    {
      previous_applications: previous_apps.count,
      claim_frequency: calculate_claim_frequency(client),
      average_coverage: previous_apps.average(:coverage_amount) || 0,
      approval_rate: calculate_client_approval_rate(previous_apps)
    }
  end
  
  def calculate_claim_frequency(client)
    # This would need to be implemented based on claims data structure
    # For now, return a placeholder
    0.1 # 10% historical claim rate
  end
  
  def calculate_client_approval_rate(applications)
    return 100 if applications.empty?
    approved = applications.where(status: 'approved').count
    ((approved.to_f / applications.count) * 100).round(2)
  end
end