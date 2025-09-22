FactoryBot.define do
  factory :security_alert do
    association :organization

    alert_type { "multiple_failed_logins" }
    message { "Multiple failed login attempts detected" }
    severity { "medium" }
    status { "active" }
    triggered_at { Time.current }
    data { {} }
    resolved_at { nil }
    resolved_by { nil }
    resolution_notes { nil }
  end
end
