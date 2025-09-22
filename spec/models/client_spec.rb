require 'rails_helper'

RSpec.describe Client, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:organization) }
  end

  describe "validations" do
    subject { create(:client) }
    
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:date_of_birth) }
    it { is_expected.to validate_uniqueness_of(:email).scoped_to(:organization_id).case_insensitive }
    it { is_expected.to validate_length_of(:first_name).is_at_least(2).is_at_most(50) }
    it { is_expected.to validate_length_of(:last_name).is_at_least(2).is_at_most(50) }
  end

  describe "age calculation" do
    it "calculates age correctly" do
      client = create(:client, date_of_birth: 30.years.ago)
      expect(client.age).to eq(30)
    end

    it "handles future date of birth" do
      client = create(:client, date_of_birth: 1.year.from_now)
      expect(client.age).to be <= 0
    end
  end

  describe "full_name method" do
    it "returns combined first and last name" do
      client = create(:client, first_name: "John", last_name: "Doe")
      expect(client.full_name).to eq("John Doe")
    end
  end

  describe "scopes" do
    let(:organization) { create(:organization) }
    
    it "searches by name" do
      client = create(:client, organization: organization, first_name: "John", last_name: "Doe")
      
      expect(Client.by_name("John")).to include(client)
      expect(Client.by_name("Doe")).to include(client)
      expect(Client.by_name("Smith")).not_to include(client)
    end

    it "searches by email" do
      client = create(:client, organization: organization, email: "john@example.com")
      
      expect(Client.by_email("john@example.com")).to include(client)
      expect(Client.by_email("smith@example.com")).not_to include(client)
    end
  end

  describe "contact methods" do
    it "returns primary contact based on preference" do
      client = create(:client, email: "test@example.com", phone: "123456789", preferred_contact_method: "email")
      expect(client.primary_contact).to eq("test@example.com")
      
      client.update(preferred_contact_method: "phone")
      expect(client.primary_contact).to eq("123456789")
    end
  end
end