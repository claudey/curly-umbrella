FactoryBot.define do
  factory :insurance_company do
    association :organization
    
    name { Faker::Company.name + ' Insurance' }
    sequence(:email) { |n| "contact#{n}@#{Faker::Internet.domain_name}" }
    phone_number { Faker::PhoneNumber.phone_number }
    
    # Address information
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state }
    postal_code { Faker::Address.zip_code }
    country { 'United States' }
    
    # Company details
    license_number { Faker::Number.number(digits: 10) }
    rating { ['A++', 'A+', 'A', 'A-', 'B++', 'B+'].sample }
    status { 'active' }
    
    # Contact information
    contact_person { Faker::Name.name }
    website { "https://#{Faker::Internet.domain_name}" }
    
    # Business information
    years_in_business { rand(5..50) }
    specialty_lines { ['auto', 'home', 'life', 'commercial'].sample(rand(1..3)) }
    
    trait :inactive do
      status { 'inactive' }
    end
    
    trait :preferred do
      status { 'preferred' }
      rating { ['A++', 'A+', 'A'].sample }
    end
    
    trait :with_quotes do
      after(:create) do |company|
        application = create(:insurance_application, organization: company.organization)
        create_list(:quote, 3, insurance_company: company, insurance_application: application, organization: company.organization)
      end
    end
  end
end