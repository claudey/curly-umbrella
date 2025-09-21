require 'rails_helper'

RSpec.describe 'Security Tests', type: :security do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, organization: organization) }
  let(:agent_user) { create(:user, :agent, organization: organization) }
  let(:client) { create(:client, organization: organization) }

  before { ActsAsTenant.current_tenant = organization }
  after { ActsAsTenant.current_tenant = nil }

  describe 'Authentication Security' do
    context 'password security' do
      it 'enforces strong password requirements' do
        weak_passwords = [ '123456', 'password', 'abc123', 'qwerty' ]

        weak_passwords.each do |weak_password|
          user = build(:user, password: weak_password, password_confirmation: weak_password)
          expect(user).not_to be_valid
          expect(user.errors[:password]).to be_present
        end
      end

      it 'prevents password reuse' do
        user = create(:user, password: 'SecurePassword123!', password_confirmation: 'SecurePassword123!')

        # Try to set the same password again
        user.password = 'SecurePassword123!'
        user.password_confirmation = 'SecurePassword123!'
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include('cannot reuse recent passwords')
      end

      it 'enforces password expiration' do
        user = create(:user)
        user.update_column(:password_changed_at, 91.days.ago)

        expect(user.password_expired?).to be true
      end
    end

    context 'session security' do
      it 'invalidates sessions after password change' do
        user = create(:user)

        # Simulate active session
        session_token = SecureRandom.hex(32)
        user.update!(current_session_token: session_token)

        # Change password
        user.update!(password: 'NewSecurePassword123!', password_confirmation: 'NewSecurePassword123!')

        # Session token should be changed
        expect(user.current_session_token).not_to eq(session_token)
      end

      it 'limits concurrent sessions' do
        user = create(:user)

        # Simulate multiple login attempts
        5.times do
          user.update!(current_session_token: SecureRandom.hex(32))
        end

        # Should track and limit sessions
        expect(user.active_sessions.count).to be <= 3 # Assuming max 3 sessions
      end
    end

    context 'multi-factor authentication' do
      let(:user_with_mfa) { create(:user, :with_mfa) }

      it 'requires MFA for sensitive operations' do
        sign_in user_with_mfa

        # Attempt sensitive operation without MFA verification
        patch "/users/#{user_with_mfa.id}/disable_mfa"
        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include('MFA verification required')
      end

      it 'validates TOTP codes correctly' do
        totp = ROTP::TOTP.new(user_with_mfa.mfa_secret)
        valid_code = totp.now
        invalid_code = '000000'

        # Valid code should work
        expect(user_with_mfa.verify_mfa_code(valid_code)).to be true

        # Invalid code should fail
        expect(user_with_mfa.verify_mfa_code(invalid_code)).to be false
      end

      it 'prevents TOTP replay attacks' do
        totp = ROTP::TOTP.new(user_with_mfa.mfa_secret)
        valid_code = totp.now

        # First use should work
        expect(user_with_mfa.verify_mfa_code(valid_code)).to be true

        # Second use of same code should fail
        expect(user_with_mfa.verify_mfa_code(valid_code)).to be false
      end
    end
  end

  describe 'Authorization Security' do
    context 'role-based access control' do
      it 'prevents privilege escalation' do
        sign_in agent_user

        # Agent tries to access admin-only function
        get '/admin/organizations'
        expect(response).to have_http_status(:forbidden)
      end

      it 'enforces organization boundaries' do
        other_organization = create(:organization)
        other_user = create(:user, organization: other_organization)
        other_application = create(:insurance_application, organization: other_organization, user: other_user)

        sign_in agent_user

        # Try to access application from different organization
        get "/insurance_applications/#{other_application.id}"
        expect(response).to have_http_status(:not_found)
      end

      it 'validates resource ownership' do
        other_agent = create(:user, :agent, organization: organization)
        other_application = create(:insurance_application, organization: organization, user: other_agent, client: client)

        sign_in agent_user

        # Agent tries to modify another agent's application
        patch "/insurance_applications/#{other_application.id}", params: {
          insurance_application: { first_name: 'Hacked' }
        }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'API security' do
      let(:api_key) { create(:api_key, organization: organization, user: agent_user) }
      let(:valid_headers) { { 'Authorization' => "Bearer #{api_key.key}" } }

      it 'validates API key format' do
        invalid_headers = { 'Authorization' => 'Bearer invalid_key_format' }

        get '/api/v1/applications', headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'enforces API rate limiting' do
        # Exceed rate limit
        51.times do
          get '/api/v1/applications', headers: valid_headers
        end

        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers['Retry-After']).to be_present
      end

      it 'prevents API key enumeration' do
        # Try random API keys - should not reveal information about format
        100.times do
          random_key = SecureRandom.hex(32)
          headers = { 'Authorization' => "Bearer #{random_key}" }

          get '/api/v1/applications', headers: headers
          expect(response).to have_http_status(:unauthorized)
          expect(response.body).not_to include('invalid format')
        end
      end
    end
  end

  describe 'Input Validation Security' do
    context 'SQL injection prevention' do
      it 'safely handles malicious SQL in search parameters' do
        malicious_inputs = [
          "'; DROP TABLE insurance_applications; --",
          "' OR '1'='1",
          "' UNION SELECT * FROM users --",
          "'; INSERT INTO users (email) VALUES ('hacker@evil.com'); --"
        ]

        sign_in agent_user

        malicious_inputs.each do |malicious_input|
          get "/insurance_applications?search=#{CGI.escape(malicious_input)}"

          # Should not cause errors or return unauthorized data
          expect(response).to have_http_status(:ok)
          expect(InsuranceApplication.count).to be >= 0 # Table should still exist
        end
      end

      it 'sanitizes dynamic query parameters' do
        application = create(:insurance_application, organization: organization, user: agent_user, client: client)

        # Try SQL injection in sort parameter
        sign_in agent_user
        get "/insurance_applications?sort=created_at; DROP TABLE insurance_applications; --"

        expect(response).to have_http_status(:ok)
        expect(InsuranceApplication.exists?(application.id)).to be true
      end
    end

    context 'XSS prevention' do
      it 'escapes malicious scripts in user input' do
        malicious_scripts = [
          '<script>alert("XSS")</script>',
          '<img src="x" onerror="alert(1)">',
          'javascript:alert("XSS")',
          '<svg onload="alert(1)">'
        ]

        malicious_scripts.each do |script|
          application = build(:insurance_application,
                             first_name: script,
                             organization: organization,
                             user: agent_user,
                             client: client)

          expect(application).not_to be_valid
          expect(application.errors[:first_name]).to include('contains invalid characters')
        end
      end

      it 'sanitizes HTML in rich text fields' do
        malicious_html = '<script>alert("XSS")</script><p>Valid content</p>'

        application = create(:insurance_application, organization: organization, user: agent_user, client: client)
        application.update(notes: malicious_html)

        # HTML should be sanitized
        expect(application.notes).not_to include('<script>')
        expect(application.notes).to include('Valid content')
      end
    end

    context 'file upload security' do
      it 'validates file types and content' do
        malicious_files = [
          { filename: 'malware.exe', content_type: 'application/x-executable' },
          { filename: 'script.php', content_type: 'application/x-php' },
          { filename: 'image.jpg', content_type: 'image/jpeg', content: '<?php eval($_POST["cmd"]); ?>' }
        ]

        application = create(:insurance_application, organization: organization, user: agent_user, client: client)

        malicious_files.each do |file_info|
          document = build(:document,
                          documentable: application,
                          organization: organization,
                          user: agent_user)

          # Should reject malicious files
          expect(document.valid_file_type?(file_info[:content_type])).to be false
        end
      end

      it 'scans uploaded files for malware signatures' do
        # Simulate EICAR test string (harmless malware test signature)
        eicar_string = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

        document = build(:document, organization: organization, user: agent_user)

        # Should detect and reject malware signature
        expect(document.contains_malware?(eicar_string)).to be true
      end
    end
  end

  describe 'Data Protection Security' do
    context 'sensitive data encryption' do
      it 'encrypts PII fields at rest' do
        application = create(:insurance_application,
                           ssn: '123-45-6789',
                           organization: organization,
                           user: agent_user,
                           client: client)

        # Check database directly to ensure encryption
        raw_data = ActiveRecord::Base.connection.execute(
          "SELECT ssn FROM insurance_applications WHERE id = #{application.id}"
        ).first

        # SSN should be encrypted in database
        expect(raw_data['ssn']).not_to eq('123-45-6789')
        expect(raw_data['ssn']).to be_present # But should have encrypted value

        # Should decrypt properly when accessed through model
        expect(application.ssn).to eq('123-45-6789')
      end

      it 'masks sensitive data in logs' do
        # Capture log output
        log_output = StringIO.new
        Rails.logger = Logger.new(log_output)

        application = create(:insurance_application,
                           ssn: '123-45-6789',
                           organization: organization,
                           user: agent_user,
                           client: client)

        # SSN should not appear in logs
        expect(log_output.string).not_to include('123-45-6789')
        expect(log_output.string).to include('***') if log_output.string.include?('ssn')
      end
    end

    context 'audit trail security' do
      it 'creates immutable audit records' do
        application = create(:insurance_application, organization: organization, user: agent_user, client: client)
        audit = application.audits.first

        # Try to modify audit record
        expect {
          audit.update!(audited_changes: { 'hacked' => true })
        }.to raise_error(ActiveRecord::ReadOnlyRecord)
      end

      it 'tracks all sensitive operations' do
        application = create(:insurance_application, organization: organization, user: agent_user, client: client)

        # Perform sensitive operation
        application.update!(status: 'approved', approved_by: admin_user)

        # Should create audit record
        audit = application.audits.last
        expect(audit.action).to eq('update')
        expect(audit.user).to eq(admin_user)
        expect(audit.audited_changes).to include('status')
      end
    end
  end

  describe 'Communication Security' do
    context 'HTTPS enforcement' do
      it 'redirects HTTP to HTTPS in production' do
        # Simulate production environment
        allow(Rails.env).to receive(:production?).and_return(true)

        get 'http://test.host/insurance_applications'
        expect(response).to redirect_to(/^https:/)
      end

      it 'sets secure headers' do
        get '/insurance_applications'

        expect(response.headers['X-Frame-Options']).to eq('DENY')
        expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
        expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
        expect(response.headers['Strict-Transport-Security']).to be_present
      end
    end

    context 'CSRF protection' do
      it 'requires CSRF token for state-changing requests' do
        # Attempt POST without CSRF token
        post '/insurance_applications', params: {
          insurance_application: { first_name: 'Test' }
        }

        expect(response).to have_http_status(:forbidden)
      end

      it 'validates CSRF token authenticity' do
        sign_in agent_user

        # Post with invalid CSRF token
        post '/insurance_applications',
             params: { insurance_application: { first_name: 'Test' } },
             headers: { 'X-CSRF-Token' => 'invalid_token' }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'Error Handling Security' do
    context 'information disclosure prevention' do
      it 'does not expose sensitive information in error messages' do
        # Trigger database error
        allow(InsuranceApplication).to receive(:find).and_raise(ActiveRecord::StatementInvalid.new('connection failed'))

        sign_in agent_user
        get '/insurance_applications/1'

        # Should not expose database details
        expect(response.body).not_to include('connection failed')
        expect(response.body).not_to include('ActiveRecord::StatementInvalid')
        expect(response.body).to include('Something went wrong')
      end

      it 'logs security events for monitoring' do
        # Capture security logs
        security_logs = []
        allow(SecurityLogger).to receive(:log) { |event| security_logs << event }

        # Attempt unauthorized access
        get '/admin/organizations'

        # Should log security event
        expect(security_logs).not_to be_empty
        expect(security_logs.last[:event_type]).to eq('unauthorized_access_attempt')
      end
    end
  end

  describe 'Dependency Security' do
    it 'does not have known vulnerable dependencies' do
      # Run bundle audit programmatically
      require 'bundler/audit/cli'

      cli = Bundler::Audit::CLI.new
      output = capture(:stdout) { cli.check }

      # Should not have vulnerabilities
      expect(output).not_to include('Vulnerabilities found!')
      expect(output).to include('No vulnerabilities found') || include('0 vulnerabilities found')
    end
  end

  describe 'Infrastructure Security' do
    context 'environment configuration' do
      it 'does not expose sensitive configuration' do
        # Check that secrets are not in environment variables
        expect(ENV['DATABASE_PASSWORD']).to be_nil
        expect(ENV['SECRET_KEY_BASE']).to be_nil
        expect(ENV['API_SECRET']).to be_nil

        # Should use Rails credentials instead
        expect(Rails.application.credentials.secret_key_base).to be_present
      end

      it 'validates SSL/TLS configuration' do
        # Check SSL settings
        expect(Rails.application.config.force_ssl).to be true if Rails.env.production?
        expect(Rails.application.config.ssl_options).to include(secure: true) if Rails.env.production?
      end
    end
  end

  private

  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end
    result
  end
end
