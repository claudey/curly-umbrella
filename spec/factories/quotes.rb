FactoryBot.define do
  factory :quote do
    association :insurance_application
    association :insurance_company
    association :motor_application, factory: :insurance_application

    association :organization
    association :quoted_by, factory: :user

    sequence(:quote_number) { |n| "QTE#{n.to_s.rjust(6, '0')}" }
    status { 'draft' }

    # Financial details
    premium_amount { 1000.0 }
    coverage_amount { 50000.0 }
    commission_rate { 15.0 }
    validity_period { 30 }

    trait :submitted do
      status { 'submitted' }
    end
  end
end
