class SmsLog < ApplicationRecord
  acts_as_tenant(:organization)
  
  belongs_to :organization
  belongs_to :user, optional: true
  
  validates :to, presence: true
  validates :body, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending sent failed delivered] }
  
  scope :sent, -> { where(status: 'sent') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(sent_at: :desc) }
  scope :for_date_range, ->(start_date, end_date) { where(sent_at: start_date..end_date) }
  
  def success?
    status.in?(%w[sent delivered])
  end
  
  def failed?
    status == 'failed'
  end
  
  def formatted_phone
    return to unless to.start_with?('+1')
    
    # Format US/CA numbers as (XXX) XXX-XXXX
    digits = to[2..-1]
    return to unless digits.length == 10
    
    "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
  end
end