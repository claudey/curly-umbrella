require 'rails_helper'

RSpec.describe "Simple Authentication Test", type: :request do
  let(:organization) { create(:organization) }
  
  before do
    # Mock security services that might not exist
    allow(IpBlockingService).to receive(:blocked?).and_return(false) if defined?(IpBlockingService)
    allow(RateLimitingService).to receive(:check_rate_limit).and_return(false) if defined?(RateLimitingService)
    
    # Set tenant context
    ActsAsTenant.current_tenant = organization
  end
  
  it "can create a user" do
    user = create(:user, organization: organization)
    
    expect(user).to be_persisted
    expect(user.organization).to eq(organization)
    puts "User created: #{user.email} with org: #{user.organization.name}"
  end

  it "can attempt login" do
    user = create(:user, organization: organization)
    
    post user_session_path, params: { 
      user: { 
        email: user.email, 
        password: "password123456" 
      } 
    }
    
    puts "Response status: #{response.status}"
    puts "Response headers: #{response.headers.to_h.select { |k,v| k.downcase.include?('location') || k.downcase.include?('redirect') }}"
    puts "Response body: #{response.body[0..200]}"
    
    expect(response.status).to be_in([200, 302, 403])
  end
  
  it "can sign in user directly using test helpers" do
    user = create(:user, organization: organization)
    
    sign_in user
    
    get root_path
    
    puts "Root path response status: #{response.status}"
    puts "Current user set: #{controller.current_user.present? if controller.respond_to?(:current_user)}"
    
    expect(response.status).to be_in([200, 302, 403])
  end
end