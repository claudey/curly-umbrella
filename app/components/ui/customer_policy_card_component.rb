class Ui::CustomerPolicyCardComponent < ApplicationComponent
  renders_many :actions

  def initialize(
    policy:,
    show_actions: true,
    compact: false,
    highlight_expiring: true,
    class: nil,
    **options
  )
    @policy = policy
    @show_actions = show_actions
    @compact = compact
    @highlight_expiring = highlight_expiring
    @additional_classes = binding.local_variable_get(:class)
    @options = options
  end

  private

  attr_reader :policy, :show_actions, :compact, :highlight_expiring, :additional_classes, :options

  def card_classes
    classes = ["card", "bg-base-100", "border", "transition-all", "duration-300"]
    
    if compact
      classes << "card-compact"
    else
      classes << "card-normal"
    end

    # Highlight expiring policies
    if highlight_expiring && expiring_soon?
      classes.concat(["border-warning", "bg-warning/5"])
    elsif expired?
      classes.concat(["border-error", "bg-error/5"])
    elsif active?
      classes.concat(["border-success", "shadow-sm", "hover:shadow-md"])
    else
      classes.concat(["border-base-300", "shadow-sm", "hover:shadow-md"])
    end

    classes << additional_classes if additional_classes
    classes.compact.join(" ")
  end

  def status_badge_variant
    case policy_status.downcase
    when 'active' then 'success'
    when 'pending' then 'warning'
    when 'expired' then 'error'
    when 'cancelled' then 'neutral'
    else 'info'
    end
  end

  def policy_type_display
    policy.insurance_type&.humanize || "Unknown"
  end

  def policy_number
    policy.policy_number || policy.application_number || "N/A"
  end

  def policy_status
    policy.status || "unknown"
  end

  def effective_date
    policy.effective_date || policy.created_at
  end

  def expiration_date
    policy.expiration_date || effective_date&.+(1.year)
  end

  def premium_amount
    policy.premium_amount || policy.estimated_premium || 0
  end

  def active?
    policy_status.downcase == 'active'
  end

  def expired?
    expiration_date && expiration_date < Date.current
  end

  def expiring_soon?
    return false unless expiration_date
    days_until_expiry = (expiration_date - Date.current).to_i
    days_until_expiry <= 30 && days_until_expiry > 0
  end

  def days_until_expiry
    return nil unless expiration_date
    (expiration_date - Date.current).to_i
  end

  def expiry_message
    return nil unless expiration_date
    
    days = days_until_expiry
    
    if days < 0
      "Expired #{pluralize(days.abs, 'day')} ago"
    elsif days == 0
      "Expires today"
    elsif days <= 30
      "Expires in #{pluralize(days, 'day')}"
    else
      "Expires #{expiration_date.strftime('%B %d, %Y')}"
    end
  end

  def expiry_icon
    if expired?
      :exclamation_triangle
    elsif expiring_soon?
      :clock
    else
      :calendar_days
    end
  end

  def coverage_details
    details = []
    
    # Add coverage amount if available
    if policy.respond_to?(:coverage_amount) && policy.coverage_amount.present?
      details << "Coverage: #{number_to_currency(policy.coverage_amount)}"
    end
    
    # Add deductible if available
    if policy.respond_to?(:deductible) && policy.deductible.present?
      details << "Deductible: #{number_to_currency(policy.deductible)}"
    end
    
    # Add specific details based on insurance type
    case policy.insurance_type&.downcase
    when 'motor'
      details << "Vehicle: #{policy.vehicle_make} #{policy.vehicle_model}" if policy.respond_to?(:vehicle_make)
    when 'fire', 'residential'
      details << "Property: #{policy.property_address}" if policy.respond_to?(:property_address)
    when 'life'
      details << "Beneficiary: #{policy.beneficiary_name}" if policy.respond_to?(:beneficiary_name)
    end
    
    details
  end

  def show_coverage_details?
    coverage_details.any? && !compact
  end

  def show_expiry_warning?
    expired? || expiring_soon?
  end

  def default_actions
    actions_list = []
    
    actions_list << {
      label: "View Details",
      path: policy_path(policy),
      icon: :eye,
      variant: "ghost"
    }
    
    if active?
      actions_list << {
        label: "Make Claim",
        path: new_customer_claim_path(policy_id: policy.id),
        icon: :plus,
        variant: "primary"
      }
      
      actions_list << {
        label: "Renew",
        path: renew_policy_path(policy),
        icon: :arrow_path,
        variant: "secondary"
      }
    end
    
    actions_list << {
      label: "Download",
      path: policy_path(policy, format: :pdf),
      icon: :arrow_down_tray,
      variant: "outline"
    }
    
    actions_list
  end

  def policy_path(policy)
    "/customer/policies/#{policy.id}"
  end

  def new_customer_claim_path(params = {})
    "/customer/claims/new?" + params.to_query
  end

  def renew_policy_path(policy)
    "/customer/policies/#{policy.id}/renew"
  end
end