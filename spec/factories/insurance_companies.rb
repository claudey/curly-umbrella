FactoryBot.define do
  factory :insurance_company do
    name { Faker::Company.name + ' Insurance' }
    sequence(:email) { |n| "contact#{n}@#{Faker::Internet.domain_name}" }
    phone { "+233244123456" }
    business_registration_number { "REG#{rand(100000..999999)}" }
    license_number { "LIC#{rand(100000..999999)}" }
    contact_person { Faker::Name.name }
    rating { 4.5 }
    commission_rate { 15.0 }
    payment_terms { "net_30" }

    website { "https://#{Faker::Internet.domain_name}" }

    trait :with_quotes do
      after(:create) do |company|
        org = create(:organization)
        application = create(:insurance_application, organization: org)
        create_list(:quote, 3, insurance_company: company, insurance_application: application)
      end
    end
  end
end
