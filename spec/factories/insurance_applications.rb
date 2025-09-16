FactoryBot.define do
  factory :insurance_application do
    association :organization
    association :user
    association :client
    
    sequence(:application_id) { |n| "APP#{n.to_s.rjust(6, '0')}" }
    application_type { InsuranceApplication::APPLICATION_TYPES.sample }
    status { 'draft' }
    
    # Personal information
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    phone_number { Faker::PhoneNumber.phone_number }
    email { Faker::Internet.email }
    date_of_birth { Faker::Date.birthday(min_age: 18, max_age: 80) }
    
    # Address information
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state }
    postal_code { Faker::Address.zip_code }
    
    # Policy details
    coverage_amount { Faker::Number.decimal(l_digits: 5, r_digits: 2) }
    policy_start_date { 1.month.from_now }
    policy_end_date { 1.year.from_now }
    
    trait :motor do
      application_type { 'motor' }
      # Vehicle-specific details
      vehicle_make { Faker::Vehicle.make }
      vehicle_model { Faker::Vehicle.model }
      vehicle_year { Faker::Vehicle.year }
      vehicle_vin { Faker::Vehicle.vin }
      license_number { Faker::Vehicle.license_plate }
    end
    
    trait :life do
      application_type { 'life' }
      # Life insurance specific details
      beneficiary_name { Faker::Name.name }
      beneficiary_relationship { ['spouse', 'child', 'parent', 'sibling'].sample }
      medical_history { Faker::Lorem.paragraph }
    end
    
    trait :property do
      application_type { 'property' }
      # Property specific details
      property_type { ['house', 'apartment', 'condo', 'commercial'].sample }
      property_value { Faker::Number.decimal(l_digits: 6, r_digits: 2) }
      year_built { Faker::Date.between(from: 50.years.ago, to: Time.current).year }
    end
    
    trait :submitted do
      status { 'submitted' }
      submitted_at { 1.day.ago }
    end
    
    trait :under_review do
      status { 'under_review' }
      submitted_at { 1.day.ago }
      review_started_at { 6.hours.ago }
    end
    
    trait :approved do
      status { 'approved' }
      submitted_at { 2.days.ago }
      review_started_at { 1.day.ago }
      approved_at { 2.hours.ago }
    end
    
    trait :rejected do
      status { 'rejected' }
      submitted_at { 2.days.ago }
      review_started_at { 1.day.ago }
      rejected_at { 2.hours.ago }
      rejection_reason { 'Does not meet underwriting criteria' }
    end
  end
end