class ApplicationApprovalWorkflow
  include AASM
  
  def initialize(application)
    @application = application
  end
  
  aasm column: :status do
    state :draft, initial: true
    state :submitted
    state :under_review
    state :pending_approval
    state :approved
    state :rejected
    state :returned_for_revision
    
    event :submit do
      transitions from: [:draft, :returned_for_revision], to: :submitted,
                 guard: :can_submit?,
                 after: :after_submit
    end
    
    event :start_review do
      transitions from: :submitted, to: :under_review,
                 after: :after_start_review
    end
    
    event :request_approval do
      transitions from: :under_review, to: :pending_approval,
                 guard: :review_completed?,
                 after: :after_request_approval
    end
    
    event :approve do
      transitions from: [:under_review, :pending_approval], to: :approved,
                 guard: :can_approve?,
                 after: :after_approve
    end
    
    event :reject do
      transitions from: [:under_review, :pending_approval], to: :rejected,
                 after: :after_reject
    end
    
    event :return_for_revision do
      transitions from: [:under_review, :pending_approval], to: :returned_for_revision,
                 after: :after_return_for_revision
    end
  end
  
  def can_submit?
    @application.valid_for_submission? && required_documents_uploaded?
  end
  
  def review_completed?
    @application.reviewed_by.present? && @application.reviewed_at.present?
  end
  
  def can_approve?
    case @application.sum_insured&.to_f
    when 0..50_000
      Current.user.can?(:approve_small_applications)
    when 50_001..500_000
      Current.user.can?(:approve_medium_applications)
    when 500_001..Float::INFINITY
      Current.user.can?(:approve_large_applications)
    else
      false
    end
  end
  
  def required_documents_uploaded?
    required_docs = @application.required_documents_for_type
    uploaded_docs = @application.documents.pluck(:name)
    
    required_docs.all? { |doc| uploaded_docs.include?(doc) }
  end
  
  def approval_required?
    case @application.insurance_type
    when 'motor'
      @application.sum_insured.to_f > 100_000
    when 'fire'
      @application.sum_insured.to_f > 250_000
    when 'liability'
      @application.sum_insured.to_f > 500_000
    when 'general_accident'
      @application.sum_insured.to_f > 50_000
    when 'bonds'
      @application.sum_insured.to_f > 1_000_000
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
    return false unless @application.sum_insured.present?
    return false if @application.high_risk?
    return false unless all_validations_passed?
    
    # Auto-approve based on sum insured thresholds
    case @application.insurance_type
    when 'motor'
      @application.sum_insured.to_f <= 50_000
    when 'fire'
      @application.sum_insured.to_f <= 100_000
    when 'liability'
      @application.sum_insured.to_f <= 250_000
    when 'general_accident'
      @application.sum_insured.to_f <= 25_000
    when 'bonds'
      @application.sum_insured.to_f <= 500_000
    else
      false
    end
  end
  
  def high_risk?
    @application.risk_level == 'high'
  end
  
  def all_validations_passed?
    @application.valid? && 
    required_documents_uploaded? && 
    client_kyc_completed? &&
    fraud_check_passed?
  end
  
  def client_kyc_completed?
    @application.client.kyc_verified?
  end
  
  def fraud_check_passed?
    # Implement fraud detection logic
    # For now, return true - would integrate with fraud detection service
    true
  end
  
  private
  
  def after_submit
    @application.update!(
      submitted_at: Time.current,
      distributed_at: nil # Reset distribution status
    )
    
    # Trigger distribution if auto-approved or sent for review
    if auto_approve_if_eligible
      ApplicationDistributionService.new(@application).distribute!
    else
      # Send for manual review
      assign_reviewer
      send_review_notification
    end
    
    # Log workflow transition
    log_workflow_transition('submitted')
  end
  
  def after_start_review
    @application.update!(
      reviewed_at: Time.current,
      reviewed_by: Current.user
    )
    
    log_workflow_transition('under_review')
  end
  
  def after_request_approval
    assign_approver
    send_approval_notification
    log_workflow_transition('pending_approval')
  end
  
  def after_approve
    @application.update!(
      approved_at: Time.current,
      approved_by: Current.user
    )
    
    # Trigger distribution to insurance companies
    ApplicationDistributionService.new(@application).distribute!
    
    # Send approval notification to client
    ClientNotificationMailer.application_approved(@application).deliver_later
    
    log_workflow_transition('approved')
  end
  
  def after_reject
    @application.update!(
      rejected_at: Time.current,
      rejected_by: Current.user
    )
    
    # Send rejection notification to client
    ClientNotificationMailer.application_rejected(@application).deliver_later
    
    log_workflow_transition('rejected')
  end
  
  def after_return_for_revision
    # Send revision request to client
    ClientNotificationMailer.revision_required(@application).deliver_later
    
    log_workflow_transition('returned_for_revision')
  end
  
  def assign_reviewer
    # Assign based on insurance type and workload
    reviewer = User.reviewers
                  .for_insurance_type(@application.insurance_type)
                  .with_lowest_workload
                  .first
    
    @application.update!(assigned_reviewer: reviewer) if reviewer
  end
  
  def assign_approver
    # Assign based on approval authority
    approver = User.approvers
                  .with_approval_authority_for(@application.sum_insured)
                  .with_lowest_workload
                  .first
    
    @application.update!(assigned_approver: approver) if approver
  end
  
  def send_review_notification
    if @application.assigned_reviewer
      WorkflowNotificationMailer.review_required(@application).deliver_later
    end
  end
  
  def send_approval_notification
    if @application.assigned_approver
      WorkflowNotificationMailer.approval_required(@application).deliver_later
    end
  end
  
  def log_workflow_transition(new_status)
    WorkflowLog.create!(
      application: @application,
      user: Current.user,
      from_status: @application.status_was,
      to_status: new_status,
      timestamp: Time.current,
      notes: "Workflow transition via #{self.class.name}"
    )
  end
end