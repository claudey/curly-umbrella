RSpec.configure do |config|
  config.before(:suite) do
    # Set up encryption for tests
    Rails.application.config.active_record.encryption.primary_key = SecureRandom.alphanumeric(32)
    Rails.application.config.active_record.encryption.deterministic_key = SecureRandom.alphanumeric(32)
    Rails.application.config.active_record.encryption.key_derivation_salt = SecureRandom.alphanumeric(32)
  end

  config.around(:each, :with_encryption) do |example|
    # Enable encryption for specific tests
    ActiveRecord::Encryption.config.support_unencrypted_data = true
    example.run
    ActiveRecord::Encryption.config.support_unencrypted_data = false
  end
end
