require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe 'validations' do
    it 'validates presence of name' do
      org = Organization.new
      expect(org.valid?).to be false
      expect(org.errors[:name]).to include("can't be blank")
    end
    
    it 'validates presence of license_number' do
      org = Organization.new(name: 'Test Org')
      expect(org.valid?).to be false
      expect(org.errors[:license_number]).to include("can't be blank")
    end
  end
  
  describe 'associations' do
    it 'has many users' do
      expect(Organization.new).to respond_to(:users)
    end
    
    it 'has many insurance_applications' do
      expect(Organization.new).to respond_to(:insurance_applications)
    end
  end
  
  describe 'creating an organization' do
    it 'can create a valid organization' do
      org = Organization.create!(
        name: 'Test Organization',
        license_number: 'LIC123456'
      )
      
      expect(org).to be_persisted
      expect(org.name).to eq('Test Organization')
    end
  end
end