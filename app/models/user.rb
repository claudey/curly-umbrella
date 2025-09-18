class User < ApplicationRecord
  audited except: [:encrypted_password, :mfa_secret, :backup_codes]

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Multi-tenant association
  acts_as_tenant :organization
  belongs_to :organization

  # Associations
  has_one :notification_preference, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :sms_logs, dependent: :destroy
  has_many :whatsapp_logs, dependent: :destroy
  has_many :documents, dependent: :destroy

  # User roles
  enum :role, {
    super_admin: 0,
    brokerage_admin: 1,
    agent: 2,
    insurance_company: 3
  }

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :phone, presence: true
  validates :phone_number, format: { with: /\A[+]?[1-9]\d{1,14}\z/, message: "must be a valid phone number" }, allow_blank: true
  validates :whatsapp_number, format: { with: /\A[+]?[1-9]\d{1,14}\z/, message: "must be a valid WhatsApp number" }, allow_blank: true
  validates :role, presence: true
  validates :mfa_secret, presence: true, if: :mfa_enabled?

  # Methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    full_name.presence || email
  end

  # Notification preferences helper
  def notification_preferences
    super || build_notification_preference
  end

  # MFA Methods
  def mfa_setup_required?
    organization&.feature_enabled?(:multi_factor_auth) && !mfa_enabled?
  end

  def generate_mfa_secret
    self.mfa_secret = ROTP::Base32.random
  end

  def mfa_qr_code_uri
    return nil unless mfa_secret

    issuer = Rails.application.class.module_parent_name
    account_name = "#{issuer}:#{email}"

    ROTP::TOTP.new(mfa_secret, issuer: issuer).provisioning_uri(account_name)
  end

  def generate_qr_code
    require "rqrcode"

    qr_code = RQRCode::QRCode.new(mfa_qr_code_uri)
    qr_code.as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true
    )
  end

  def verify_mfa_code(code, drift: 30)
    return false unless mfa_enabled? && mfa_secret
    return false if code.blank?

    # Check if it's a backup code
    if backup_codes.present? && backup_codes.include?(code)
      # Remove used backup code
      codes = JSON.parse(backup_codes)
      codes.delete(code)
      update!(backup_codes: codes.to_json)
      return true
    end

    # Verify TOTP code
    totp = ROTP::TOTP.new(mfa_secret)
    verification_time = totp.verify(code, drift_ahead: drift, drift_behind: drift)

    if verification_time
      # Prevent code reuse by checking if this code was used recently
      code_time = Time.at(verification_time)
      return false if last_mfa_code_used_at && last_mfa_code_used_at >= code_time

      update!(last_mfa_code_used_at: code_time)
      true
    else
      false
    end
  end

  def enable_mfa!
    generate_mfa_secret unless mfa_secret
    generate_backup_codes
    update!(
      mfa_enabled: true,
      mfa_setup_at: Time.current
    )
  end

  def disable_mfa!
    update!(
      mfa_enabled: false,
      mfa_secret: nil,
      backup_codes: nil,
      mfa_setup_at: nil,
      last_mfa_code_used_at: nil
    )
  end

  def generate_backup_codes(count: 10)
    codes = Array.new(count) { SecureRandom.hex(4) }
    self.backup_codes = codes.to_json
    codes
  end

  def backup_codes_array
    return [] unless backup_codes
    JSON.parse(backup_codes)
  rescue JSON::ParserError
    []
  end

  # SMS Methods
  def can_receive_sms?
    phone_number.present? && sms_enabled?
  end

  def formatted_phone_number
    return phone_number unless phone_number&.start_with?('+1')
    
    # Format US/CA numbers as (XXX) XXX-XXXX
    digits = phone_number[2..-1]
    return phone_number unless digits.length == 10
    
    "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
  end

  def send_sms(body:, from: nil)
    return false unless can_receive_sms?
    
    SmsService.new.send_sms(
      to: phone_number,
      body: body,
      from: from
    )
  end

  # WhatsApp Methods
  def can_receive_whatsapp?
    whatsapp_number.present? && whatsapp_enabled?
  end

  def formatted_whatsapp_number
    return whatsapp_number unless whatsapp_number&.match?(/^\d+$/)
    
    # Format as international number
    if whatsapp_number.length == 11 && whatsapp_number.start_with?('1')
      # US/CA number
      country_code = whatsapp_number[0]
      area_code = whatsapp_number[1..3]
      exchange = whatsapp_number[4..6]
      number = whatsapp_number[7..10]
      "+#{country_code} (#{area_code}) #{exchange}-#{number}"
    else
      "+#{whatsapp_number}"
    end
  end

  def send_whatsapp(message:, message_type: 'text')
    return false unless can_receive_whatsapp?
    
    WhatsappService.new.send_message(
      to: whatsapp_number,
      message: message,
      message_type: message_type
    )
  end

  # Create default notification preferences after user creation
  after_create :create_default_notification_preferences

  private

  def create_default_notification_preferences
    NotificationPreference.create_defaults_for_user(self, organization)
  end
end
