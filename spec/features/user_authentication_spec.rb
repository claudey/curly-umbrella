require 'rails_helper'

RSpec.describe "User Authentication", type: :feature do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, email: "test@example.com", password: "password123456", organization: organization) }

  describe "Login functionality" do
    it "allows valid user to login" do
      visit new_user_session_path
      
      fill_in "Email", with: "test@example.com"
      fill_in "Password", with: "password123456"
      click_button "Sign in"
      
      expect(page).to have_current_path(root_path)
      expect(page).to have_text("Dashboard")
    end

    it "rejects invalid credentials" do
      visit new_user_session_path
      
      fill_in "Email", with: "invalid@example.com"
      fill_in "Password", with: "wrong"
      click_button "Sign in"
      
      expect(page).to have_text("Invalid Email or password")
      expect(page).to have_current_path(new_user_session_path)
    end

    it "shows appropriate error for blank fields" do
      visit new_user_session_path
      
      click_button "Sign in"
      
      expect(page).to have_text("Invalid Email or password")
    end
  end

  describe "Logout functionality" do
    before do
      sign_in user
      visit root_path
    end

    it "logs out user successfully" do
      click_link "Logout"
      
      expect(page).to have_current_path(root_path)
      expect(page).not_to have_text("Dashboard")
    end
  end

  describe "Protected pages" do
    it "redirects unauthenticated users to login" do
      visit clients_path
      
      expect(page).to have_current_path(new_user_session_path)
    end

    it "allows authenticated users to access protected pages" do
      sign_in user
      visit clients_path
      
      expect(page).to have_text("Clients")
    end
  end

  describe "Password requirements" do
    it "enforces minimum password length" do
      visit new_user_registration_path
      
      fill_in "Email", with: "newuser@example.com"
      fill_in "Password", with: "short"
      fill_in "Password confirmation", with: "short"
      click_button "Sign up"
      
      expect(page).to have_text("Password is too short")
    end
  end
end