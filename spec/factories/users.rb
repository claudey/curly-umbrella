FactoryBot.define do
  factory :user do
    association :organization
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    password_confirmation { 'password123' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    phone_number { Faker::PhoneNumber.phone_number }
    status { 'active' }
    confirmed_at { Time.current }
    role { 'agent' }

    trait :admin do
      role { 'admin' }
    end

    trait :executive do
      role { 'executive' }
    end

    trait :agent do
      role { 'agent' }
    end

    trait :with_mfa do
      mfa_enabled { true }
      mfa_secret { ROTP::Base32.random }
    end

    trait :inactive do
      status { 'inactive' }
    end
  end
end