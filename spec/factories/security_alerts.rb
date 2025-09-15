FactoryBot.define do
  factory :security_alert do
    alert_type { "MyString" }
    message { "MyText" }
    severity { "MyString" }
    data { "" }
    organization { nil }
    triggered_at { "2025-09-15 23:24:37" }
    status { "MyString" }
    resolved_at { "2025-09-15 23:24:37" }
    resolved_by { nil }
  end
end
