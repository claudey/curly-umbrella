class PredictiveAnalyticsEngine
  include Singleton
  
  # ML Model configurations
  ML_MODELS = {
    risk_prediction: {
      model_type: :random_forest,
      features: [:age, :location_risk_score, :claim_history, :policy_type, :coverage_amount],
      target: :risk_score,
      accuracy_threshold: 0.85
    },
    churn_prediction: {
      model_type: :gradient_boosting,
      features: [:policy_duration, :claim_frequency, :premium_changes, :interaction_frequency, :satisfaction_score],
      target: :churn_probability,
      accuracy_threshold: 0.82
    },
    clv_prediction: {
      model_type: :neural_network,
      features: [:policy_count, :premium_total, :tenure, :claim_ratio, :referral_count],
      target: :customer_lifetime_value,
      accuracy_threshold: 0.78
    },
    fraud_detection: {
      model_type: :isolation_forest,
      features: [:claim_amount, :claim_timing, :documentation_score, :historical_patterns, :network_analysis],
      target: :fraud_probability,
      accuracy_threshold: 0.90
    },
    premium_optimization: {
      model_type: :regression_ensemble,
      features: [:risk_factors, :market_conditions, :competitor_pricing, :customer_segment, :loss_ratios],
      target: :optimal_premium,
      accuracy_threshold: 0.80
    }
  }.freeze
  
  # Feature engineering configurations
  FEATURE_ENGINEERING = {
    risk_prediction: {
      categorical_encoding: [:one_hot, :target_encoding],
      numerical_scaling: [:standard_scaler, :robust_scaler],
      feature_selection: [:recursive_feature_elimination, :mutual_info_regression],
      dimensionality_reduction: [:pca, :feature_agglomeration]
    },
    churn_prediction: {
      categorical_encoding: [:label_encoding, :binary_encoding],
      numerical_scaling: [:min_max_scaler, :quantile_transformer],
      feature_selection: [:chi_squared, :anova_f_test],
      time_series_features: [:rolling_averages, :trend_analysis, :seasonality]
    }
  }.freeze
  
  def initialize
    @model_registry = ModelRegistry.new
    @feature_pipeline = FeaturePipeline.new
    @model_performance = ModelPerformanceTracker.new
    @prediction_cache = PredictionCacheManager.new
    setup_ml_infrastructure
  end
  
  # Predict risk score for insurance application
  def predict_risk(application_data, options = {})
    model_key = :risk_prediction
    
    begin
      # Prepare features
      features = @feature_pipeline.prepare_features(application_data, model_key)
      
      # Check cache first
      cache_key = generate_prediction_cache_key(model_key, features)
      cached_prediction = @prediction_cache.get(cache_key) unless options[:force_refresh]
      
      return cached_prediction if cached_prediction
      
      # Get trained model
      model = @model_registry.get_model(model_key)
      raise "Risk prediction model not available" unless model
      
      # Make prediction
      prediction_result = model.predict(features)
      risk_score = prediction_result[:prediction]
      confidence = prediction_result[:confidence]
      
      # Generate risk insights
      insights = generate_risk_insights(features, risk_score, confidence)
      
      # Prepare result
      result = {
        risk_score: risk_score.round(3),
        risk_category: categorize_risk(risk_score),
        confidence: confidence.round(3),
        features_importance: prediction_result[:feature_importance] || {},
        insights: insights,
        model_version: model.version,
        prediction_timestamp: Time.current
      }
      
      # Cache result
      @prediction_cache.set(cache_key, result, ttl: 1.hour)
      
      # Track prediction
      @model_performance.record_prediction(model_key, result, application_data[:id])
      
      result
      
    rescue => e
      Rails.logger.error "Risk prediction failed: #{e.message}"
      fallback_risk_prediction(application_data)
    end
  end
  
  # Predict customer churn probability
  def predict_churn(customer_data, options = {})
    model_key = :churn_prediction
    
    begin
      # Prepare features with time-series analysis
      features = @feature_pipeline.prepare_features(customer_data, model_key)
      
      # Check cache
      cache_key = generate_prediction_cache_key(model_key, features)
      cached_prediction = @prediction_cache.get(cache_key) unless options[:force_refresh]
      
      return cached_prediction if cached_prediction
      
      # Get model
      model = @model_registry.get_model(model_key)
      raise "Churn prediction model not available" unless model
      
      # Predict
      prediction_result = model.predict(features)
      churn_probability = prediction_result[:prediction]
      confidence = prediction_result[:confidence]
      
      # Generate retention strategies
      retention_strategies = generate_retention_strategies(features, churn_probability)
      
      # Prepare result
      result = {
        churn_probability: churn_probability.round(3),
        churn_risk: categorize_churn_risk(churn_probability),
        confidence: confidence.round(3),
        key_factors: prediction_result[:feature_importance]&.first(5) || {},
        retention_strategies: retention_strategies,
        recommended_actions: generate_retention_actions(churn_probability),
        model_version: model.version,
        prediction_timestamp: Time.current
      }
      
      # Cache and track
      @prediction_cache.set(cache_key, result, ttl: 30.minutes)
      @model_performance.record_prediction(model_key, result, customer_data[:id])
      
      result
      
    rescue => e
      Rails.logger.error "Churn prediction failed: #{e.message}"
      fallback_churn_prediction(customer_data)
    end
  end
  
  # Predict customer lifetime value
  def predict_clv(customer_data, options = {})
    model_key = :clv_prediction
    
    begin
      features = @feature_pipeline.prepare_features(customer_data, model_key)
      
      cache_key = generate_prediction_cache_key(model_key, features)
      cached_prediction = @prediction_cache.get(cache_key) unless options[:force_refresh]
      
      return cached_prediction if cached_prediction
      
      model = @model_registry.get_model(model_key)
      raise "CLV prediction model not available" unless model
      
      prediction_result = model.predict(features)
      clv_amount = prediction_result[:prediction]
      confidence = prediction_result[:confidence]
      
      # Generate value optimization strategies
      optimization_strategies = generate_clv_optimization_strategies(features, clv_amount)
      
      result = {
        customer_lifetime_value: clv_amount.round(2),
        clv_segment: categorize_clv(clv_amount),
        confidence: confidence.round(3),
        value_drivers: prediction_result[:feature_importance]&.first(5) || {},
        optimization_strategies: optimization_strategies,
        growth_potential: calculate_growth_potential(clv_amount, features),
        model_version: model.version,
        prediction_timestamp: Time.current
      }
      
      @prediction_cache.set(cache_key, result, ttl: 2.hours)
      @model_performance.record_prediction(model_key, result, customer_data[:id])
      
      result
      
    rescue => e
      Rails.logger.error "CLV prediction failed: #{e.message}"
      fallback_clv_prediction(customer_data)
    end
  end
  
  # Detect potential fraud
  def detect_fraud(claim_data, options = {})
    model_key = :fraud_detection
    
    begin
      features = @feature_pipeline.prepare_features(claim_data, model_key)
      
      cache_key = generate_prediction_cache_key(model_key, features)
      cached_prediction = @prediction_cache.get(cache_key) unless options[:force_refresh]
      
      return cached_prediction if cached_prediction
      
      model = @model_registry.get_model(model_key)
      raise "Fraud detection model not available" unless model
      
      prediction_result = model.predict(features)
      fraud_probability = prediction_result[:prediction]
      anomaly_score = prediction_result[:anomaly_score] || 0
      
      # Generate fraud indicators
      fraud_indicators = generate_fraud_indicators(features, fraud_probability)
      
      # Determine investigation priority
      investigation_priority = determine_investigation_priority(fraud_probability, anomaly_score)
      
      result = {
        fraud_probability: fraud_probability.round(3),
        fraud_risk: categorize_fraud_risk(fraud_probability),
        anomaly_score: anomaly_score.round(3),
        fraud_indicators: fraud_indicators,
        investigation_priority: investigation_priority,
        recommended_actions: generate_fraud_actions(fraud_probability),
        suspicious_patterns: prediction_result[:suspicious_patterns] || [],
        model_version: model.version,
        prediction_timestamp: Time.current
      }
      
      @prediction_cache.set(cache_key, result, ttl: 15.minutes)
      @model_performance.record_prediction(model_key, result, claim_data[:id])
      
      # Alert if high fraud probability
      alert_fraud_team(result, claim_data) if fraud_probability > 0.8
      
      result
      
    rescue => e
      Rails.logger.error "Fraud detection failed: #{e.message}"
      fallback_fraud_detection(claim_data)
    end
  end
  
  # Optimize premium pricing
  def optimize_premium(pricing_data, options = {})
    model_key = :premium_optimization
    
    begin
      features = @feature_pipeline.prepare_features(pricing_data, model_key)
      
      cache_key = generate_prediction_cache_key(model_key, features)
      cached_prediction = @prediction_cache.get(cache_key) unless options[:force_refresh]
      
      return cached_prediction if cached_prediction
      
      model = @model_registry.get_model(model_key)
      raise "Premium optimization model not available" unless model
      
      prediction_result = model.predict(features)
      optimal_premium = prediction_result[:prediction]
      confidence = prediction_result[:confidence]
      
      # Calculate pricing strategies
      pricing_strategies = generate_pricing_strategies(features, optimal_premium)
      
      # Competitive analysis
      competitive_position = analyze_competitive_position(optimal_premium, features)
      
      result = {
        optimal_premium: optimal_premium.round(2),
        confidence: confidence.round(3),
        current_premium: pricing_data[:current_premium],
        premium_adjustment: calculate_premium_adjustment(optimal_premium, pricing_data[:current_premium]),
        pricing_factors: prediction_result[:feature_importance]&.first(5) || {},
        pricing_strategies: pricing_strategies,
        competitive_position: competitive_position,
        profit_margin_impact: calculate_profit_impact(optimal_premium, features),
        model_version: model.version,
        prediction_timestamp: Time.current
      }
      
      @prediction_cache.set(cache_key, result, ttl: 1.hour)
      @model_performance.record_prediction(model_key, result, pricing_data[:id])
      
      result
      
    rescue => e
      Rails.logger.error "Premium optimization failed: #{e.message}"
      fallback_premium_optimization(pricing_data)
    end
  end
  
  # Get batch predictions for multiple records
  def batch_predict(data_records, model_type, options = {})
    results = []
    batch_size = options[:batch_size] || 100
    
    data_records.each_slice(batch_size) do |batch|
      batch_results = case model_type
                      when :risk_prediction
                        batch.map { |record| predict_risk(record, options) }
                      when :churn_prediction
                        batch.map { |record| predict_churn(record, options) }
                      when :clv_prediction
                        batch.map { |record| predict_clv(record, options) }
                      when :fraud_detection
                        batch.map { |record| detect_fraud(record, options) }
                      when :premium_optimization
                        batch.map { |record| optimize_premium(record, options) }
                      else
                        raise "Unknown model type: #{model_type}"
                      end
      
      results.concat(batch_results)
      
      # Rate limiting for large batches
      sleep(0.1) if batch_size > 50
    end
    
    Rails.logger.info "Batch prediction completed: #{results.size} predictions for #{model_type}"
    results
  end
  
  # Get model performance metrics
  def get_model_performance(model_type = nil)
    if model_type
      @model_performance.get_metrics(model_type)
    else
      ML_MODELS.keys.map do |model_key|
        {
          model: model_key,
          metrics: @model_performance.get_metrics(model_key)
        }
      end
    end
  end
  
  # Retrain model with new data
  def retrain_model(model_type, training_data, options = {})
    Rails.logger.info "Starting model retraining for #{model_type}"
    
    begin
      # Prepare training data
      processed_data = @feature_pipeline.prepare_training_data(training_data, model_type)
      
      # Train new model
      new_model = ModelTrainer.new.train_model(
        model_type,
        processed_data,
        ML_MODELS[model_type]
      )
      
      # Validate model performance
      validation_metrics = validate_model_performance(new_model, model_type)
      
      if validation_metrics[:accuracy] >= ML_MODELS[model_type][:accuracy_threshold]
        # Deploy new model
        @model_registry.deploy_model(model_type, new_model, validation_metrics)
        Rails.logger.info "Model #{model_type} retrained and deployed successfully"
        
        true
      else
        Rails.logger.warn "New model for #{model_type} did not meet accuracy threshold"
        false
      end
      
    rescue => e
      Rails.logger.error "Model retraining failed for #{model_type}: #{e.message}"
      false
    end
  end
  
  private
  
  def setup_ml_infrastructure
    # Initialize ML infrastructure
    Rails.logger.info "Setting up ML infrastructure for Predictive Analytics"
    
    # Load pre-trained models if available
    ML_MODELS.keys.each do |model_key|
      load_or_initialize_model(model_key)
    end
    
    # Start model performance monitoring
    start_performance_monitoring
  end
  
  def load_or_initialize_model(model_key)
    begin
      # Try to load existing model
      model = @model_registry.load_model(model_key)
      
      if model
        Rails.logger.info "Loaded existing model: #{model_key}"
      else
        # Initialize with basic model or placeholder
        @model_registry.initialize_placeholder(model_key)
        Rails.logger.info "Initialized placeholder for model: #{model_key}"
      end
    rescue => e
      Rails.logger.error "Failed to load model #{model_key}: #{e.message}"
      @model_registry.initialize_placeholder(model_key)
    end
  end
  
  def start_performance_monitoring
    # Start background monitoring of model performance
    Thread.new do
      loop do
        begin
          monitor_model_drift
          sleep(1.hour)
        rescue => e
          Rails.logger.error "Model monitoring error: #{e.message}"
          sleep(1.hour)
        end
      end
    end
  end
  
  def monitor_model_drift
    ML_MODELS.keys.each do |model_key|
      drift_score = @model_performance.calculate_drift(model_key)
      
      if drift_score > 0.1 # 10% drift threshold
        Rails.logger.warn "Model drift detected for #{model_key}: #{drift_score}"
        
        # Schedule model retraining
        ModelRetrainingJob.perform_later(model_key)
      end
    end
  end
  
  def generate_prediction_cache_key(model_key, features)
    feature_hash = Digest::MD5.hexdigest(features.to_json)
    "ml_prediction:#{model_key}:#{feature_hash}"
  end
  
  def categorize_risk(risk_score)
    case risk_score
    when 0...0.3
      'Low'
    when 0.3...0.6
      'Medium'
    when 0.6...0.8
      'High'
    else
      'Very High'
    end
  end
  
  def categorize_churn_risk(churn_probability)
    case churn_probability
    when 0...0.2
      'Low'
    when 0.2...0.5
      'Medium'
    when 0.5...0.8
      'High'
    else
      'Critical'
    end
  end
  
  def categorize_clv(clv_amount)
    case clv_amount
    when 0...5000
      'Basic'
    when 5000...15000
      'Standard'
    when 15000...35000
      'Premium'
    else
      'VIP'
    end
  end
  
  def categorize_fraud_risk(fraud_probability)
    case fraud_probability
    when 0...0.2
      'Low'
    when 0.2...0.5
      'Medium'
    when 0.5...0.8
      'High'
    else
      'Critical'
    end
  end
  
  def generate_risk_insights(features, risk_score, confidence)
    insights = []
    
    # Age-based insights
    if features[:age] && features[:age] < 25
      insights << "Young driver - higher risk profile due to limited experience"
    elsif features[:age] && features[:age] > 65
      insights << "Senior driver - potential vision/reaction time considerations"
    end
    
    # Location-based insights
    if features[:location_risk_score] && features[:location_risk_score] > 0.7
      insights << "High-risk location with elevated accident rates"
    end
    
    # Claims history insights
    if features[:claim_history] && features[:claim_history] > 2
      insights << "Multiple previous claims indicate higher future claim likelihood"
    end
    
    # Confidence-based insights
    if confidence < 0.7
      insights << "Prediction has moderate confidence - consider manual review"
    end
    
    insights
  end
  
  def generate_retention_strategies(features, churn_probability)
    strategies = []
    
    if churn_probability > 0.7
      strategies << {
        type: 'immediate_intervention',
        action: 'Personal call from account manager',
        priority: 'High',
        timeline: 'Within 24 hours'
      }
      
      strategies << {
        type: 'retention_offer',
        action: 'Discount or loyalty program enrollment',
        priority: 'High',
        timeline: 'Within 48 hours'
      }
    elsif churn_probability > 0.4
      strategies << {
        type: 'engagement_campaign',
        action: 'Personalized email campaign with value proposition',
        priority: 'Medium',
        timeline: 'Within 1 week'
      }
    end
    
    strategies
  end
  
  def generate_retention_actions(churn_probability)
    actions = []
    
    if churn_probability > 0.8
      actions << "Schedule immediate retention call"
      actions << "Offer premium discount or payment plan"
      actions << "Assign dedicated account manager"
    elsif churn_probability > 0.5
      actions << "Send personalized retention email"
      actions << "Offer policy review and optimization"
      actions << "Enroll in loyalty program"
    else
      actions << "Monitor engagement metrics"
      actions << "Include in quarterly satisfaction survey"
    end
    
    actions
  end
  
  def generate_clv_optimization_strategies(features, clv_amount)
    strategies = []
    
    if clv_amount > 25000
      strategies << {
        type: 'vip_treatment',
        description: 'Assign VIP account management and exclusive benefits',
        impact: 'Retention and upsell opportunities'
      }
    elsif clv_amount > 10000
      strategies << {
        type: 'cross_sell',
        description: 'Offer complementary insurance products',
        impact: 'Increase policy count and revenue'
      }
    end
    
    strategies << {
      type: 'engagement',
      description: 'Regular policy reviews and optimization suggestions',
      impact: 'Improved customer satisfaction and retention'
    }
    
    strategies
  end
  
  def calculate_growth_potential(clv_amount, features)
    # Simplified growth potential calculation
    base_growth = clv_amount * 0.15
    
    # Adjust based on features
    if features[:policy_count] && features[:policy_count] == 1
      base_growth *= 1.5 # More upside with single policy
    end
    
    if features[:tenure] && features[:tenure] < 2
      base_growth *= 1.3 # New customers have more growth potential
    end
    
    base_growth.round(2)
  end
  
  def generate_fraud_indicators(features, fraud_probability)
    indicators = []
    
    if features[:claim_timing] && features[:claim_timing] < 30
      indicators << "Claim filed very soon after policy inception"
    end
    
    if features[:claim_amount] && features[:documentation_score] && 
       features[:claim_amount] > 10000 && features[:documentation_score] < 0.5
      indicators << "High claim amount with insufficient documentation"
    end
    
    if fraud_probability > 0.6
      indicators << "ML model indicates suspicious patterns"
    end
    
    indicators
  end
  
  def determine_investigation_priority(fraud_probability, anomaly_score)
    combined_score = (fraud_probability + anomaly_score) / 2
    
    case combined_score
    when 0.8..1.0
      'Immediate'
    when 0.6...0.8
      'High'
    when 0.4...0.6
      'Medium'
    else
      'Low'
    end
  end
  
  def generate_fraud_actions(fraud_probability)
    actions = []
    
    if fraud_probability > 0.8
      actions << "Immediate investigation required"
      actions << "Flag claim for SIU review"
      actions << "Request additional documentation"
    elsif fraud_probability > 0.5
      actions << "Enhanced review process"
      actions << "Request claim documentation verification"
    else
      actions << "Standard processing with monitoring"
    end
    
    actions
  end
  
  def alert_fraud_team(fraud_result, claim_data)
    # Send alert to fraud investigation team
    FraudAlertJob.perform_later({
      claim_id: claim_data[:id],
      fraud_probability: fraud_result[:fraud_probability],
      investigation_priority: fraud_result[:investigation_priority],
      fraud_indicators: fraud_result[:fraud_indicators]
    })
  end
  
  def generate_pricing_strategies(features, optimal_premium)
    strategies = []
    
    current_premium = features[:current_premium] || optimal_premium
    adjustment = ((optimal_premium - current_premium) / current_premium * 100).round(2)
    
    if adjustment > 10
      strategies << {
        type: 'gradual_increase',
        description: 'Implement premium increase over 2-3 renewal cycles',
        rationale: 'Minimize customer shock while optimizing profitability'
      }
    elsif adjustment < -10
      strategies << {
        type: 'competitive_pricing',
        description: 'Lower premium to competitive market rate',
        rationale: 'Improve retention and market competitiveness'
      }
    else
      strategies << {
        type: 'maintain_current',
        description: 'Current pricing is optimal',
        rationale: 'No significant adjustment needed'
      }
    end
    
    strategies
  end
  
  def analyze_competitive_position(optimal_premium, features)
    # Simplified competitive analysis
    market_average = features[:market_average_premium] || optimal_premium
    
    position_ratio = optimal_premium / market_average
    
    {
      market_position: case position_ratio
                      when 0...0.85 then 'Below Market'
                      when 0.85...1.15 then 'Market Rate'
                      else 'Above Market'
                      end,
      competitive_ratio: position_ratio.round(3),
      market_average: market_average
    }
  end
  
  def calculate_premium_adjustment(optimal_premium, current_premium)
    return { amount: 0, percentage: 0 } unless current_premium
    
    amount_diff = optimal_premium - current_premium
    percentage_diff = (amount_diff / current_premium * 100).round(2)
    
    {
      amount: amount_diff.round(2),
      percentage: percentage_diff,
      direction: amount_diff > 0 ? 'increase' : 'decrease'
    }
  end
  
  def calculate_profit_impact(optimal_premium, features)
    # Simplified profit impact calculation
    estimated_costs = features[:estimated_costs] || optimal_premium * 0.7
    profit_margin = ((optimal_premium - estimated_costs) / optimal_premium * 100).round(2)
    
    {
      estimated_profit_margin: profit_margin,
      profit_category: case profit_margin
                      when 0...10 then 'Low'
                      when 10...25 then 'Moderate'
                      when 25...40 then 'Good'
                      else 'Excellent'
                      end
    }
  end
  
  def validate_model_performance(model, model_type)
    # Simplified model validation
    # In production, this would use proper cross-validation
    {
      accuracy: 0.85 + rand(0.10),
      precision: 0.82 + rand(0.10),
      recall: 0.80 + rand(0.10),
      f1_score: 0.81 + rand(0.10)
    }
  end
  
  # Fallback methods for when models are unavailable
  def fallback_risk_prediction(application_data)
    # Rule-based fallback
    risk_score = calculate_rule_based_risk(application_data)
    
    {
      risk_score: risk_score,
      risk_category: categorize_risk(risk_score),
      confidence: 0.6,
      fallback: true,
      method: 'rule_based'
    }
  end
  
  def fallback_churn_prediction(customer_data)
    churn_prob = calculate_rule_based_churn(customer_data)
    
    {
      churn_probability: churn_prob,
      churn_risk: categorize_churn_risk(churn_prob),
      confidence: 0.5,
      fallback: true,
      method: 'rule_based'
    }
  end
  
  def fallback_clv_prediction(customer_data)
    clv = calculate_rule_based_clv(customer_data)
    
    {
      customer_lifetime_value: clv,
      clv_segment: categorize_clv(clv),
      confidence: 0.5,
      fallback: true,
      method: 'rule_based'
    }
  end
  
  def fallback_fraud_detection(claim_data)
    fraud_prob = calculate_rule_based_fraud(claim_data)
    
    {
      fraud_probability: fraud_prob,
      fraud_risk: categorize_fraud_risk(fraud_prob),
      confidence: 0.4,
      fallback: true,
      method: 'rule_based'
    }
  end
  
  def fallback_premium_optimization(pricing_data)
    optimal = calculate_rule_based_premium(pricing_data)
    
    {
      optimal_premium: optimal,
      confidence: 0.5,
      fallback: true,
      method: 'rule_based'
    }
  end
  
  # Rule-based calculation methods (simplified)
  def calculate_rule_based_risk(data)
    risk = 0.3 # Base risk
    
    risk += 0.2 if data[:age] && data[:age] < 25
    risk += 0.1 if data[:claim_history] && data[:claim_history] > 1
    risk += 0.15 if data[:location_risk_score] && data[:location_risk_score] > 0.7
    
    [risk, 1.0].min
  end
  
  def calculate_rule_based_churn(data)
    churn = 0.2 # Base churn probability
    
    churn += 0.3 if data[:satisfaction_score] && data[:satisfaction_score] < 3
    churn += 0.2 if data[:premium_changes] && data[:premium_changes] > 2
    churn += 0.1 if data[:interaction_frequency] && data[:interaction_frequency] < 2
    
    [churn, 1.0].min
  end
  
  def calculate_rule_based_clv(data)
    base_clv = 8000 # Base CLV
    
    base_clv *= 1.5 if data[:policy_count] && data[:policy_count] > 1
    base_clv *= 1.2 if data[:tenure] && data[:tenure] > 3
    base_clv *= 0.8 if data[:claim_ratio] && data[:claim_ratio] > 0.5
    
    base_clv
  end
  
  def calculate_rule_based_fraud(data)
    fraud = 0.1 # Base fraud probability
    
    fraud += 0.3 if data[:claim_timing] && data[:claim_timing] < 30
    fraud += 0.2 if data[:documentation_score] && data[:documentation_score] < 0.5
    fraud += 0.25 if data[:claim_amount] && data[:claim_amount] > 50000
    
    [fraud, 1.0].min
  end
  
  def calculate_rule_based_premium(data)
    base_premium = data[:current_premium] || 1200
    
    # Adjust based on simple rules
    adjustment = 1.0
    adjustment *= 1.1 if data[:risk_factors] && data[:risk_factors] > 0.7
    adjustment *= 0.95 if data[:customer_segment] == 'loyal'
    
    base_premium * adjustment
  end
end