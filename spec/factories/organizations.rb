FactoryBot.define do
  factory :organization do
    name { Faker::Company.name }
    license_number { "LIC-#{rand(100000..999999)}" }
    subdomain { "org#{rand(1000..9999)}" }
    plan { ['basic', 'premium', 'enterprise'].sample }
    active { true }
    max_users { 50 }
    max_applications { 1000 }
    billing_email { Faker::Internet.email }
    description { Faker::Company.catch_phrase }
  end
end