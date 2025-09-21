require 'rails_helper'

RSpec.describe "Basic Model Functionality", type: :model do
  describe Organization do
    it "creates organization successfully" do
      org = create(:organization)
      expect(org).to be_persisted
      expect(org.name).to be_present
    end

    it "validates required fields" do
      org = build(:organization, name: nil)
      expect(org).not_to be_valid
      expect(org.errors[:name]).to include("can't be blank")
    end
  end

  describe User do
    it "creates user successfully" do
      org = create(:organization)
      user = create(:user, organization: org)
      expect(user).to be_persisted
      expect(user.organization).to eq(org)
    end

    it "validates email format" do
      user = build(:user, email: "invalid_email")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it "has default role" do
      user = create(:user)
      expect(user.role).to eq('agent')
    end
  end

  describe Client do
    it "creates client successfully" do
      org = create(:organization)
      client = create(:client, organization: org)
      expect(client).to be_persisted
      expect(client.organization).to eq(org)
    end

    it "validates required fields" do
      client = build(:client, first_name: nil)
      expect(client).not_to be_valid
      expect(client.errors[:first_name]).to include("can't be blank")
    end

    it "calculates age correctly" do
      client = create(:client, date_of_birth: 30.years.ago)
      expect(client.age).to eq(30)
    end
  end

  describe InsuranceApplication do
    it "creates application successfully" do
      org = create(:organization)
      client = create(:client, organization: org)
      application = create(:insurance_application,
        client: client,
        organization: org,
        insurance_type: 'motor'
      )
      expect(application).to be_persisted
      expect(application.client).to eq(client)
    end

    it "generates application number" do
      application = create(:insurance_application, insurance_type: 'motor')
      expect(application.application_number).to be_present
      expect(application.application_number).to start_with('MI')
    end

    it "has default status" do
      application = create(:insurance_application)
      expect(application.status).to eq('draft')
    end
  end


  describe Document do
    it "creates document successfully without file" do
      org = create(:organization)
      user = create(:user, organization: org)

      # Skip file validation for basic testing
      allow_any_instance_of(Document).to receive(:file_attached?).and_return(true)
      allow_any_instance_of(Document).to receive(:set_file_metadata).and_return(true)
      allow_any_instance_of(Document).to receive(:set_checksum).and_return(true)

      document = create(:document, organization: org, user: user)
      expect(document).to be_persisted
      expect(document.organization).to eq(org)
    end

    it "validates name presence" do
      document = build(:document, name: nil)
      expect(document).not_to be_valid
      expect(document.errors[:name]).to be_present
    end
  end
end
