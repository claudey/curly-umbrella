FactoryBot.define do
  factory :quote do
    association :organization
    association :insurance_application
    association :insurance_company
    association :user
    
    sequence(:quote_number) { |n| "QTE#{n.to_s.rjust(6, '0')}" }
    status { 'pending' }
    
    # Financial details
    base_premium { Faker::Number.decimal(l_digits: 4, r_digits: 2) }
    taxes { base_premium * 0.1 }
    fees { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    total_premium { base_premium + taxes + fees }
    
    # Policy terms
    policy_term { [6, 12, 24, 36].sample }
    payment_frequency { ['monthly', 'quarterly', 'semi_annual', 'annual'].sample }
    effective_date { 1.month.from_now }
    expiry_date { 1.year.from_now }
    
    # Coverage details
    coverage_limits { { 'liability' => 1000000, 'collision' => 50000, 'comprehensive' => 30000 } }
    deductibles { { 'collision' => 500, 'comprehensive' => 250 } }
    
    # Quote lifecycle
    quoted_at { Time.current }
    expires_at { 30.days.from_now }
    
    trait :submitted do
      status { 'submitted' }
      submitted_at { 1.day.ago }
    end
    
    trait :approved do
      status { 'approved' }
      submitted_at { 2.days.ago }
      approved_at { 1.day.ago }
    end
    
    trait :rejected do
      status { 'rejected' }
      submitted_at { 2.days.ago }
      rejected_at { 1.day.ago }
      rejection_reason { 'Exceeds risk tolerance' }
    end
    
    trait :accepted do
      status { 'accepted' }
      submitted_at { 3.days.ago }
      approved_at { 2.days.ago }
      accepted_at { 1.day.ago }
    end
    
    trait :withdrawn do
      status { 'withdrawn' }
      submitted_at { 3.days.ago }
      withdrawn_at { 1.day.ago }
      withdrawal_reason { 'Client found better rate' }
    end
    
    trait :expired do
      status { 'expired' }
      quoted_at { 45.days.ago }
      expires_at { 15.days.ago }
    end
    
    trait :motor do
      after(:build) do |quote|
        quote.insurance_application.application_type = 'motor'
      end
    end
    
    trait :life do
      after(:build) do |quote|
        quote.insurance_application.application_type = 'life'
        quote.coverage_limits = { 'death_benefit' => 500000, 'accidental_death' => 100000 }
      end
    end
    
    trait :property do
      after(:build) do |quote|
        quote.insurance_application.application_type = 'property'
        quote.coverage_limits = { 'dwelling' => 300000, 'personal_property' => 150000, 'liability' => 100000 }
      end
    end
  end
end