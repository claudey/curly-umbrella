module Encryptable
  extend ActiveSupport::Concern

  included do
    # Store encrypted field metadata
    @encrypted_fields_metadata ||= {}
  end

  class_methods do
    def encrypt_field(field_name, deterministic: false, **options)
      if deterministic
        encrypts_deterministic field_name, **encryption_options(options)
      else
        encrypts field_name, **encryption_options(options)
      end

      # Store encrypted field metadata
      encrypted_fields_metadata[field_name] = {
        deterministic: deterministic,
        options: options
      }
    end

    def encrypt_pii(*field_names, **options)
      field_names.each do |field_name|
        encrypt_field(field_name, deterministic: true, **options)
      end
    end

    def encrypt_sensitive(*field_names, **options)
      field_names.each do |field_name|
        encrypt_field(field_name, deterministic: false, **options)
      end
    end

    def encrypted_fields_metadata
      @encrypted_fields_metadata ||= {}
    end

    private

    def encryption_options(custom_options = {})
      default_options = {
        key: encryption_key_selector,
        previous: previous_encryption_keys
      }

      default_options.merge(custom_options)
    end

    def encryption_key_selector
      ->(context) {
        # Use different keys based on field sensitivity
        case context[:field_name]
        when /ssn|tax_id|social_security/
          :pii_encryption_key
        when /password|secret|token/
          :auth_encryption_key
        when /credit_card|bank_account|payment/
          :financial_encryption_key
        else
          :general_encryption_key
        end
      }
    end

    def previous_encryption_keys
      # Return array of previous keys for key rotation
      []
    end
  end

  # Instance methods for encryption utilities
  def encrypt_value(value, key_name = :general_encryption_key)
    return nil if value.nil?

    encryptor = ActiveRecord::Encryption::Encryptor.new
    encryptor.encrypt(value.to_s, key: encryption_key(key_name))
  end

  def decrypt_value(encrypted_value, key_name = :general_encryption_key)
    return nil if encrypted_value.nil?

    encryptor = ActiveRecord::Encryption::Encryptor.new
    encryptor.decrypt(encrypted_value, key: encryption_key(key_name))
  end

  def is_field_encrypted?(field_name)
    self.class.encrypted_fields_metadata.key?(field_name.to_sym)
  end

  def get_encrypted_fields
    self.class.encrypted_fields_metadata.keys
  end

  def secure_export_data
    exported_data = attributes.dup

    # Mask or remove encrypted fields for export
    get_encrypted_fields.each do |field|
      if exported_data.key?(field.to_s)
        exported_data[field.to_s] = mask_sensitive_data(exported_data[field.to_s])
      end
    end

    exported_data
  end

  # Data masking for compliance exports
  def mask_sensitive_data(value, mask_char = "*")
    return nil if value.nil?

    value_str = value.to_s
    return value_str if value_str.length <= 4

    # Keep first 2 and last 2 characters, mask the rest
    first_part = value_str[0..1]
    last_part = value_str[-2..-1]
    middle_length = value_str.length - 4

    "#{first_part}#{'*' * middle_length}#{last_part}"
  end

  # Compliance and audit helpers
  def log_encryption_event(action, field_name, user = nil)
    AuditLog.log_security_event(
      user,
      "encryption_#{action}",
      {
        field_name: field_name,
        model: self.class.name,
        record_id: id,
        encryption_key_used: determine_key_for_field(field_name),
        severity: "info"
      }
    )
  end

  def rotate_encryption_keys!
    # This would be implemented based on your key rotation strategy
    get_encrypted_fields.each do |field|
      current_value = send(field)
      if current_value.present?
        # Re-encrypt with new key
        send("#{field}=", current_value)
        log_encryption_event("key_rotation", field)
      end
    end

    save!
  end

  def verify_encryption_integrity
    errors = []

    get_encrypted_fields.each do |field|
      begin
        # Try to read the encrypted field
        value = send(field)
        # If we can read it without error, encryption is intact
      rescue ActiveRecord::Encryption::Errors::Decryption => e
        errors << "Field #{field}: #{e.message}"
      end
    end

    errors
  end

  # Search encrypted fields (only works with deterministic encryption)
  module ClassMethods
    def search_encrypted_field(field_name, search_term)
      metadata = encrypted_fields_metadata[field_name.to_sym]

      if metadata && metadata[:deterministic]
        where(field_name => search_term)
      else
        raise ArgumentError, "Field #{field_name} is not deterministically encrypted and cannot be searched"
      end
    end

    def find_by_encrypted_field(field_name, value)
      search_encrypted_field(field_name, value).first
    end
  end

  private

  def encryption_key(key_name)
    # This would integrate with your key management system
    case key_name
    when :pii_encryption_key
      ENV["PII_ENCRYPTION_KEY"] ||
      Rails.application.config.active_record.encryption.primary_key
    when :auth_encryption_key
      ENV["AUTH_ENCRYPTION_KEY"] ||
      Rails.application.config.active_record.encryption.primary_key
    when :financial_encryption_key
      ENV["FINANCIAL_ENCRYPTION_KEY"] ||
      Rails.application.config.active_record.encryption.primary_key
    else
      Rails.application.config.active_record.encryption.primary_key
    end
  end

  def determine_key_for_field(field_name)
    case field_name.to_s
    when /ssn|tax_id|social_security/
      :pii_encryption_key
    when /password|secret|token/
      :auth_encryption_key
    when /credit_card|bank_account|payment/
      :financial_encryption_key
    else
      :general_encryption_key
    end
  end
end
