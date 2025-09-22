FactoryBot.define do
  factory :api_key do
    association :user
    association :organization

    name { "Test API Key" }
    key { ApiKey.generate_key }
    access_level { "read_write" }
    active { true }
    expires_at { 1.year.from_now }
    scopes { %w[api:access applications:read applications:write quotes:read quotes:write] }
    rate_limit { 1000 }

    trait :read_only do
      access_level { "read_only" }
      scopes { %w[api:access applications:read quotes:read] }
      rate_limit { 500 }
    end

    trait :admin do
      access_level { "admin" }
      scopes { ApiKey::AVAILABLE_SCOPES }
      rate_limit { 5000 }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :inactive do
      active { false }
    end

    trait :basic_tier do
      rate_limit { 100 }
    end

    trait :premium_tier do
      rate_limit { 2000 }
    end

    trait :enterprise_tier do
      rate_limit { 10000 }
    end
  end
end
