FactoryBot.define do
  factory :feature_flag do
    sequence(:key) { |n| "test_feature_#{n}" }
    name { "Test Feature" }
    description { "A test feature flag" }
    enabled { false }
    percentage { nil }
    user_groups { [] }
    conditions { {} }
    metadata { {} }
    created_by { nil }
    updated_by { nil }
  end
end
