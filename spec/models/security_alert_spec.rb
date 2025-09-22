require 'rails_helper'

RSpec.describe SecurityAlert, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:resolved_by).class_name('User').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:alert_type) }
    it { should validate_presence_of(:message) }
    it { should validate_presence_of(:severity) }
    it { should validate_inclusion_of(:severity).in_array(%w[low medium high critical]) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[active investigating resolved dismissed]) }
    it { should validate_presence_of(:triggered_at) }
  end

  describe 'enums' do
    it 'defines severity enum correctly' do
      expect(SecurityAlert.severities.keys).to contain_exactly('low', 'medium', 'high', 'critical')
    end

    it 'defines status enum correctly' do
      expect(SecurityAlert.statuses.keys).to contain_exactly('active', 'investigating', 'resolved', 'dismissed')
    end

    it 'defines alert_type enum correctly' do
      expected_types = %w[
        multiple_failed_logins suspicious_ip_activity rapid_user_activity
        unusual_login_location new_login_location concurrent_sessions
        unauthorized_access_attempt privilege_escalation_attempt bulk_data_access
        brute_force_attack ip_user_anomaly activity_spike off_hours_activity
        unusual_login_time
      ]
      expect(SecurityAlert.alert_types.keys).to contain_exactly(*expected_types)
    end
  end

  describe 'scopes' do
    let!(:recent_alert) { create(:security_alert, organization: organization, triggered_at: 1.hour.ago) }
    let!(:old_alert) { create(:security_alert, organization: organization, triggered_at: 1.week.ago) }
    let!(:active_alert) { create(:security_alert, organization: organization, status: 'active') }
    let!(:resolved_alert) { create(:security_alert, organization: organization, status: 'resolved') }
    let!(:critical_alert) { create(:security_alert, organization: organization, severity: 'critical') }
    let!(:low_alert) { create(:security_alert, organization: organization, severity: 'low') }

    it 'orders by most recent first' do
      alerts = SecurityAlert.recent
      expect(alerts.first).to eq(recent_alert)
      expect(alerts.last).to eq(old_alert)
    end

    it 'filters unresolved alerts' do
      unresolved = SecurityAlert.unresolved
      expect(unresolved).to include(active_alert)
      expect(unresolved).to_not include(resolved_alert)
    end

    it 'filters critical alerts' do
      critical = SecurityAlert.critical_alerts
      expect(critical).to include(critical_alert)
      expect(critical).to_not include(low_alert)
    end

    it 'filters alerts for organization' do
      other_org = create(:organization)
      other_alert = create(:security_alert, organization: other_org)
      
      org_alerts = SecurityAlert.for_organization(organization)
      expect(org_alerts).to include(recent_alert)
      expect(org_alerts).to_not include(other_alert)
    end
  end

  describe 'status management methods' do
    let(:alert) { create(:security_alert, organization: organization, status: 'active') }
    let(:resolver) { create(:user, organization: organization) }

    describe '#resolve!' do
      it 'resolves alert with notes' do
        notes = "Issue was a false positive"
        
        alert.resolve!(resolver, notes)
        
        expect(alert.status).to eq('resolved')
        expect(alert.resolved_by).to eq(resolver)
        expect(alert.resolved_at).to be_present
        expect(alert.resolution_notes).to eq(notes)
      end

      it 'resolves alert without notes' do
        alert.resolve!(resolver)
        
        expect(alert.status).to eq('resolved')
        expect(alert.resolved_by).to eq(resolver)
        expect(alert.resolved_at).to be_present
        expect(alert.resolution_notes).to be_nil
      end
    end

    describe '#dismiss!' do
      it 'dismisses alert with reason' do
        reason = "Known behavior"
        
        alert.dismiss!(resolver, reason)
        
        expect(alert.status).to eq('dismissed')
        expect(alert.resolved_by).to eq(resolver)
        expect(alert.resolved_at).to be_present
        expect(alert.resolution_notes).to eq(reason)
      end
    end

    describe '#investigate!' do
      it 'marks alert as under investigation' do
        alert.investigate!(resolver)
        
        expect(alert.status).to eq('investigating')
        expect(alert.resolved_by).to eq(resolver)
        expect(alert.resolved_at).to be_nil
      end
    end
  end

  describe 'severity and status styling methods' do
    describe '#severity_color' do
      it 'returns correct colors for each severity' do
        low_alert = build(:security_alert, severity: 'low')
        medium_alert = build(:security_alert, severity: 'medium')
        high_alert = build(:security_alert, severity: 'high')
        critical_alert = build(:security_alert, severity: 'critical')

        expect(low_alert.severity_color).to eq('text-blue-600')
        expect(medium_alert.severity_color).to eq('text-yellow-600')
        expect(high_alert.severity_color).to eq('text-orange-600')
        expect(critical_alert.severity_color).to eq('text-red-600')
      end
    end

    describe '#severity_badge_class' do
      it 'returns correct badge classes for each severity' do
        low_alert = build(:security_alert, severity: 'low')
        medium_alert = build(:security_alert, severity: 'medium')
        high_alert = build(:security_alert, severity: 'high')
        critical_alert = build(:security_alert, severity: 'critical')

        expect(low_alert.severity_badge_class).to eq('bg-blue-100 text-blue-800')
        expect(medium_alert.severity_badge_class).to eq('bg-yellow-100 text-yellow-800')
        expect(high_alert.severity_badge_class).to eq('bg-orange-100 text-orange-800')
        expect(critical_alert.severity_badge_class).to eq('bg-red-100 text-red-800')
      end
    end

    describe '#status_badge_class' do
      it 'returns correct badge classes for each status' do
        active_alert = build(:security_alert, status: 'active')
        investigating_alert = build(:security_alert, status: 'investigating')
        resolved_alert = build(:security_alert, status: 'resolved')
        dismissed_alert = build(:security_alert, status: 'dismissed')

        expect(active_alert.status_badge_class).to eq('bg-red-100 text-red-800')
        expect(investigating_alert.status_badge_class).to eq('bg-yellow-100 text-yellow-800')
        expect(resolved_alert.status_badge_class).to eq('bg-green-100 text-green-800')
        expect(dismissed_alert.status_badge_class).to eq('bg-gray-100 text-gray-800')
      end
    end
  end

  describe 'data extraction methods' do
    describe '#affected_user' do
      it 'returns user when user_id is in data' do
        alert = create(:security_alert, organization: organization, data: { 'user_id' => user.id })
        expect(alert.affected_user).to eq(user)
      end

      it 'returns user when nested user data is present' do
        alert = create(:security_alert, organization: organization, data: { 'user' => { 'id' => user.id } })
        expect(alert.affected_user).to eq(user)
      end

      it 'returns nil when no user data present' do
        alert = create(:security_alert, organization: organization, data: {})
        expect(alert.affected_user).to be_nil
      end

      it 'returns nil when data is not a hash' do
        alert = create(:security_alert, organization: organization, data: 'not a hash')
        expect(alert.affected_user).to be_nil
      end
    end

    describe '#ip_address' do
      it 'returns IP address from data' do
        ip = '192.168.1.1'
        alert = create(:security_alert, organization: organization, data: { 'ip_address' => ip })
        expect(alert.ip_address).to eq(ip)
      end

      it 'returns nil when IP address not present' do
        alert = create(:security_alert, organization: organization, data: {})
        expect(alert.ip_address).to be_nil
      end
    end
  end

  describe 'classification methods' do
    describe '#auto_resolvable?' do
      it 'returns true for auto-resolvable alert types' do
        off_hours = build(:security_alert, alert_type: 'off_hours_activity')
        unusual_time = build(:security_alert, alert_type: 'unusual_login_time')

        expect(off_hours.auto_resolvable?).to be true
        expect(unusual_time.auto_resolvable?).to be true
      end

      it 'returns false for non-auto-resolvable alert types' do
        brute_force = build(:security_alert, alert_type: 'brute_force_attack')
        expect(brute_force.auto_resolvable?).to be false
      end
    end

    describe '#requires_immediate_action?' do
      it 'returns true for critical alerts requiring immediate action' do
        brute_force = build(:security_alert, alert_type: 'brute_force_attack', severity: 'critical')
        privilege_escalation = build(:security_alert, alert_type: 'privilege_escalation_attempt', severity: 'critical')

        expect(brute_force.requires_immediate_action?).to be true
        expect(privilege_escalation.requires_immediate_action?).to be true
      end

      it 'returns false for non-critical alerts' do
        brute_force = build(:security_alert, alert_type: 'brute_force_attack', severity: 'medium')
        expect(brute_force.requires_immediate_action?).to be false
      end

      it 'returns false for critical alerts not requiring immediate action' do
        suspicious_ip = build(:security_alert, alert_type: 'suspicious_ip_activity', severity: 'critical')
        expect(suspicious_ip.requires_immediate_action?).to be false
      end
    end
  end

  describe '#time_since_triggered' do
    it 'returns time elapsed since trigger' do
      alert = create(:security_alert, organization: organization, triggered_at: 2.hours.ago)
      
      expect(alert.time_since_triggered).to be_within(1.minute).of(2.hours)
    end

    it 'returns nil when triggered_at is nil' do
      alert = build(:security_alert, triggered_at: nil)
      expect(alert.time_since_triggered).to be_nil
    end
  end

  describe '#formatted_data' do
    it 'formats user data correctly' do
      data = { 'user' => { 'name' => 'John Doe', 'email' => 'john@example.com' } }
      alert = create(:security_alert, organization: organization, data: data)
      
      formatted = alert.formatted_data
      expect(formatted['User']).to eq('John Doe (john@example.com)')
    end

    it 'formats IP address correctly' do
      data = { 'ip_address' => '192.168.1.1' }
      alert = create(:security_alert, organization: organization, data: data)
      
      formatted = alert.formatted_data
      expect(formatted['IP Address']).to eq('192.168.1.1')
    end

    it 'formats count fields correctly' do
      data = { 'attempt_count' => 5, 'access_count' => 10 }
      alert = create(:security_alert, organization: organization, data: data)
      
      formatted = alert.formatted_data
      expect(formatted['Attempt count']).to eq(5)
      expect(formatted['Access count']).to eq(10)
    end

    it 'humanizes other field names' do
      data = { 'current_hour' => 23, 'typical_hours' => [9, 10, 11] }
      alert = create(:security_alert, organization: organization, data: data)
      
      formatted = alert.formatted_data
      expect(formatted['Current hour']).to eq(23)
      expect(formatted['Typical hours']).to eq([9, 10, 11])
    end

    it 'returns empty hash when data is not a hash' do
      alert = create(:security_alert, organization: organization, data: 'not a hash')
      expect(alert.formatted_data).to eq({})
    end
  end

  describe 'class methods' do
    describe '.cleanup_old_alerts' do
      let!(:old_resolved) { create(:security_alert, organization: organization, status: 'resolved', triggered_at: 100.days.ago) }
      let!(:old_dismissed) { create(:security_alert, organization: organization, status: 'dismissed', triggered_at: 100.days.ago) }
      let!(:old_active) { create(:security_alert, organization: organization, status: 'active', triggered_at: 100.days.ago) }
      let!(:recent_resolved) { create(:security_alert, organization: organization, status: 'resolved', triggered_at: 30.days.ago) }

      it 'deletes old resolved and dismissed alerts' do
        expect {
          SecurityAlert.cleanup_old_alerts(90)
        }.to change(SecurityAlert, :count).by(-2)

        expect(SecurityAlert.exists?(old_resolved.id)).to be false
        expect(SecurityAlert.exists?(old_dismissed.id)).to be false
        expect(SecurityAlert.exists?(old_active.id)).to be true
        expect(SecurityAlert.exists?(recent_resolved.id)).to be true
      end
    end

    describe '.daily_summary' do
      let(:date) { Date.current }
      let!(:today_critical) { create(:security_alert, organization: organization, severity: 'critical', status: 'active', triggered_at: date.beginning_of_day + 1.hour) }
      let!(:today_medium) { create(:security_alert, organization: organization, severity: 'medium', status: 'resolved', triggered_at: date.beginning_of_day + 2.hours, resolved_at: date.beginning_of_day + 3.hours) }
      let!(:yesterday_alert) { create(:security_alert, organization: organization, triggered_at: 1.day.ago) }

      it 'returns daily summary for organization' do
        summary = SecurityAlert.daily_summary(organization, date)

        expect(summary[:total]).to eq(2)
        expect(summary[:by_severity]).to include('critical' => 1, 'medium' => 1)
        expect(summary[:by_status]).to include('active' => 1, 'resolved' => 1)
        expect(summary[:critical_unresolved]).to eq(1)
        expect(summary[:auto_resolved]).to eq(1)
      end

      it 'excludes alerts from other organizations' do
        other_org = create(:organization)
        create(:security_alert, organization: other_org, triggered_at: date.beginning_of_day + 1.hour)

        summary = SecurityAlert.daily_summary(organization, date)
        expect(summary[:total]).to eq(2) # Only alerts from the specified organization
      end
    end
  end

  describe 'factory creation' do
    it 'creates valid security alert' do
      alert = create(:security_alert, organization: organization)
      
      expect(alert).to be_valid
      expect(alert.organization).to eq(organization)
      expect(alert.triggered_at).to be_present
      expect(alert.status).to be_present
      expect(alert.severity).to be_present
      expect(alert.alert_type).to be_present
      expect(alert.message).to be_present
    end
  end
end
