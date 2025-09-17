class FeatureFlag < ApplicationRecord
  acts_as_tenant(:organization, optional: true)
  
  belongs_to :organization, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  
  validates :key, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :percentage, inclusion: { in: 0..100 }, allow_nil: true
  
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  
  # User groups are stored as JSON array
  serialize :user_groups, type: Array, coder: JSON
  
  # Conditions are stored as JSON hash
  serialize :conditions, type: Hash, coder: JSON
  
  before_validation :set_defaults
  
  # Feature flag evaluation methods
  def enabled_for?(user, context = {})
    return false unless enabled?
    
    # Check percentage rollout
    if percentage.present?
      return false unless user_in_percentage_rollout?(user)
    end
    
    # Check user groups
    if user_groups.present?
      return false unless user_in_groups?(user)
    end
    
    # Check custom conditions
    if conditions.present?
      return false unless conditions_met?(user, context)
    end
    
    true
  end
  
  def enabled_percentage
    percentage || (enabled? ? 100 : 0)
  end
  
  def toggle!
    update!(enabled: !enabled?)
  end
  
  def self.enabled?(key, user = nil, context = {})
    flag = find_by(key: key)
    return false unless flag
    
    return flag.enabled? if user.nil?
    flag.enabled_for?(user, context)
  end
  
  def self.create_or_update_flag(key, attributes = {})
    flag = find_or_initialize_by(key: key)
    flag.update!(attributes)
    flag
  end
  
  private
  
  def set_defaults
    self.enabled = false if enabled.nil?
    self.percentage = nil if percentage == 0
    self.user_groups = [] if user_groups.nil?
    self.conditions = {} if conditions.nil?
    self.metadata = {} if metadata.nil?
  end
  
  def user_in_percentage_rollout?(user)
    return true if percentage == 100
    return false if percentage == 0
    
    # Use consistent hash of user ID and flag key for deterministic rollout
    hash_input = "#{user.id}:#{key}"
    hash_value = Digest::SHA256.hexdigest(hash_input).to_i(16)
    rollout_value = hash_value % 100
    
    rollout_value < percentage
  end
  
  def user_in_groups?(user)
    return true if user_groups.empty?
    
    user_group_names = user.groups.pluck(:name)
    (user_groups & user_group_names).any?
  end
  
  def conditions_met?(user, context)
    return true if conditions.empty?
    
    # Evaluate custom conditions
    conditions.all? do |condition_key, condition_value|
      case condition_key
      when 'role'
        user.role == condition_value
      when 'email_domain'
        user.email.end_with?("@#{condition_value}")
      when 'created_after'
        user.created_at > Date.parse(condition_value)
      when 'has_permission'
        user.has_permission?(condition_value)
      when 'context'
        condition_value.all? { |k, v| context[k.to_sym] == v }
      else
        # Custom condition evaluation can be extended here
        true
      end
    end
  end
end
