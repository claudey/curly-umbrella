class Document < ApplicationRecord
  include Discard::Model
  acts_as_tenant :organization
  audited except: [:checksum, :file_size]

  # Document type constants
  DOCUMENT_TYPES = %w[
    application_form
    driver_license
    vehicle_registration
    insurance_certificate
    claim_form
    policy_document
    quote_document
    payment_receipt
    inspection_report
    medical_report
    other
  ].freeze

  # Access level constants
  ACCESS_LEVELS = %w[
    public
    private
    confidential
    restricted
  ].freeze

  # Category constants
  CATEGORIES = %w[
    legal
    financial
    medical
    technical
    administrative
    compliance
  ].freeze

  belongs_to :organization
  belongs_to :user
  belongs_to :documentable, polymorphic: true
  belongs_to :archived_by, class_name: 'User', optional: true

  has_one_attached :file
  
  validates :name, presence: true
  validates :document_type, presence: true, inclusion: { in: DOCUMENT_TYPES }
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :access_level, presence: true, inclusion: { in: ACCESS_LEVELS }
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  
  validate :file_attachment_required
  validate :expires_at_in_future, if: :expires_at?

  before_save :set_file_metadata, if: :file_attached?
  before_save :set_checksum, if: :file_attached?
  after_commit :ensure_single_current_version, on: [:create, :update]
  
  # Notification callbacks
  after_create_commit :notify_document_uploaded
  after_update_commit :notify_document_updated, if: :should_notify_update?
  after_commit :notify_archive_status_change, if: :saved_change_to_is_archived?

  scope :current, -> { where(is_current: true) }
  scope :archived, -> { where(is_archived: true) }
  scope :not_archived, -> { where(is_archived: false) }
  scope :public_documents, -> { where(is_public: true) }
  scope :private_documents, -> { where(is_public: false) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_type, ->(type) { where(document_type: type) }
  scope :expiring_soon, ->(days = 30) { where(expires_at: Time.current..days.days.from_now) }
  scope :expired, -> { where(expires_at: ...Time.current) }
  scope :by_tags, ->(tags) { where('tags && ARRAY[?]', Array(tags)) }
  scope :recent, -> { order(created_at: :desc) }

  # Document types
  DOCUMENT_TYPES = %w[
    application_form
    insurance_policy
    claim_form
    identity_document
    proof_of_income
    medical_report
    vehicle_registration
    property_deed
    financial_statement
    correspondence
    contract
    invoice
    receipt
    certificate
    legal_document
    compliance_document
    audit_report
    other
  ].freeze

  # Access levels
  ACCESS_LEVELS = %w[private organization public].freeze

  # Categories
  CATEGORIES = %w[
    underwriting
    claims
    legal
    financial
    compliance
    marketing
    operations
    hr
    it
    general
  ].freeze

  def file_attached?
    file.attached?
  end

  def file_url
    return nil unless file_attached?
    Rails.application.routes.url_helpers.url_for(file)
  end

  def download_url
    return nil unless file_attached?
    Rails.application.routes.url_helpers.rails_blob_path(file, disposition: "attachment")
  end

  def preview_url
    return nil unless file_attached?
    Rails.application.routes.url_helpers.rails_blob_path(file, disposition: "inline")
  end

  def human_file_size
    return 'Unknown' unless file_size
    
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    size = file_size.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(1)} #{units[unit_index]}"
  end

  def expired?
    expires_at&.< Time.current
  end

  def expiring_soon?(days = 30)
    expires_at && expires_at <= days.days.from_now && !expired?
  end

  def can_be_viewed_by?(user)
    case access_level
    when 'public'
      true
    when 'organization'
      user.organization_id == organization_id
    when 'private'
      user == self.user || user.can_manage_organization?(organization)
    else
      false
    end
  end

  def can_be_edited_by?(user)
    return false if is_archived?
    user == self.user || user.can_manage_organization?(organization)
  end

  def can_be_deleted_by?(user)
    return false if is_archived?
    user == self.user || user.can_manage_organization?(organization)
  end

  def archive!(user, reason = nil)
    return false if is_archived?
    
    transaction do
      update!(
        is_archived: true,
        archived_at: Time.current,
        archived_by: user,
        archive_reason: reason
      )
    end
  end

  def restore!(user)
    return false unless is_archived?
    
    transaction do
      update!(
        is_archived: false,
        archived_at: nil,
        archived_by: nil,
        archive_reason: nil
      )
    end
  end

  def create_new_version!(new_file, user, attributes = {})
    transaction do
      # Mark current version as not current
      self.class.where(
        documentable: documentable,
        document_type: document_type,
        name: name
      ).update_all(is_current: false)
      
      # Create new version
      new_document = self.class.create!(
        name: name,
        description: attributes[:description] || description,
        document_type: document_type,
        organization: organization,
        user: user,
        documentable: documentable,
        category: attributes[:category] || category,
        tags: attributes[:tags] || tags,
        is_public: attributes.key?(:is_public) ? attributes[:is_public] : is_public,
        access_level: attributes[:access_level] || access_level,
        expires_at: attributes[:expires_at] || expires_at,
        version: (self.class.where(
          documentable: documentable,
          document_type: document_type,
          name: name
        ).maximum(:version) || 0) + 1,
        is_current: true,
        metadata: attributes[:metadata] || {}
      )
      
      new_document.file.attach(new_file)
      new_document
    end
  end

  def version_history
    self.class.where(
      documentable: documentable,
      document_type: document_type,
      name: name
    ).order(version: :desc)
  end

  def previous_version
    version_history.where('version < ?', version).first
  end

  def next_version
    version_history.where('version > ?', version).first
  end

  def is_image?
    return false unless content_type
    content_type.start_with?('image/')
  end

  def is_pdf?
    content_type == 'application/pdf'
  end

  def is_text?
    return false unless content_type
    content_type.start_with?('text/') || 
    %w[application/json application/xml].include?(content_type)
  end

  def icon_class
    case content_type
    when /^image\//
      'ph-image'
    when 'application/pdf'
      'ph-file-pdf'
    when /^text\//, 'application/json', 'application/xml'
      'ph-file-text'
    when /excel/, /spreadsheet/
      'ph-file-xls'
    when /word/, /document/
      'ph-file-doc'
    when /zip/, /compressed/
      'ph-file-zip'
    else
      'ph-file'
    end
  end

  # Notification methods
  def notify_document_uploaded
    DocumentNotificationService.notify_document_uploaded(self)
  end

  def notify_document_updated
    DocumentNotificationService.notify_document_updated(self)
  end

  def notify_archive_status_change
    if is_archived?
      DocumentNotificationService.notify_document_archived(self, archived_by)
    else
      DocumentNotificationService.notify_document_restored(self, user)
    end
  end

  def should_notify_update?
    # Only notify for significant updates, not metadata-only changes
    saved_changes.keys.any? { |key| %w[name description file category access_level expires_at].include?(key) }
  end

  private

  def set_file_metadata
    return unless file_attached?
    
    self.file_size = file.blob.byte_size
    self.content_type = file.blob.content_type
  end

  def set_checksum
    return unless file_attached?
    
    self.checksum = file.blob.checksum
  end

  def file_attachment_required
    errors.add(:file, 'must be attached') unless file_attached?
  end

  def expires_at_in_future
    return unless expires_at
    
    errors.add(:expires_at, 'must be in the future') if expires_at <= Time.current
  end

  def ensure_single_current_version
    return unless is_current? && saved_change_to_is_current?
    
    # Ensure only one current version exists for the same document
    self.class.where(
      documentable: documentable,
      document_type: document_type,
      name: name
    ).where.not(id: id).update_all(is_current: false)
  end
end