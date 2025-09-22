# frozen_string_literal: true

class Settings::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access
  before_action :set_user, only: [:show, :edit, :update, :destroy, :activate, :deactivate, :reset_password]

  # GET /settings/users
  def index
    @users = current_user.organization.users.includes(:role)
    @users = @users.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?", 
                          "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @users = @users.page(params[:page]).per(25)
  end

  # GET /settings/users/1
  def show
  end

  # GET /settings/users/new
  def new
    @user = current_user.organization.users.build
  end

  # GET /settings/users/1/edit
  def edit
  end

  # POST /settings/users
  def create
    @user = current_user.organization.users.build(user_params)
    @user.password = SecureRandom.hex(12) # Generate temporary password

    if @user.save
      # Send invitation email with temporary password
      UserMailer.invitation_email(@user, @user.password).deliver_now
      redirect_to settings_users_path, notice: 'User was successfully created and invitation sent.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /settings/users/1
  def update
    if @user.update(user_params)
      redirect_to settings_user_path(@user), notice: 'User was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /settings/users/1
  def destroy
    if @user == current_user
      redirect_to settings_users_path, alert: 'You cannot delete your own account.'
      return
    end

    @user.destroy
    redirect_to settings_users_path, notice: 'User was successfully deleted.'
  end

  # PATCH /settings/users/1/activate
  def activate
    @user.update(status: 'active')
    redirect_to settings_user_path(@user), notice: 'User was activated.'
  end

  # PATCH /settings/users/1/deactivate
  def deactivate
    if @user == current_user
      redirect_to settings_users_path, alert: 'You cannot deactivate your own account.'
      return
    end

    @user.update(status: 'inactive')
    redirect_to settings_user_path(@user), notice: 'User was deactivated.'
  end

  # PATCH /settings/users/1/reset_password
  def reset_password
    new_password = SecureRandom.hex(12)
    @user.update(password: new_password)
    
    # Send password reset email
    UserMailer.password_reset_email(@user, new_password).deliver_now
    redirect_to settings_user_path(@user), notice: 'Password was reset and email sent to user.'
  end

  private

  def set_user
    @user = current_user.organization.users.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone, :role, :status, :department)
  end

  def ensure_admin_access
    redirect_to root_path, alert: 'Access denied.' unless current_user.admin? || current_user.brokerage_admin?
  end
end