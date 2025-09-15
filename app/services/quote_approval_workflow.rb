class QuoteApprovalWorkflow
  include AASM
  
  def initialize(quote)
    @quote = quote
  end
  
  aasm column: :status do
    state :draft, initial: true
    state :submitted
    state :pending_review
    state :approved
    state :rejected
    state :expired
    state :accepted
    state :withdrawn
    
    event :submit do
      transitions from: :draft, to: :submitted,
                 guard: :can_submit?,
                 after: :after_submit
    end
    
    event :start_review do
      transitions from: :submitted, to: :pending_review,
                 after: :after_start_review
    end
    
    event :approve do
      transitions from: [:submitted, :pending_review], to: :approved,
                 guard: :can_approve?,
                 after: :after_approve
    end
    
    event :reject do
      transitions from: [:submitted, :pending_review], to: :rejected,
                 after: :after_reject
    end
    
    event :accept do
      transitions from: :approved, to: :accepted,
                 guard: :can_accept?,
                 after: :after_accept
    end
    
    event :expire do
      transitions from: [:submitted, :pending_review, :approved], to: :expired,
                 after: :after_expire
    end
    
    event :withdraw do
      transitions from: [:submitted, :pending_review, :approved], to: :withdrawn,
                 after: :after_withdraw
    end
  end
  
  def can_submit?
    @quote.valid? && all_required_fields_present?
  end
  
  def can_approve?
    case @quote.premium_amount.to_f
    when 0..10_000
      Current.user.can?(:approve_small_quotes)
    when 10_001..100_000
      Current.user.can?(:approve_medium_quotes)
    when 100_001..Float::INFINITY
      Current.user.can?(:approve_large_quotes)
    else
      false
    end
  end
  
  def can_accept?
    @quote.approved? && !@quote.expired? && client_can_accept?
  end
  
  def requires_approval?
    case @quote.insurance_application.insurance_type
    when 'motor'
      @quote.premium_amount.to_f > 50_000
    when 'fire'
      @quote.premium_amount.to_f > 100_000
    when 'liability'
      @quote.premium_amount.to_f > 200_000
    when 'general_accident'
      @quote.premium_amount.to_f > 25_000
    when 'bonds'
      @quote.premium_amount.to_f > 500_000
    else
      true
    end
  end
  
  def auto_approve_if_eligible
    if can_auto_approve?
      approve!
      true
    else
      false
    end
  end
  
  def can_auto_approve?
    return false unless @quote.premium_amount.present?
    return false if high_value_quote?
    return false unless standard_terms?
    
    # Auto-approve based on premium amount thresholds
    case @quote.insurance_application.insurance_type
    when 'motor'
      @quote.premium_amount.to_f <= 25_000
    when 'fire'
      @quote.premium_amount.to_f <= 50_000
    when 'liability'
      @quote.premium_amount.to_f <= 100_000
    when 'general_accident'
      @quote.premium_amount.to_f <= 15_000
    when 'bonds'
      @quote.premium_amount.to_f <= 250_000
    else
      false
    end
  end
  
  def high_value_quote?
    @quote.premium_amount.to_f > 100_000
  end
  
  def standard_terms?
    # Check if quote uses standard terms and conditions
    @quote.terms_and_conditions.blank? || 
    @quote.terms_and_conditions == 'standard'
  end
  
  def client_can_accept?
    @quote.insurance_application.client.present? && 
    !@quote.insurance_application.has_accepted_quote?
  end
  
  def all_required_fields_present?
    required_fields = %w[premium_amount coverage_amount validity_period]
    required_fields.all? { |field| @quote.send(field).present? }
  end
  
  def send_for_review
    if requires_approval?
      start_review! if submitted?
    else
      auto_approve_if_eligible
    end
  end
  
  private
  
  def after_submit
    @quote.update!(
      quoted_at: Time.current,
      expires_at: Time.current + @quote.validity_period.days
    )
    
    # Mark corresponding application distribution as quoted
    distribution = @quote.insurance_application
                        .application_distributions
                        .find_by(insurance_company: @quote.insurance_company)
    distribution&.mark_as_quoted!
    
    # Auto-approve if eligible, otherwise send for review
    unless auto_approve_if_eligible
      send_for_review if requires_approval?
    end
    
    # Notify broker about new quote
    BrokerNotificationMailer.new_quote_submitted(@quote).deliver_later
    
    log_workflow_transition('submitted')
  end
  
  def after_start_review
    assign_reviewer
    send_review_notification
    log_workflow_transition('pending_review')
  end
  
  def after_approve
    @quote.update!(approved_by: Current.user, approved_at: Time.current)
    
    # Notify client about approved quote
    ClientNotificationMailer.quote_approved(@quote).deliver_later
    
    # Notify insurance company
    InsuranceCompanyMailer.quote_status_update(@quote).deliver_later
    
    log_workflow_transition('approved')
  end
  
  def after_reject
    @quote.update!(rejected_by: Current.user, rejected_at: Time.current)
    
    # Notify insurance company about rejection
    InsuranceCompanyMailer.quote_status_update(@quote).deliver_later
    
    log_workflow_transition('rejected')
  end
  
  def after_accept
    @quote.update!(accepted_at: Time.current, accepted_by: @quote.insurance_application.client)
    
    # Reject all other quotes for this application
    @quote.insurance_application.quotes
          .where.not(id: @quote.id)
          .where(status: ['approved', 'pending_review'])
          .find_each(&:reject!)
    
    # Update application status
    @quote.insurance_application.update!(status: 'policy_issued')
    
    # Notify all parties
    ClientNotificationMailer.quote_accepted(@quote).deliver_later
    InsuranceCompanyMailer.quote_status_update(@quote).deliver_later
    BrokerNotificationMailer.quote_accepted(@quote).deliver_later
    
    # Generate policy documents
    PolicyGenerationJob.perform_later(@quote.id)
    
    log_workflow_transition('accepted')
  end
  
  def after_expire
    @quote.update!(expired_at: Time.current)
    
    # Notify insurance company
    InsuranceCompanyMailer.quote_status_update(@quote).deliver_later
    
    log_workflow_transition('expired')
  end
  
  def after_withdraw
    @quote.update!(withdrawn_at: Time.current, withdrawn_by: Current.user)
    
    # Notify client if quote was previously approved
    if @quote.approved?
      ClientNotificationMailer.quote_withdrawn(@quote).deliver_later
    end
    
    log_workflow_transition('withdrawn')
  end
  
  def assign_reviewer
    # Assign reviewer based on quote value and insurance type
    reviewer = User.quote_reviewers
                  .for_insurance_type(@quote.insurance_application.insurance_type)
                  .with_authority_for_amount(@quote.premium_amount)
                  .with_lowest_workload
                  .first
    
    @quote.update!(assigned_reviewer: reviewer) if reviewer
  end
  
  def send_review_notification
    if @quote.assigned_reviewer
      WorkflowNotificationMailer.quote_review_required(@quote).deliver_later
    end
  end
  
  def log_workflow_transition(new_status)
    WorkflowLog.create!(
      quote: @quote,
      user: Current.user,
      from_status: @quote.status_was,
      to_status: new_status,
      timestamp: Time.current,
      notes: "Workflow transition via #{self.class.name}"
    )
  end
end