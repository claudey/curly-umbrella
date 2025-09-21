require 'rails_helper'

RSpec.describe "Authentication", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, password: "password123456") }

  describe "User Authentication (Basic)" do
    it "allows valid user to login" do
      post user_session_path, params: { 
        user: { 
          email: user.email, 
          password: "password123456" 
        } 
      }
      
      expect(response).to redirect_to(root_path)
      expect(controller.current_user).to eq(user)
    end

    it "rejects invalid credentials" do
      post user_session_path, params: { 
        user: { 
          email: "invalid@example.com", 
          password: "wrong" 
        } 
      }
      
      expect(response).to render_template(:new)
      expect(flash[:alert]).to be_present
    end

    it "logs out user successfully" do
      sign_in user
      delete destroy_user_session_path
      
      expect(response).to redirect_to(root_path)
      expect(controller.current_user).to be_nil
    end

    it "redirects unauthenticated users to login" do
      get clients_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "handles remember me functionality" do
      post user_session_path, params: { 
        user: { 
          email: user.email, 
          password: "password123456",
          remember_me: "1"
        } 
      }
      
      expect(response).to redirect_to(root_path)
      expect(response.cookies["remember_user_token"]).to be_present
    end
  end

  describe "Multi-Factor Authentication (MFA)" do
    let(:user_with_mfa) { create(:user, mfa_enabled: false) }

    it "allows user to setup MFA" do
      sign_in user_with_mfa
      post enable_mfa_path
      
      user_with_mfa.reload
      expect(user_with_mfa.mfa_enabled?).to be true
      expect(user_with_mfa.mfa_secret).to be_present
      expect(user_with_mfa.backup_codes).to be_present
    end

    it "verifies TOTP codes correctly" do
      user_with_mfa.enable_mfa!
      totp = ROTP::TOTP.new(user_with_mfa.mfa_secret)
      valid_code = totp.now
      
      expect(user_with_mfa.verify_mfa_code(valid_code)).to be true
      expect(user_with_mfa.verify_mfa_code("123456")).to be false
    end

    it "accepts backup codes" do
      user_with_mfa.enable_mfa!
      backup_code = JSON.parse(user_with_mfa.backup_codes).first
      
      expect(user_with_mfa.verify_mfa_code(backup_code)).to be true
      user_with_mfa.reload
      expect(JSON.parse(user_with_mfa.backup_codes)).not_to include(backup_code)
    end

    it "requires MFA verification after login when enabled" do
      user_with_mfa.update!(mfa_enabled: true, mfa_secret: ROTP::Base32.random)
      
      post user_session_path, params: { 
        user: { 
          email: user_with_mfa.email, 
          password: "password123456" 
        } 
      }
      
      expect(response).to redirect_to(new_mfa_verification_path)
    end
  end

  describe "Session Security Management" do
    it "tracks session creation" do
      expect {
        sign_in user
      }.to change(UserSession, :count).by(1)
    end

    it "detects suspicious login locations" do
      # Mock different IP addresses
      allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return("192.168.1.1")
      sign_in user
      
      allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return("203.0.113.1")
      sign_in user
      
      expect(SecurityAlert.where(alert_type: 'new_login_location').count).to be > 0
    end

    it "limits concurrent sessions" do
      # Create max allowed sessions
      5.times do |i|
        UserSession.create!(
          user: user, 
          session_id: "session_#{i}", 
          ip_address: "192.168.1.#{i}"
        )
      end
      
      # Attempt to create another session
      new_session = UserSession.new(
        user: user, 
        session_id: "session_6", 
        ip_address: "192.168.1.6"
      )
      expect(new_session.save).to be false
    end

    it "terminates other user sessions" do
      # Create multiple sessions
      session1 = UserSession.create!(user: user, session_id: "session_1", ip_address: "192.168.1.1")
      session2 = UserSession.create!(user: user, session_id: "session_2", ip_address: "192.168.1.2")
      
      sign_in user
      delete terminate_other_sessions_path
      
      expect(UserSession.where(id: [session1.id, session2.id])).to be_empty
    end
  end

  describe "Rate Limiting & IP Blocking" do
    it "blocks excessive login attempts" do
      6.times do
        post user_session_path, params: { 
          user: { 
            email: "test@example.com", 
            password: "wrong" 
          } 
        }
      end
      
      expect(response).to have_http_status(:too_many_requests)
      expect(RateLimitingService.check_rate_limit("127.0.0.1", :login)).to be true
    end

    it "auto-blocks IPs with multiple violations" do
      identifier = "203.0.113.1"
      
      # Trigger multiple rate limit violations
      6.times do
        RateLimitingService.increment_counter(identifier, :login)
      end
      
      expect(IpBlockingService.blocked?(identifier)).to be true
    end

    it "resets rate limits after cooldown period" do
      identifier = "127.0.0.1"
      
      # Trigger rate limit
      5.times do
        RateLimitingService.increment_counter(identifier, :login)
      end
      
      expect(RateLimitingService.check_rate_limit(identifier, :login)).to be true
      
      # Simulate time passing
      travel 1.hour do
        expect(RateLimitingService.check_rate_limit(identifier, :login)).to be false
      end
    end
  end

  describe "Password Security" do
    it "requires strong passwords for new users" do
      weak_passwords = ["123456", "password", "abc123", "qwerty"]
      
      weak_passwords.each do |weak_password|
        user_params = {
          email: "test#{rand(1000)}@example.com",
          password: weak_password,
          password_confirmation: weak_password,
          first_name: "Test",
          last_name: "User"
        }
        
        post user_registration_path, params: { user: user_params }
        
        expect(response.body).to include("Password") # Should show validation error
      end
    end

    it "enforces password complexity requirements" do
      complex_password = "ComplexP@ssw0rd123!"
      
      user_params = {
        email: "test@example.com",
        password: complex_password,
        password_confirmation: complex_password,
        first_name: "Test",
        last_name: "User"
      }
      
      post user_registration_path, params: { user: user_params }
      
      expect(response).to redirect_to(root_path)
    end

    it "handles password reset flow" do
      post user_password_path, params: { 
        user: { email: user.email } 
      }
      
      expect(response).to redirect_to(new_user_session_path)
      expect(ActionMailer::Base.deliveries.last.to).to include(user.email)
    end
  end

  describe "Account Security" do
    it "locks account after multiple failed attempts" do
      10.times do
        post user_session_path, params: { 
          user: { 
            email: user.email, 
            password: "wrong_password" 
          } 
        }
      end
      
      user.reload
      expect(user.access_locked?).to be true
    end

    it "sends security alerts for suspicious activity" do
      # Mock suspicious activity
      allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return("203.0.113.1")
      
      post user_session_path, params: { 
        user: { 
          email: user.email, 
          password: "password123456" 
        } 
      }
      
      expect(SecurityAlert.where(user: user, alert_type: 'suspicious_login').count).to be > 0
    end

    it "tracks login history" do
      sign_in user
      
      expect(user.login_histories.count).to be > 0
      expect(user.login_histories.last.ip_address).to eq("127.0.0.1")
    end
  end

  describe "API Authentication" do
    let(:api_key) { create(:api_key, organization: organization) }

    it "authenticates API requests with valid key" do
      get api_v1_applications_path, headers: { 
        'Authorization' => "Bearer #{api_key.key}" 
      }
      
      expect(response).to have_http_status(:success)
    end

    it "rejects API requests with invalid key" do
      get api_v1_applications_path, headers: { 
        'Authorization' => "Bearer invalid_key" 
      }
      
      expect(response).to have_http_status(:unauthorized)
    end

    it "tracks API key usage" do
      get api_v1_applications_path, headers: { 
        'Authorization' => "Bearer #{api_key.key}" 
      }
      
      api_key.reload
      expect(api_key.last_used_at).to be_present
      expect(api_key.request_count).to be > 0
    end

    it "enforces API rate limits" do
      100.times do
        get api_v1_applications_path, headers: { 
          'Authorization' => "Bearer #{api_key.key}" 
        }
      end
      
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "Security Edge Cases" do
    it "handles SQL injection attempts in login" do
      malicious_inputs = [
        "' OR '1'='1",
        "admin'--",
        "'; DROP TABLE users; --"
      ]
      
      malicious_inputs.each do |malicious_input|
        post user_session_path, params: { 
          user: { 
            email: malicious_input, 
            password: "password" 
          } 
        }
        
        expect(response).to render_template(:new)
        expect(User.count).to be > 0 # Ensure no data was deleted
      end
    end

    it "sanitizes user input in forms" do
      xss_input = "<script>alert('xss')</script>"
      
      post user_session_path, params: { 
        user: { 
          email: xss_input, 
          password: "password" 
        } 
      }
      
      expect(response.body).not_to include("<script>")
    end

    it "handles concurrent login attempts gracefully" do
      threads = []
      
      5.times do
        threads << Thread.new do
          post user_session_path, params: { 
            user: { 
              email: user.email, 
              password: "password123456" 
            } 
          }
        end
      end
      
      threads.each(&:join)
      
      # Should not cause database conflicts or errors
      expect(response).to be_successful
    end
  end
end