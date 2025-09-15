require 'rails_helper'

RSpec.describe "Documents", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/documents/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/documents/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/documents/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/documents/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/documents/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/documents/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/documents/destroy"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /download" do
    it "returns http success" do
      get "/documents/download"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /archive" do
    it "returns http success" do
      get "/documents/archive"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /restore" do
    it "returns http success" do
      get "/documents/restore"
      expect(response).to have_http_status(:success)
    end
  end

end
