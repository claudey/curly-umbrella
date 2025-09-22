require 'rails_helper'

RSpec.describe FeatureFlag, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  describe 'associations' do
    it { should belong_to(:organization).optional }
    it { should belong_to(:created_by).class_name('User').optional }
    it { should belong_to(:updated_by).class_name('User').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:key) }
    it { should validate_presence_of(:name) }
    it { should validate_inclusion_of(:percentage).in_range(0..100).allow_nil }

    it 'validates uniqueness of key scoped to organization' do
      create(:feature_flag, key: 'test_flag', organization: organization)
      new_flag = build(:feature_flag, key: 'test_flag', organization: organization)
      
      expect(new_flag).to_not be_valid
      expect(new_flag.errors[:key]).to include('has already been taken')
    end

    it 'allows same key in different organizations' do
      other_org = create(:organization)
      create(:feature_flag, key: 'test_flag', organization: organization)
      new_flag = build(:feature_flag, key: 'test_flag', organization: other_org)
      
      expect(new_flag).to be_valid
    end
  end

  describe 'scopes' do
    let!(:enabled_flag) { create(:feature_flag, enabled: true) }
    let!(:disabled_flag) { create(:feature_flag, enabled: false) }

    it 'filters enabled flags' do
      expect(FeatureFlag.enabled).to include(enabled_flag)
      expect(FeatureFlag.enabled).to_not include(disabled_flag)
    end

    it 'filters disabled flags' do
      expect(FeatureFlag.disabled).to include(disabled_flag)
      expect(FeatureFlag.disabled).to_not include(enabled_flag)
    end
  end

  describe 'callbacks' do
    it 'sets defaults on creation' do
      flag = create(:feature_flag)
      
      expect(flag.enabled).to be false
      expect(flag.user_groups).to eq([])
      expect(flag.conditions).to eq({})
      expect(flag.metadata).to eq({})
    end

    it 'handles nil percentage correctly' do
      flag = create(:feature_flag, percentage: 0)
      expect(flag.percentage).to be_nil
    end
  end

  describe '#enabled_for?' do
    let(:flag) { create(:feature_flag, enabled: true) }

    context 'when flag is disabled' do
      it 'returns false' do
        flag.update!(enabled: false)
        expect(flag.enabled_for?(user)).to be false
      end
    end

    context 'with percentage rollout' do
      it 'returns true for 100% rollout' do
        flag.update!(percentage: 100)
        expect(flag.enabled_for?(user)).to be true
      end

      it 'returns false for 0% rollout' do
        flag.update!(percentage: 0)
        flag.reload  # Reload to see the callback effect
        expect(flag.enabled_for?(user)).to be false
      end

      it 'uses consistent hash for percentage calculation' do
        flag.update!(percentage: 50)
        result1 = flag.enabled_for?(user)
        result2 = flag.enabled_for?(user)
        
        expect(result1).to eq(result2)
      end
    end

    context 'with user groups' do
      before do
        # Mock the groups association for testing
        allow(user).to receive(:groups).and_return(double(pluck: ->(attr) { 
          attr == :name ? ['beta_users'] : []
        }))
      end

      it 'returns true when no user groups specified (empty array)' do
        flag.update!(user_groups: [])
        expect(flag.enabled_for?(user)).to be true
      end

      it 'returns true when user is in allowed group' do
        flag.update!(user_groups: ['beta_users'])
        expect(flag.enabled_for?(user)).to be true
      end

      it 'returns false when user is not in allowed group' do
        allow(user).to receive(:groups).and_return(double(pluck: ->(attr) { 
          attr == :name ? ['admin_users'] : []
        }))
        
        flag.update!(user_groups: ['beta_users'])
        expect(flag.enabled_for?(user)).to be false
      end
    end

    context 'with custom conditions' do
      it 'evaluates role condition correctly' do
        flag.update!(conditions: { 'role' => 'agent' })
        user.update!(role: 'agent')
        
        expect(flag.enabled_for?(user)).to be true
      end

      it 'evaluates email domain condition correctly' do
        flag.update!(conditions: { 'email_domain' => 'example.com' })
        user.update!(email: 'test@example.com')
        
        expect(flag.enabled_for?(user)).to be true
      end

      it 'evaluates created_after condition correctly' do
        flag.update!(conditions: { 'created_after' => 1.year.ago.to_date.to_s })
        
        expect(flag.enabled_for?(user)).to be true
      end

      it 'evaluates context condition correctly' do
        flag.update!(conditions: { 'context' => { 'feature' => 'premium' } })
        context = { feature: 'premium' }
        
        expect(flag.enabled_for?(user, context)).to be true
      end

      it 'returns false when conditions are not met' do
        flag.update!(conditions: { 'role' => 'admin' })
        user.update!(role: 'agent')
        
        expect(flag.enabled_for?(user)).to be false
      end
    end
  end

  describe '#enabled_percentage' do
    it 'returns percentage when set' do
      flag = create(:feature_flag, percentage: 75)
      expect(flag.enabled_percentage).to eq(75)
    end

    it 'returns 100 when enabled and no percentage set' do
      flag = create(:feature_flag, enabled: true, percentage: nil)
      expect(flag.enabled_percentage).to eq(100)
    end

    it 'returns 0 when disabled and no percentage set' do
      flag = create(:feature_flag, enabled: false, percentage: nil)
      expect(flag.enabled_percentage).to eq(0)
    end
  end

  describe '#toggle!' do
    it 'toggles enabled state' do
      flag = create(:feature_flag, enabled: false)
      
      flag.toggle!
      expect(flag.enabled?).to be true
      
      flag.toggle!
      expect(flag.enabled?).to be false
    end
  end

  describe '.enabled?' do
    let!(:flag) { create(:feature_flag, key: 'test_feature', enabled: true) }

    it 'returns true for enabled flag without user' do
      expect(FeatureFlag.enabled?('test_feature')).to be true
    end

    it 'returns false for disabled flag without user' do
      flag.update!(enabled: false)
      expect(FeatureFlag.enabled?('test_feature')).to be false
    end

    it 'returns false for non-existent flag' do
      expect(FeatureFlag.enabled?('non_existent')).to be false
    end

    it 'evaluates flag for specific user' do
      flag.update!(percentage: 100)
      expect(FeatureFlag.enabled?('test_feature', user)).to be true
    end

    it 'passes context to flag evaluation' do
      flag.update!(conditions: { 'context' => { 'plan' => 'premium' } })
      context = { plan: 'premium' }
      
      expect(FeatureFlag.enabled?('test_feature', user, context)).to be true
    end
  end

  describe '.create_or_update_flag' do
    it 'creates new flag when it does not exist' do
      expect {
        FeatureFlag.create_or_update_flag('new_feature', name: 'New Feature', enabled: true)
      }.to change(FeatureFlag, :count).by(1)
      
      flag = FeatureFlag.find_by(key: 'new_feature')
      expect(flag.name).to eq('New Feature')
      expect(flag.enabled?).to be true
    end

    it 'updates existing flag' do
      existing_flag = create(:feature_flag, key: 'existing_feature', enabled: false)
      
      FeatureFlag.create_or_update_flag('existing_feature', enabled: true, percentage: 50)
      
      existing_flag.reload
      expect(existing_flag.enabled?).to be true
      expect(existing_flag.percentage).to eq(50)
    end
  end

  describe 'percentage rollout calculation' do
    let(:flag) { create(:feature_flag, key: 'test_rollout', enabled: true, percentage: 30) }

    it 'distributes users consistently based on hash' do
      users = create_list(:user, 100, organization: organization)
      enabled_count = users.count { |u| flag.enabled_for?(u) }
      
      # Should be roughly 30% (allowing for some variance due to hashing)
      expect(enabled_count).to be_between(20, 40)
    end

    it 'maintains consistency across multiple calls' do
      results = Array.new(10) { flag.enabled_for?(user) }
      expect(results.uniq.size).to eq(1) # All results should be the same
    end
  end

  describe 'serialization' do
    it 'serializes user_groups as JSON array' do
      flag = create(:feature_flag, user_groups: ['admins', 'beta_users'])
      flag.reload
      
      expect(flag.user_groups).to eq(['admins', 'beta_users'])
      expect(flag.user_groups).to be_a(Array)
    end

    it 'serializes conditions as JSON hash' do
      conditions = { 'role' => 'admin', 'email_domain' => 'company.com' }
      flag = create(:feature_flag, conditions: conditions)
      flag.reload
      
      expect(flag.conditions).to eq(conditions)
      expect(flag.conditions).to be_a(Hash)
    end
  end
end
