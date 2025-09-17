FactoryBot.define do
  factory :feature_flag do
    key { "MyString" }
    name { "MyString" }
    description { "MyText" }
    enabled { false }
    percentage { 1 }
    user_groups { "MyText" }
    conditions { "MyText" }
    metadata { "" }
    created_by { nil }
    updated_by { nil }
  end
end
