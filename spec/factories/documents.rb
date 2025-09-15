FactoryBot.define do
  factory :document do
    name { "MyString" }
    description { "MyText" }
    document_type { "MyString" }
    file_size { "" }
    content_type { "MyString" }
    checksum { "MyString" }
    version { 1 }
    is_current { false }
    metadata { "" }
    organization { nil }
    user { nil }
    documentable { nil }
  end
end
