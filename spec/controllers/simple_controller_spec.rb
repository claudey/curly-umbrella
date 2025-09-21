require 'rails_helper'

RSpec.describe "Simple Controller Tests", type: :controller do
  # Test controllers without complex security layers
  
  controller(ApplicationController) do
    skip_before_action :authenticate_user!, only: [:test_action]
    skip_before_action :set_current_tenant, only: [:test_action]
    
    def test_action
      render json: { message: "Hello World", status: "ok" }
    end
  end

  before do
    routes.draw { get "test_action" => "anonymous#test_action" }
  end

  describe "Basic controller functionality" do
    it "responds to simple action" do
      get :test_action
      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to eq("Hello World")
    end
  end
end

# Test a real controller with minimal setup
RSpec.describe Users::SessionsController, type: :controller do
  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe "GET #new" do
    it "renders new template" do
      get :new
      expect(response).to have_http_status(:success)
      expect(response).to render_template("new")
    end
  end
end