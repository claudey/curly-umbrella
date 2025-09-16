require 'rails_helper'

RSpec.describe Quote, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:client) { create(:client, organization: organization) }
  let(:insurance_application) { create(:insurance_application, organization: organization, user: user, client: client) }
  let(:insurance_company) { create(:insurance_company, organization: organization) }
  
  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:insurance_application) }
    it { should belong_to(:insurance_company) }
    it { should belong_to(:user) }
    it { should belong_to(:approved_by).class_name('User').optional }
    it { should belong_to(:rejected_by).class_name('User').optional }
    it { should have_many(:documents).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:quote, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user) }

    it { should validate_presence_of(:quote_number) }
    it { should validate_uniqueness_of(:quote_number).scoped_to(:organization_id) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(Quote::STATUSES) }
    it { should validate_presence_of(:base_premium) }
    it { should validate_numericality_of(:base_premium).is_greater_than(0) }
    it { should validate_presence_of(:total_premium) }
    it { should validate_numericality_of(:total_premium).is_greater_than(0) }
    it { should validate_presence_of(:policy_term) }
    it { should validate_numericality_of(:policy_term).is_greater_than(0) }
    it { should validate_presence_of(:payment_frequency) }
    it { should validate_inclusion_of(:payment_frequency).in_array(Quote::PAYMENT_FREQUENCIES) }
    it { should validate_presence_of(:effective_date) }
    it { should validate_presence_of(:expiry_date) }
    it { should validate_presence_of(:quoted_at) }
    it { should validate_presence_of(:expires_at) }
  end

  describe 'scopes' do
    let!(:pending_quote) { create(:quote, status: 'pending', organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user) }
    let!(:submitted_quote) { create(:quote, :submitted, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user) }
    let!(:approved_quote) { create(:quote, :approved, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user) }
    let!(:accepted_quote) { create(:quote, :accepted, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user) }
    let!(:expired_quote) { create(:quote, :expired, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user) }

    it 'filters by status' do
      expect(Quote.with_status('pending')).to include(pending_quote)
      expect(Quote.with_status('submitted')).to include(submitted_quote)
      expect(Quote.with_status('approved')).to include(approved_quote)
      expect(Quote.with_status('accepted')).to include(accepted_quote)
    end

    it 'filters pending quotes' do
      expect(Quote.pending).to include(pending_quote)
      expect(Quote.pending).not_to include(submitted_quote, approved_quote, accepted_quote)
    end

    it 'filters active quotes' do
      expect(Quote.active).to include(pending_quote, submitted_quote, approved_quote, accepted_quote)
      expect(Quote.active).not_to include(expired_quote)
    end

    it 'filters expired quotes' do
      expect(Quote.expired).to include(expired_quote)
      expect(Quote.expired).not_to include(pending_quote, submitted_quote, approved_quote, accepted_quote)
    end

    it 'filters expiring soon quotes' do
      expiring_quote = create(:quote, expires_at: 2.days.from_now, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user)
      expect(Quote.expiring_soon(7)).to include(expiring_quote)
      expect(Quote.expiring_soon(1)).not_to include(expiring_quote)
    end

    it 'orders by recent first' do
      recent_quotes = Quote.recent.limit(2)
      expect(recent_quotes.first.created_at).to be >= recent_quotes.second.created_at
    end
  end

  describe 'callbacks' do
    it 'generates quote_number before validation on create' do
      quote = build(:quote, quote_number: nil, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user)
      quote.valid?
      expect(quote.quote_number).to be_present
      expect(quote.quote_number).to match(/^QTE\d{6}$/)
    end

    it 'sets quoted_at timestamp before create' do
      quote = build(:quote, quoted_at: nil, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user)
      quote.save!
      expect(quote.quoted_at).to be_present
    end

    it 'sets expires_at timestamp before create' do
      quote = build(:quote, expires_at: nil, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user)
      quote.save!
      expect(quote.expires_at).to be_present
      expect(quote.expires_at).to be > quote.quoted_at
    end

    it 'calculates total_premium before save' do
      quote = build(:quote, base_premium: 1000, taxes: 100, fees: 50, total_premium: nil, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user)
      quote.save!
      expect(quote.total_premium).to eq(1150)
    end

    it 'sets timestamps on status changes' do
      quote = create(:quote, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user)
      
      quote.update!(status: 'submitted')
      expect(quote.submitted_at).to be_present
      
      quote.update!(status: 'approved')
      expect(quote.approved_at).to be_present
      
      rejected_quote = create(:quote, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user)
      rejected_quote.update!(status: 'rejected', rejection_reason: 'Test reason')
      expect(rejected_quote.rejected_at).to be_present
      
      accepted_quote = create(:quote, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user)
      accepted_quote.update!(status: 'accepted')
      expect(accepted_quote.accepted_at).to be_present
    end
  end

  describe 'instance methods' do
    let(:quote) { create(:quote, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user) }

    describe '#expired?' do
      it 'returns true if expires_at is in the past' do
        quote.expires_at = 1.day.ago
        expect(quote.expired?).to be_truthy
      end

      it 'returns false if expires_at is in the future' do
        quote.expires_at = 1.day.from_now
        expect(quote.expired?).to be_falsey
      end
    end

    describe '#expiring_soon?' do
      it 'returns true if expires within specified days' do
        quote.expires_at = 2.days.from_now
        expect(quote.expiring_soon?(7)).to be_truthy
        expect(quote.expiring_soon?(1)).to be_falsey
      end

      it 'returns false if already expired' do
        quote.expires_at = 1.day.ago
        expect(quote.expiring_soon?(7)).to be_falsey
      end
    end

    describe '#can_be_submitted?' do
      it 'returns true for pending quotes' do
        quote.status = 'pending'
        expect(quote.can_be_submitted?).to be_truthy
      end

      it 'returns false for non-pending quotes' do
        quote.status = 'submitted'
        expect(quote.can_be_submitted?).to be_falsey
      end

      it 'returns false for expired quotes' do
        quote.status = 'pending'
        quote.expires_at = 1.day.ago
        expect(quote.can_be_submitted?).to be_falsey
      end
    end

    describe '#can_be_approved?' do
      it 'returns true for submitted quotes' do
        quote.status = 'submitted'
        expect(quote.can_be_approved?).to be_truthy
      end

      it 'returns false for other statuses' do
        quote.status = 'pending'
        expect(quote.can_be_approved?).to be_falsey
        
        quote.status = 'approved'
        expect(quote.can_be_approved?).to be_falsey
      end
    end

    describe '#can_be_accepted?' do
      it 'returns true for approved quotes' do
        quote.status = 'approved'
        expect(quote.can_be_accepted?).to be_truthy
      end

      it 'returns false for other statuses' do
        quote.status = 'pending'
        expect(quote.can_be_accepted?).to be_falsey
        
        quote.status = 'accepted'
        expect(quote.can_be_accepted?).to be_falsey
      end
    end

    describe '#submit!' do
      it 'changes status to submitted and sets timestamp' do
        quote.status = 'pending'
        expect { quote.submit! }.to change { quote.status }.to('submitted')
        expect(quote.submitted_at).to be_present
      end

      it 'raises error if quote cannot be submitted' do
        quote.status = 'approved'
        expect { quote.submit! }.to raise_error(StandardError)
      end
    end

    describe '#approve!' do
      it 'changes status to approved and sets timestamp' do
        quote.status = 'submitted'
        expect { quote.approve!(user) }.to change { quote.status }.to('approved')
        expect(quote.approved_at).to be_present
        expect(quote.approved_by).to eq(user)
      end

      it 'raises error if quote cannot be approved' do
        quote.status = 'pending'
        expect { quote.approve!(user) }.to raise_error(StandardError)
      end
    end

    describe '#reject!' do
      let(:reason) { 'Rate too high' }

      it 'changes status to rejected and sets timestamp and reason' do
        quote.status = 'submitted'
        expect { quote.reject!(user, reason) }.to change { quote.status }.to('rejected')
        expect(quote.rejected_at).to be_present
        expect(quote.rejected_by).to eq(user)
        expect(quote.rejection_reason).to eq(reason)
      end

      it 'raises error if quote cannot be rejected' do
        quote.status = 'accepted'
        expect { quote.reject!(user, reason) }.to raise_error(StandardError)
      end
    end

    describe '#accept!' do
      it 'changes status to accepted and sets timestamp' do
        quote.status = 'approved'
        expect { quote.accept! }.to change { quote.status }.to('accepted')
        expect(quote.accepted_at).to be_present
      end

      it 'raises error if quote cannot be accepted' do
        quote.status = 'pending'
        expect { quote.accept! }.to raise_error(StandardError)
      end
    end

    describe '#withdraw!' do
      let(:reason) { 'Found better rate' }

      it 'changes status to withdrawn and sets timestamp and reason' do
        quote.status = 'approved'
        expect { quote.withdraw!(reason) }.to change { quote.status }.to('withdrawn')
        expect(quote.withdrawn_at).to be_present
        expect(quote.withdrawal_reason).to eq(reason)
      end
    end

    describe '#monthly_premium' do
      it 'calculates monthly premium based on payment frequency' do
        quote.total_premium = 1200
        quote.payment_frequency = 'annual'
        expect(quote.monthly_premium).to eq(100)

        quote.payment_frequency = 'monthly'
        expect(quote.monthly_premium).to eq(1200)

        quote.payment_frequency = 'quarterly'
        expect(quote.monthly_premium).to eq(400)
      end
    end

    describe '#commission_amount' do
      it 'calculates commission based on percentage' do
        quote.total_premium = 1000
        quote.commission_percentage = 15
        expect(quote.commission_amount).to eq(150)
      end

      it 'returns 0 if commission percentage not set' do
        quote.total_premium = 1000
        quote.commission_percentage = nil
        expect(quote.commission_amount).to eq(0)
      end
    end

    describe '#days_until_expiry' do
      it 'returns number of days until expiry' do
        quote.expires_at = 5.days.from_now
        expect(quote.days_until_expiry).to eq(5)
      end

      it 'returns negative number for expired quotes' do
        quote.expires_at = 2.days.ago
        expect(quote.days_until_expiry).to eq(-2)
      end
    end

    describe '#coverage_summary' do
      it 'returns formatted coverage summary' do
        quote.coverage_limits = { 'liability' => 1000000, 'collision' => 50000 }
        summary = quote.coverage_summary
        expect(summary).to include('liability')
        expect(summary).to include('1000000')
      end
    end
  end

  describe 'validations with business rules' do
    let(:quote) { build(:quote, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user) }

    it 'validates effective_date is not in the past' do
      quote.effective_date = 1.day.ago
      expect(quote).not_to be_valid
      expect(quote.errors[:effective_date]).to include('cannot be in the past')
    end

    it 'validates expiry_date is after effective_date' do
      quote.effective_date = 1.month.from_now
      quote.expiry_date = 1.week.from_now
      expect(quote).not_to be_valid
      expect(quote.errors[:expiry_date]).to include('must be after effective date')
    end

    it 'validates expires_at is after quoted_at' do
      quote.quoted_at = Time.current
      quote.expires_at = 1.hour.ago
      expect(quote).not_to be_valid
      expect(quote.errors[:expires_at]).to include('must be after quoted date')
    end

    it 'validates total_premium is greater than or equal to base_premium' do
      quote.base_premium = 1000
      quote.total_premium = 900
      expect(quote).not_to be_valid
      expect(quote.errors[:total_premium]).to include('must be greater than or equal to base premium')
    end
  end

  describe 'audit logging' do
    it 'creates audit log on creation' do
      expect { create(:quote, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user) }
        .to change { Audited::Audit.count }.by(1)
    end

    it 'creates audit log on status change' do
      quote = create(:quote, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user)
      expect { quote.update!(status: 'submitted') }.to change { Audited::Audit.count }.by(1)
    end
  end

  describe 'soft deletion' do
    let(:quote) { create(:quote, organization: organization, insurance_application: insurance_application, insurance_company: insurance_company, user: user) }

    it 'soft deletes the quote' do
      quote.discard
      expect(quote.discarded?).to be_truthy
      expect(Quote.kept).not_to include(quote)
      expect(Quote.discarded).to include(quote)
    end

    it 'can be undiscarded' do
      quote.discard
      quote.undiscard
      expect(quote.discarded?).to be_falsey
      expect(Quote.kept).to include(quote)
    end
  end
end