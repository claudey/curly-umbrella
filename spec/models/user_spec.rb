require "rails_helper"

RSpec.describe User, type: :model do
  describe "enums" do
    it do
      expect(described_class).to define_enum_for(:role)
        .with_values(
          super_admin: 0,
          brokerage_admin: 1,
          agent: 2,
          insurance_company: 3
        )
        .backed_by_column_of_type(:integer)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:role) }
  end

  describe "enum behavior" do
    let(:organization) { Organization.create!(name: "Org") }
    let(:user) do
      described_class.new(
        first_name: "A",
        last_name: "B",
        phone: "123",
        email: "a@example.com",
        password: "password",
        organization: organization,
        role: :agent
      )
    end

    it "sets and queries via symbols" do
      expect(user.role).to eq("agent")
      expect(user.agent?).to be true
      user.brokerage_admin!
      expect(user.role).to eq("brokerage_admin")
      expect(user.brokerage_admin?).to be true
    end

    it "raises on invalid value" do
      expect { user.role = :unknown }.to raise_error(ArgumentError)
    end
  end

  describe "scopes" do
    it "returns only matching roles" do
      org = Organization.create!(name: "Org")
      u1 = described_class.create!(first_name: "S", last_name: "A", phone: "1", email: "s@example.com", password: "password", organization: org, role: :super_admin)
      _u2 = described_class.create!(first_name: "A", last_name: "G", phone: "2", email: "a@example.com", password: "password", organization: org, role: :agent)
      expect(User.super_admin).to contain_exactly(u1)
    end
  end
end


