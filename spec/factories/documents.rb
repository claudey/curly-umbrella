FactoryBot.define do
  factory :document do
    association :organization
    association :user
    association :documentable, factory: :insurance_application

    name { "Test Document" }
    description { "Test document description" }
    document_type { "policy_document" }
    version { 1 }
    is_current { true }
    access_level { "public" }
    metadata { {} }

    after(:build) do |document|
      document.file.attach(
        io: File.open(Rails.root.join('test-documents/fire-insurance/property_deed.pdf')),
        filename: 'test-document.pdf',
        content_type: 'application/pdf'
      )
    end
  end
end
