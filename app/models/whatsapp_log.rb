class WhatsappLog < ApplicationRecord
  acts_as_tenant(:organization)

  belongs_to :organization
  belongs_to :user, optional: true

  validates :to, presence: true
  validates :message, presence: true
  validates :message_type, presence: true, inclusion: { in: %w[text template] }
  validates :status, presence: true, inclusion: { in: %w[pending sent delivered read failed] }

  scope :sent, -> { where(status: "sent") }
  scope :delivered, -> { where(status: "delivered") }
  scope :read, -> { where(status: "read") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(sent_at: :desc) }
  scope :for_date_range, ->(start_date, end_date) { where(sent_at: start_date..end_date) }

  def success?
    status.in?(%w[sent delivered read])
  end

  def failed?
    status == "failed"
  end

  def formatted_phone
    return to unless to.length >= 10

    # Format as WhatsApp number (with country code)
    if to.length == 11 && to.start_with?("1")
      # US/CA number
      country_code = to[0]
      area_code = to[1..3]
      exchange = to[4..6]
      number = to[7..10]
      "+#{country_code} (#{area_code}) #{exchange}-#{number}"
    else
      "+#{to}"
    end
  end

  def delivery_status_icon
    case status
    when "sent"
      "ph-check"
    when "delivered"
      "ph-checks"
    when "read"
      "ph-checks text-primary"
    when "failed"
      "ph-x-circle text-error"
    else
      "ph-clock"
    end
  end
end
