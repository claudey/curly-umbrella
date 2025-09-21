FactoryBot.define do
  factory :document do
    association :organization
    association :user
    association :documentable, factory: :client

    name { "Test Document" }
    description { "Test document description" }
    document_type { "policy_document" }
    file_size { 1024 }
    content_type { "application/pdf" }
    checksum { "abc123" }
    version { 1 }
    is_current { true }
    metadata { {} }

    # Skip file attachment for basic testing
  end
end
