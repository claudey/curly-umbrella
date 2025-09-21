FactoryBot.define do
  factory :client do
    association :organization
    
    sequence(:email) { |n| "client#{n}@example.com" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    phone { "+233244123456" }
    date_of_birth { Faker::Date.birthday(min_age: 18, max_age: 80) }
    
    # Address information
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state }
    postal_code { Faker::Address.zip_code }
    country { 'United States' }
    
    trait :inactive do
      # Client model doesn't have status field
    end
    
    trait :with_applications do
      after(:create) do |client|
        create_list(:insurance_application, 2, client: client, organization: client.organization)
      end
    end
  end
end