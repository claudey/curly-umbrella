class ChatbotEngine
  include Singleton

  # Intent categories and patterns
  INTENT_PATTERNS = {
    greeting: {
      patterns: [ "hello", "hi", "hey", "good morning", "good afternoon", "good evening" ],
      confidence_threshold: 0.8,
      category: :conversational
    },
    policy_inquiry: {
      patterns: [ "policy", "coverage", "premium", "deductible", "what does my policy cover" ],
      confidence_threshold: 0.85,
      category: :insurance_specific
    },
    claim_filing: {
      patterns: [ "file claim", "report claim", "claim process", "accident", "damage", "loss" ],
      confidence_threshold: 0.90,
      category: :claims_related
    },
    quote_request: {
      patterns: [ "quote", "price", "cost", "how much", "get quote", "estimate" ],
      confidence_threshold: 0.85,
      category: :sales_related
    },
    account_management: {
      patterns: [ "account", "login", "password", "profile", "update information", "change address" ],
      confidence_threshold: 0.80,
      category: :account_related
    },
    payment_inquiry: {
      patterns: [ "payment", "bill", "due date", "pay premium", "billing", "invoice" ],
      confidence_threshold: 0.85,
      category: :billing_related
    },
    support_request: {
      patterns: [ "help", "support", "problem", "issue", "trouble", "assistance" ],
      confidence_threshold: 0.75,
      category: :support_related
    },
    appointment_scheduling: {
      patterns: [ "appointment", "schedule", "meeting", "call me", "speak to agent" ],
      confidence_threshold: 0.80,
      category: :scheduling_related
    }
  }.freeze

  # Entity types for extraction
  ENTITY_TYPES = {
    policy_number: {
      pattern: /(?:policy|pol)?\s*#?\s*([A-Z]{2,4}\d{6,12})/i,
      validation: :validate_policy_number
    },
    claim_number: {
      pattern: /(?:claim|clm)?\s*#?\s*([A-Z]{2,4}\d{6,12})/i,
      validation: :validate_claim_number
    },
    phone_number: {
      pattern: /(\+?1?[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})/,
      validation: :validate_phone_number
    },
    email: {
      pattern: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/,
      validation: :validate_email
    },
    date: {
      pattern: /\b(?:\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4}|\d{4}[-\/]\d{1,2}[-\/]\d{1,2})\b/,
      validation: :validate_date
    },
    amount: {
      pattern: /\$?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)/,
      validation: :validate_amount
    }
  }.freeze

  # Response templates
  RESPONSE_TEMPLATES = {
    greeting: {
      responses: [
        "Hello! I'm your BrokerSync assistant. How can I help you today?",
        "Hi there! Welcome to BrokerSync. What can I assist you with?",
        "Good day! I'm here to help with your insurance needs. What would you like to know?"
      ],
      follow_up_actions: [ :show_quick_actions ]
    },
    policy_inquiry: {
      responses: [
        "I'd be happy to help you with your policy information. Could you please provide your policy number?",
        "Let me assist you with your policy details. What specific information are you looking for?"
      ],
      required_entities: [ :policy_number ],
      follow_up_actions: [ :retrieve_policy_info ]
    },
    claim_filing: {
      responses: [
        "I can help you start a claim. Let me guide you through the process. What type of incident are you reporting?",
        "I'm sorry to hear about your loss. I'll help you file a claim right away. Can you tell me what happened?"
      ],
      follow_up_actions: [ :start_claim_process, :collect_incident_details ]
    },
    quote_request: {
      responses: [
        "I'd be happy to help you get a quote! What type of insurance are you interested in?",
        "Let's get you a personalized quote. What coverage are you looking for?"
      ],
      follow_up_actions: [ :start_quote_process, :collect_quote_requirements ]
    },
    escalation_needed: {
      responses: [
        "I understand this requires special attention. Let me connect you with one of our specialists.",
        "For this type of request, I'll transfer you to a human agent who can better assist you."
      ],
      follow_up_actions: [ :escalate_to_human, :schedule_callback ]
    }
  }.freeze

  def initialize
    @conversation_memory = {}
    @analytics_engine = PredictiveAnalyticsEngine.instance
    @user_context_manager = UserContextManager.new
  end

  # Analyze user intent from message
  def analyze_intent(message, user_context = {})
    begin
      # Normalize message
      normalized_message = normalize_message(message)

      # Calculate intent scores
      intent_scores = {}

      INTENT_PATTERNS.each do |intent, config|
        score = calculate_intent_score(normalized_message, config[:patterns])
        intent_scores[intent] = score if score >= config[:confidence_threshold]
      end

      # Determine primary intent
      primary_intent = intent_scores.max_by { |_, score| score }

      # Consider conversation context
      context_adjusted_intent = adjust_intent_with_context(
        primary_intent,
        intent_scores,
        user_context
      )

      {
        intent: context_adjusted_intent ? context_adjusted_intent[0] : :unknown,
        confidence: context_adjusted_intent ? context_adjusted_intent[1] : 0.0,
        all_intents: intent_scores,
        category: primary_intent ? INTENT_PATTERNS[primary_intent[0]][:category] : :unknown,
        requires_clarification: intent_scores.empty? || context_adjusted_intent[1] < 0.7
      }

    rescue => e
      Rails.logger.error "Intent analysis failed: #{e.message}"
      {
        intent: :unknown,
        confidence: 0.0,
        error: true,
        requires_human_assistance: true
      }
    end
  end

  # Extract entities from message
  def extract_entities(message, intent_analysis = {})
    entities = {}

    ENTITY_TYPES.each do |entity_type, config|
      matches = message.scan(config[:pattern])

      if matches.any?
        # Validate extracted entities
        validated_entities = matches.map do |match|
          entity_value = match.is_a?(Array) ? match.join : match
          validation_result = send(config[:validation], entity_value) if config[:validation]

          {
            value: entity_value,
            valid: validation_result != false,
            confidence: calculate_entity_confidence(entity_value, entity_type)
          }
        end

        entities[entity_type] = validated_entities.select { |e| e[:valid] }
      end
    end

    # Extract intent-specific entities
    intent_specific_entities = extract_intent_specific_entities(message, intent_analysis)
    entities.merge!(intent_specific_entities)

    entities
  end

  # Analyze conversation context
  def analyze_context(user_context, intent_analysis, entities)
    user_id = user_context[:user_id]

    # Get conversation history
    conversation_history = get_conversation_history(user_id)

    # Analyze user profile context
    user_profile_context = @user_context_manager.get_user_profile_context(user_id)

    # Determine conversation state
    conversation_state = determine_conversation_state(
      conversation_history,
      intent_analysis,
      entities
    )

    # Check for ongoing processes
    ongoing_processes = check_ongoing_processes(user_id, user_context)

    {
      conversation_state: conversation_state,
      user_profile: user_profile_context,
      conversation_history: conversation_history.last(5), # Last 5 interactions
      ongoing_processes: ongoing_processes,
      context_score: calculate_context_score(conversation_history, intent_analysis),
      requires_authentication: requires_user_authentication?(intent_analysis, entities)
    }
  end

  # Generate appropriate response
  def generate_response(intent_analysis, entities, context_analysis, user_context = {})
    intent = intent_analysis[:intent]

    begin
      # Check if user needs authentication for this intent
      if context_analysis[:requires_authentication] && !user_authenticated?(user_context)
        return generate_authentication_required_response(intent_analysis)
      end

      # Generate intent-specific response
      response = case intent
      when :greeting
                   generate_greeting_response(user_context)
      when :policy_inquiry
                   generate_policy_inquiry_response(entities, user_context)
      when :claim_filing
                   generate_claim_filing_response(entities, context_analysis, user_context)
      when :quote_request
                   generate_quote_request_response(entities, user_context)
      when :account_management
                   generate_account_management_response(entities, user_context)
      when :payment_inquiry
                   generate_payment_inquiry_response(entities, user_context)
      when :support_request
                   generate_support_response(entities, context_analysis, user_context)
      when :appointment_scheduling
                   generate_appointment_response(entities, user_context)
      else
                   generate_fallback_response(intent_analysis, context_analysis)
      end

      # Add personalization
      response = personalize_response(response, user_context, context_analysis)

      # Store conversation for context
      store_conversation_turn(user_context[:user_id], intent_analysis, entities, response)

      response

    rescue => e
      Rails.logger.error "Response generation failed: #{e.message}"
      generate_error_response
    end
  end

  # Execute actions based on chatbot response
  def execute_action(action, parameters, user_context)
    case action
    when :retrieve_policy_info
      retrieve_policy_information(parameters, user_context)
    when :start_claim_process
      initiate_claim_process(parameters, user_context)
    when :start_quote_process
      initiate_quote_process(parameters, user_context)
    when :schedule_callback
      schedule_callback_request(parameters, user_context)
    when :escalate_to_human
      escalate_to_human_agent(parameters, user_context)
    when :update_user_profile
      update_user_profile_information(parameters, user_context)
    when :send_documents
      send_document_links(parameters, user_context)
    else
      { success: false, error: "Unknown action: #{action}" }
    end
  end

  # Get chatbot analytics and performance metrics
  def get_chatbot_analytics(time_range = 30.days)
    {
      conversation_metrics: {
        total_conversations: get_total_conversations(time_range),
        average_conversation_length: get_average_conversation_length(time_range),
        resolution_rate: get_resolution_rate(time_range),
        escalation_rate: get_escalation_rate(time_range)
      },
      intent_analysis: {
        top_intents: get_top_intents(time_range),
        intent_accuracy: get_intent_accuracy(time_range),
        unrecognized_intents: get_unrecognized_intents(time_range)
      },
      user_satisfaction: {
        satisfaction_score: get_satisfaction_score(time_range),
        positive_feedback_rate: get_positive_feedback_rate(time_range),
        common_complaints: get_common_complaints(time_range)
      },
      performance_metrics: {
        average_response_time: get_average_response_time(time_range),
        successful_task_completion: get_task_completion_rate(time_range),
        automation_effectiveness: get_automation_effectiveness(time_range)
      }
    }
  end

  private

  def normalize_message(message)
    message.downcase.strip.gsub(/[^\w\s@.-]/, "")
  end

  def calculate_intent_score(message, patterns)
    pattern_matches = patterns.count { |pattern| message.include?(pattern.downcase) }
    total_words = message.split.size

    # Calculate score based on pattern matches and context
    base_score = (pattern_matches.to_f / patterns.size) * 100
    context_bonus = [ pattern_matches * 10, 30 ].min # Max 30% bonus

    [ base_score + context_bonus, 100 ].min
  end

  def adjust_intent_with_context(primary_intent, intent_scores, user_context)
    return primary_intent unless primary_intent

    # Consider user's recent activity context
    if user_context[:recent_activity]
      case user_context[:recent_activity]
      when "filed_claim"
        # Boost claim-related intents
        intent_scores[:claim_filing] = (intent_scores[:claim_filing] || 0) + 20
      when "requested_quote"
        # Boost quote-related intents
        intent_scores[:quote_request] = (intent_scores[:quote_request] || 0) + 20
      end
    end

    # Return highest scoring intent after context adjustment
    intent_scores.max_by { |_, score| score }
  end

  def calculate_entity_confidence(value, entity_type)
    # Simple confidence calculation based on entity type and value characteristics
    case entity_type
    when :policy_number, :claim_number
      value.length >= 8 ? 0.9 : 0.6
    when :phone_number
      value.gsub(/\D/, "").length == 10 ? 0.95 : 0.7
    when :email
      value.include?("@") && value.include?(".") ? 0.9 : 0.5
    else
      0.8
    end
  end

  def extract_intent_specific_entities(message, intent_analysis)
    intent = intent_analysis[:intent]
    entities = {}

    case intent
    when :claim_filing
      # Extract incident types
      incident_types = [ "accident", "theft", "fire", "flood", "vandalism" ]
      found_incidents = incident_types.select { |type| message.downcase.include?(type) }
      entities[:incident_type] = found_incidents.map { |type| { value: type, confidence: 0.8 } } if found_incidents.any?

    when :quote_request
      # Extract insurance types
      insurance_types = [ "auto", "home", "life", "health", "business" ]
      found_types = insurance_types.select { |type| message.downcase.include?(type) }
      entities[:insurance_type] = found_types.map { |type| { value: type, confidence: 0.85 } } if found_types.any?
    end

    entities
  end

  def get_conversation_history(user_id)
    @conversation_memory[user_id] || []
  end

  def determine_conversation_state(history, intent_analysis, entities)
    return :new_conversation if history.empty?

    last_interaction = history.last

    # Check if continuing a previous topic
    if last_interaction && similar_intent?(last_interaction[:intent], intent_analysis[:intent])
      :continuing_topic
    elsif entities.any? { |_, entity_list| entity_list.any? { |e| e[:confidence] > 0.8 } }
      :providing_information
    else
      :topic_change
    end
  end

  def similar_intent?(intent1, intent2)
    # Check if intents are in the same category
    category1 = INTENT_PATTERNS[intent1]&.dig(:category)
    category2 = INTENT_PATTERNS[intent2]&.dig(:category)

    category1 && category2 && category1 == category2
  end

  def check_ongoing_processes(user_id, user_context)
    # Check for ongoing applications, claims, etc.
    processes = []

    # Check for pending applications
    if user_context[:organization_id]
      pending_apps = InsuranceApplication.where(
        organization_id: user_context[:organization_id],
        status: [ "pending", "in_review" ]
      ).limit(3)

      processes.concat(pending_apps.map { |app| { type: :application, id: app.id, status: app.status } })
    end

    processes
  end

  def calculate_context_score(history, intent_analysis)
    # Calculate how well we understand the conversation context
    base_score = 0.5

    base_score += 0.2 if history.size > 2 # Established conversation
    base_score += 0.2 if intent_analysis[:confidence] > 0.8 # Clear intent
    base_score += 0.1 if history.any? { |h| h[:resolved] } # Previous successful resolution

    [ base_score, 1.0 ].min
  end

  def requires_user_authentication?(intent_analysis, entities)
    # Determine if intent requires authentication
    authenticated_intents = [ :policy_inquiry, :claim_filing, :account_management, :payment_inquiry ]

    authenticated_intents.include?(intent_analysis[:intent]) ||
      entities.key?(:policy_number) ||
      entities.key?(:claim_number)
  end

  def user_authenticated?(user_context)
    user_context[:authenticated] == true || user_context[:user_id].present?
  end

  def generate_greeting_response(user_context)
    template = RESPONSE_TEMPLATES[:greeting]
    base_response = template[:responses].sample

    # Personalize if user is known
    if user_context[:user_name]
      base_response = "Hello #{user_context[:user_name]}! " + base_response.split("!", 2).last
    end

    {
      message: base_response,
      actions: template[:follow_up_actions],
      suggested_actions: [
        { text: "Get a Quote", action: :start_quote_process },
        { text: "Policy Information", action: :policy_inquiry },
        { text: "File a Claim", action: :start_claim_process },
        { text: "Contact Support", action: :escalate_to_human }
      ],
      requires_input: false
    }
  end

  def generate_policy_inquiry_response(entities, user_context)
    if entities[:policy_number]&.any?
      policy_number = entities[:policy_number].first[:value]

      {
        message: "I found policy number #{policy_number}. Let me retrieve your policy information.",
        actions: [ :retrieve_policy_info ],
        parameters: { policy_number: policy_number },
        requires_input: false
      }
    else
      {
        message: "I'd be happy to help with your policy information. Could you please provide your policy number? It usually starts with 2-4 letters followed by numbers.",
        actions: [],
        requires_input: true,
        expected_input: :policy_number
      }
    end
  end

  def generate_claim_filing_response(entities, context_analysis, user_context)
    incident_type = entities[:incident_type]&.first&.dig(:value)

    if incident_type
      {
        message: "I'm sorry to hear about the #{incident_type}. I'll help you file a claim right away. Let me start the process for you.",
        actions: [ :start_claim_process ],
        parameters: { incident_type: incident_type },
        requires_input: false
      }
    else
      {
        message: "I can help you file a claim. To get started, could you tell me what type of incident you're reporting? (accident, theft, fire, etc.)",
        actions: [],
        requires_input: true,
        expected_input: :incident_type
      }
    end
  end

  def generate_quote_request_response(entities, user_context)
    insurance_type = entities[:insurance_type]&.first&.dig(:value)

    if insurance_type
      {
        message: "Great! I can help you get a #{insurance_type} insurance quote. Let me start the quote process for you.",
        actions: [ :start_quote_process ],
        parameters: { insurance_type: insurance_type },
        requires_input: false
      }
    else
      {
        message: "I'd be happy to help you get a quote! What type of insurance are you interested in? (auto, home, life, health, business)",
        actions: [],
        requires_input: true,
        expected_input: :insurance_type
      }
    end
  end

  def generate_account_management_response(entities, user_context)
    {
      message: "I can help you with your account. What would you like to update or manage?",
      actions: [],
      suggested_actions: [
        { text: "Update Address", action: :update_user_profile, parameters: { field: :address } },
        { text: "Change Password", action: :update_user_profile, parameters: { field: :password } },
        { text: "Update Phone", action: :update_user_profile, parameters: { field: :phone } },
        { text: "Download Documents", action: :send_documents }
      ],
      requires_input: true
    }
  end

  def generate_payment_inquiry_response(entities, user_context)
    {
      message: "I can help you with billing and payment information. Let me check your account status.",
      actions: [ :retrieve_payment_info ],
      parameters: { user_id: user_context[:user_id] },
      requires_input: false
    }
  end

  def generate_support_response(entities, context_analysis, user_context)
    if context_analysis[:context_score] < 0.6
      {
        message: "I'd be happy to help! Could you please provide more details about what you need assistance with?",
        actions: [],
        requires_input: true
      }
    else
      {
        message: "I understand you need support. Let me connect you with one of our specialists who can better assist you.",
        actions: [ :escalate_to_human ],
        escalation_needed: true,
        requires_input: false
      }
    end
  end

  def generate_appointment_response(entities, user_context)
    {
      message: "I can help you schedule an appointment with one of our agents. What type of consultation do you need?",
      actions: [ :schedule_callback ],
      suggested_actions: [
        { text: "Policy Review", action: :schedule_callback, parameters: { type: :policy_review } },
        { text: "Claims Consultation", action: :schedule_callback, parameters: { type: :claims_consultation } },
        { text: "General Inquiry", action: :schedule_callback, parameters: { type: :general } }
      ],
      requires_input: true
    }
  end

  def generate_fallback_response(intent_analysis, context_analysis)
    if intent_analysis[:requires_clarification]
      {
        message: "I'm not sure I understand. Could you please rephrase that or tell me more about what you need help with?",
        actions: [],
        suggested_actions: [
          { text: "Get a Quote", action: :start_quote_process },
          { text: "File a Claim", action: :start_claim_process },
          { text: "Speak to Agent", action: :escalate_to_human }
        ],
        requires_input: true
      }
    else
      {
        message: "I apologize, but I'm not able to help with that specific request. Let me connect you with a human agent who can better assist you.",
        actions: [ :escalate_to_human ],
        escalation_needed: true,
        requires_input: false
      }
    end
  end

  def generate_authentication_required_response(intent_analysis)
    {
      message: "For security purposes, I'll need to verify your identity before I can help with that. Please log in to your account or provide your policy number.",
      actions: [ :request_authentication ],
      requires_authentication: true,
      requires_input: true
    }
  end

  def generate_error_response
    {
      message: "I'm experiencing some technical difficulties right now. Please try again in a moment, or I can connect you with a human agent for immediate assistance.",
      actions: [ :escalate_to_human ],
      error: true,
      requires_input: false
    }
  end

  def personalize_response(response, user_context, context_analysis)
    # Add personalization based on user context
    if user_context[:user_name] && !response[:message].include?(user_context[:user_name])
      # Add personal touch occasionally
      if rand < 0.3 # 30% chance
        response[:message] = response[:message].gsub(/^(I|Let me)/, "#{user_context[:user_name]}, \\1")
      end
    end

    response
  end

  def store_conversation_turn(user_id, intent_analysis, entities, response)
    @conversation_memory[user_id] ||= []
    @conversation_memory[user_id] << {
      timestamp: Time.current,
      intent: intent_analysis[:intent],
      confidence: intent_analysis[:confidence],
      entities: entities,
      response: response[:message],
      resolved: !response[:requires_input],
      escalated: response[:escalation_needed] || false
    }

    # Keep only last 20 conversation turns
    @conversation_memory[user_id] = @conversation_memory[user_id].last(20)
  end

  # Action execution methods
  def retrieve_policy_information(parameters, user_context)
    policy_number = parameters[:policy_number]

    # Simulate policy lookup
    {
      success: true,
      policy_info: {
        policy_number: policy_number,
        status: "Active",
        coverage_type: "Auto Insurance",
        premium: "$156/month",
        next_payment: "2024-02-15"
      },
      message: "Here's your policy information for #{policy_number}"
    }
  end

  def initiate_claim_process(parameters, user_context)
    incident_type = parameters[:incident_type]

    claim_number = "CLM#{rand(100000..999999)}"

    {
      success: true,
      claim_number: claim_number,
      message: "I've started claim #{claim_number} for your #{incident_type}. You'll receive an email with next steps.",
      next_steps: [ "Upload photos", "Complete incident report", "Schedule adjuster visit" ]
    }
  end

  def initiate_quote_process(parameters, user_context)
    insurance_type = parameters[:insurance_type]

    {
      success: true,
      quote_id: "QTE#{rand(100000..999999)}",
      message: "I've started a #{insurance_type} insurance quote for you. Please provide some basic information to continue.",
      required_info: [ "Vehicle year/make/model", "Driving history", "Coverage preferences" ]
    }
  end

  def schedule_callback_request(parameters, user_context)
    appointment_type = parameters[:type] || "general"

    {
      success: true,
      appointment_id: "APT#{rand(100000..999999)}",
      message: "I've scheduled a #{appointment_type} consultation for you. You'll receive a confirmation email shortly.",
      estimated_callback: "Within 24 hours"
    }
  end

  def escalate_to_human_agent(parameters, user_context)
    {
      success: true,
      ticket_id: "TKT#{rand(100000..999999)}",
      message: "I'm connecting you with a human agent. Please hold while I transfer your conversation.",
      estimated_wait_time: "3-5 minutes"
    }
  end

  # Validation methods
  def validate_policy_number(value)
    value.length >= 8 && value.match?(/^[A-Z]{2,4}\d{6,12}$/i)
  end

  def validate_claim_number(value)
    value.length >= 8 && value.match?(/^[A-Z]{2,4}\d{6,12}$/i)
  end

  def validate_phone_number(value)
    value.gsub(/\D/, "").length == 10
  end

  def validate_email(value)
    value.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end

  def validate_date(value)
    Date.parse(value.to_s) rescue false
  end

  def validate_amount(value)
    value.to_f > 0
  end

  # Analytics methods (simplified implementations)
  def get_total_conversations(time_range)
    rand(1000..5000)
  end

  def get_average_conversation_length(time_range)
    rand(3..8) # Number of exchanges
  end

  def get_resolution_rate(time_range)
    rand(75..90) # Percentage
  end

  def get_escalation_rate(time_range)
    rand(10..25) # Percentage
  end

  def get_satisfaction_score(time_range)
    rand(4.0..4.8).round(1) # Out of 5.0
  end
end

# Supporting class for user context management
class UserContextManager
  def get_user_profile_context(user_id)
    return {} unless user_id

    user = User.find_by(id: user_id)
    return {} unless user

    {
      name: user.name,
      email: user.email,
      organization: user.organization&.name,
      role: user.role,
      last_login: user.last_sign_in_at,
      policy_count: user.organization&.insurance_applications&.count || 0
    }
  end
end
