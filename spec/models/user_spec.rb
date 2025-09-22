require "rails_helper"

RSpec.describe User, type: :model do
  describe "enums" do
    it "defines role enum correctly" do
      expect(User.defined_enums['role']).to eq({
        'super_admin' => 0,
        'brokerage_admin' => 1,
        'agent' => 2,
        'insurance_company' => 3
      })
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:role) }
  end

  describe "enum behavior" do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, organization: organization, role: :agent) }

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
      org = create(:organization)
      u1 = create(:user, organization: org, role: :super_admin)
      _u2 = create(:user, organization: org, role: :agent)
      expect(User.super_admin).to contain_exactly(u1)
    end
  end
end
