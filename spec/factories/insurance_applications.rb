FactoryBot.define do
  factory :insurance_application do
    association :organization
    association :user
    association :client

    insurance_type { 'motor' }
    status { 'draft' }
    application_data { {
      vehicle_make: 'Toyota',
      vehicle_model: 'Camry',
      vehicle_year: '2020',
      registration_number: 'ABC123',
      chassis_number: 'CHD456',
      engine_number: 'ENG789',
      driver_license_number: 'DL001122'
    } }

    trait :submitted do
      status { 'submitted' }
    end
  end
end
