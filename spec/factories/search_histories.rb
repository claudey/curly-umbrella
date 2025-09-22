FactoryBot.define do
  factory :search_history do
    user { nil }
    query { "MyString" }
    results_count { 1 }
    search_time { "9.99" }
    metadata { "" }
  end
end
