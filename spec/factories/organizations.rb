FactoryBot.define do
  factory :organization do
    name { Faker::Company.name }
    subscription_tier { Organization::SUBSCRIPTION_TIERS.sample }
    status { 'active' }
    sequence(:tenant_id) { |n| n }
  end
end