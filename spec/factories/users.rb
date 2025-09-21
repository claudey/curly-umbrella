FactoryBot.define do
  factory :user do
    association :organization
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123456' }
    password_confirmation { 'password123456' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    phone { "+233244123456" }
    phone_number { "+233244123456" }
    role { 'agent' }
    sms_enabled { false }
    whatsapp_enabled { false }

    trait :brokerage_admin do
      role { 'brokerage_admin' }
    end

    trait :agent do
      role { 'agent' }
    end

    trait :insurance_company do
      role { 'insurance_company' }
    end

    trait :with_mfa do
      mfa_enabled { true }
      mfa_secret { ROTP::Base32.random }
    end

    trait :with_sms do
      sms_enabled { true }
      phone { "+233244123456" }
    end

    trait :with_whatsapp do
      whatsapp_enabled { true }
      whatsapp_number { "+233244123456" }
    end
  end
end