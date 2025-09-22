# frozen_string_literal: true

class Settings::PreferencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_preferences

  # GET /settings/preferences
  def show
  end

  # PATCH/PUT /settings/preferences
  def update
    if @user_preferences.update(preferences_params)
      redirect_to settings_preferences_path, notice: 'Preferences were successfully updated.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_user_preferences
    @user_preferences = current_user.user_preferences || current_user.build_user_preferences
  end

  def preferences_params
    params.require(:user_preferences).permit(:theme, :language, :timezone, :email_notifications, :push_notifications, :sms_notifications, :dashboard_layout, :items_per_page)
  end
end