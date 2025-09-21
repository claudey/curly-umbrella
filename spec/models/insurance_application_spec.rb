require 'rails_helper'

RSpec.describe InsuranceApplication, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:client) { create(:client, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:user) }
    it { should belong_to(:client) }
    it { should have_many(:quotes).dependent(:destroy) }
    it { should have_many(:documents).dependent(:destroy) }
    it { should have_many(:application_distributions).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:insurance_application, organization: organization, user: user, client: client) }

    it { should validate_presence_of(:application_id) }
    it { should validate_uniqueness_of(:application_id).scoped_to(:organization_id) }
    it { should validate_presence_of(:application_type) }
    it { should validate_inclusion_of(:application_type).in_array(InsuranceApplication::APPLICATION_TYPES) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(InsuranceApplication::STATUSES) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:date_of_birth) }
    it { should validate_presence_of(:phone_number) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:address) }
    it { should validate_presence_of(:city) }
    it { should validate_presence_of(:state) }
    it { should validate_presence_of(:postal_code) }
  end

  describe 'scopes' do
    let!(:draft_app) { create(:insurance_application, :motor, status: 'draft', organization: organization, user: user, client: client) }
    let!(:submitted_app) { create(:insurance_application, :life, status: 'submitted', organization: organization, user: user, client: client) }
    let!(:approved_app) { create(:insurance_application, :property, status: 'approved', organization: organization, user: user, client: client) }
    let!(:rejected_app) { create(:insurance_application, :motor, status: 'rejected', organization: organization, user: user, client: client) }

    it 'filters by status' do
      expect(InsuranceApplication.with_status('draft')).to include(draft_app)
      expect(InsuranceApplication.with_status('submitted')).to include(submitted_app)
      expect(InsuranceApplication.with_status('approved')).to include(approved_app)
      expect(InsuranceApplication.with_status('rejected')).to include(rejected_app)
    end

    it 'filters by application type' do
      expect(InsuranceApplication.by_type('motor')).to include(draft_app, rejected_app)
      expect(InsuranceApplication.by_type('life')).to include(submitted_app)
      expect(InsuranceApplication.by_type('property')).to include(approved_app)
    end

    it 'filters pending applications' do
      expect(InsuranceApplication.pending).to include(submitted_app)
      expect(InsuranceApplication.pending).not_to include(draft_app, approved_app, rejected_app)
    end

    it 'filters completed applications' do
      expect(InsuranceApplication.completed).to include(approved_app, rejected_app)
      expect(InsuranceApplication.completed).not_to include(draft_app, submitted_app)
    end

    it 'orders by recent first' do
      recent_apps = InsuranceApplication.recent.limit(2)
      expect(recent_apps.first.created_at).to be >= recent_apps.second.created_at
    end
  end

  describe 'callbacks' do
    it 'generates application_id before validation on create' do
      app = build(:insurance_application, application_id: nil, organization: organization, user: user, client: client)
      app.valid?
      expect(app.application_id).to be_present
      expect(app.application_id).to match(/^APP\d{6}$/)
    end

    it 'sets timestamps on status changes' do
      app = create(:insurance_application, organization: organization, user: user, client: client)

      app.update!(status: 'submitted')
      expect(app.submitted_at).to be_present

      app.update!(status: 'under_review')
      expect(app.review_started_at).to be_present

      app.update!(status: 'approved')
      expect(app.approved_at).to be_present

      rejected_app = create(:insurance_application, organization: organization, user: user, client: client)
      rejected_app.update!(status: 'rejected', rejection_reason: 'Test reason')
      expect(rejected_app.rejected_at).to be_present
    end
  end

  describe 'instance methods' do
    let(:application) { create(:insurance_application, organization: organization, user: user, client: client) }

    describe '#full_name' do
      it 'returns concatenated first and last name' do
        application.first_name = 'John'
        application.last_name = 'Doe'
        expect(application.full_name).to eq('John Doe')
      end
    end

    describe '#can_be_submitted?' do
      it 'returns true for draft applications' do
        application.status = 'draft'
        expect(application.can_be_submitted?).to be_truthy
      end

      it 'returns false for non-draft applications' do
        application.status = 'submitted'
        expect(application.can_be_submitted?).to be_falsey
      end
    end

    describe '#can_be_approved?' do
      it 'returns true for submitted or under_review applications' do
        application.status = 'submitted'
        expect(application.can_be_approved?).to be_truthy

        application.status = 'under_review'
        expect(application.can_be_approved?).to be_truthy
      end

      it 'returns false for other statuses' do
        application.status = 'draft'
        expect(application.can_be_approved?).to be_falsey

        application.status = 'approved'
        expect(application.can_be_approved?).to be_falsey
      end
    end

    describe '#can_be_rejected?' do
      it 'returns true for submitted or under_review applications' do
        application.status = 'submitted'
        expect(application.can_be_rejected?).to be_truthy

        application.status = 'under_review'
        expect(application.can_be_rejected?).to be_truthy
      end

      it 'returns false for other statuses' do
        application.status = 'approved'
        expect(application.can_be_rejected?).to be_falsey
      end
    end

    describe '#submit!' do
      it 'changes status to submitted and sets timestamp' do
        application.status = 'draft'
        expect { application.submit! }.to change { application.status }.to('submitted')
        expect(application.submitted_at).to be_present
      end

      it 'raises error if application cannot be submitted' do
        application.status = 'approved'
        expect { application.submit! }.to raise_error(StandardError)
      end
    end

    describe '#approve!' do
      it 'changes status to approved and sets timestamp' do
        application.status = 'submitted'
        expect { application.approve!(user) }.to change { application.status }.to('approved')
        expect(application.approved_at).to be_present
        expect(application.approved_by).to eq(user)
      end

      it 'raises error if application cannot be approved' do
        application.status = 'draft'
        expect { application.approve!(user) }.to raise_error(StandardError)
      end
    end

    describe '#reject!' do
      let(:reason) { 'Does not meet criteria' }

      it 'changes status to rejected and sets timestamp and reason' do
        application.status = 'submitted'
        expect { application.reject!(user, reason) }.to change { application.status }.to('rejected')
        expect(application.rejected_at).to be_present
        expect(application.rejected_by).to eq(user)
        expect(application.rejection_reason).to eq(reason)
      end

      it 'raises error if application cannot be rejected' do
        application.status = 'approved'
        expect { application.reject!(user, reason) }.to raise_error(StandardError)
      end
    end

    describe '#processing_time' do
      it 'returns nil if not completed' do
        application.status = 'submitted'
        application.submitted_at = 1.day.ago
        expect(application.processing_time).to be_nil
      end

      it 'calculates processing time for approved applications' do
        application.status = 'approved'
        application.submitted_at = 2.days.ago
        application.approved_at = 1.day.ago
        expect(application.processing_time).to be_within(1).of(1.day.to_i)
      end

      it 'calculates processing time for rejected applications' do
        application.status = 'rejected'
        application.submitted_at = 3.days.ago
        application.rejected_at = 1.day.ago
        expect(application.processing_time).to be_within(1).of(2.days.to_i)
      end
    end

    describe '#has_quotes?' do
      it 'returns true if application has quotes' do
        create(:quote, insurance_application: application, organization: organization)
        expect(application.has_quotes?).to be_truthy
      end

      it 'returns false if application has no quotes' do
        expect(application.has_quotes?).to be_falsey
      end
    end

    describe '#accepted_quotes' do
      it 'returns only accepted quotes' do
        accepted_quote = create(:quote, :accepted, insurance_application: application, organization: organization)
        create(:quote, :rejected, insurance_application: application, organization: organization)

        expect(application.accepted_quotes).to include(accepted_quote)
        expect(application.accepted_quotes.count).to eq(1)
      end
    end
  end

  describe 'motor application specific validations' do
    subject { build(:insurance_application, :motor, organization: organization, user: user, client: client) }

    it 'validates motor-specific fields when application_type is motor' do
      subject.vehicle_make = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:vehicle_make]).to include("can't be blank")
    end
  end

  describe 'life application specific validations' do
    subject { build(:insurance_application, :life, organization: organization, user: user, client: client) }

    it 'validates life-specific fields when application_type is life' do
      subject.beneficiary_name = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:beneficiary_name]).to include("can't be blank")
    end
  end

  describe 'property application specific validations' do
    subject { build(:insurance_application, :property, organization: organization, user: user, client: client) }

    it 'validates property-specific fields when application_type is property' do
      subject.property_type = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:property_type]).to include("can't be blank")
    end
  end

  describe 'audit logging' do
    it 'creates audit log on creation' do
      expect { create(:insurance_application, organization: organization, user: user, client: client) }
        .to change { Audited::Audit.count }.by(1)
    end

    it 'creates audit log on update' do
      app = create(:insurance_application, organization: organization, user: user, client: client)
      expect { app.update!(status: 'submitted') }.to change { Audited::Audit.count }.by(1)
    end
  end

  describe 'soft deletion' do
    let(:application) { create(:insurance_application, organization: organization, user: user, client: client) }

    it 'soft deletes the application' do
      application.discard
      expect(application.discarded?).to be_truthy
      expect(InsuranceApplication.kept).not_to include(application)
      expect(InsuranceApplication.discarded).to include(application)
    end

    it 'can be undiscarded' do
      application.discard
      application.undiscard
      expect(application.discarded?).to be_falsey
      expect(InsuranceApplication.kept).to include(application)
    end
  end
end
