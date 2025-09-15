class MfaController < ApplicationController
  include AuthorizationController
  
  before_action :authenticate_user!
  before_action :set_user
  
  def show
    @qr_code_svg = @user.generate_qr_code if @user.mfa_secret
  end
  
  def setup
    @user.generate_mfa_secret
    @qr_code_svg = @user.generate_qr_code
  end
  
  def enable
    if @user.verify_mfa_code(params[:code])
      backup_codes = @user.enable_mfa!
      flash[:notice] = 'Two-factor authentication has been enabled successfully.'
      flash[:backup_codes] = backup_codes
      redirect_to mfa_path
    else
      flash.now[:alert] = 'Invalid verification code. Please try again.'
      @qr_code_svg = @user.generate_qr_code
      render :setup
    end
  end
  
  def disable
    if @user.verify_mfa_code(params[:code])
      @user.disable_mfa!
      flash[:notice] = 'Two-factor authentication has been disabled.'
      redirect_to mfa_path
    else
      flash.now[:alert] = 'Invalid verification code. Please try again.'
      render :show
    end
  end
  
  def backup_codes
    @backup_codes = @user.backup_codes_array
  end
  
  def regenerate_backup_codes
    if @user.verify_mfa_code(params[:code])
      @backup_codes = @user.generate_backup_codes
      @user.save!
      flash[:notice] = 'New backup codes have been generated. Please save them securely.'
      render :backup_codes
    else
      flash.now[:alert] = 'Invalid verification code. Please try again.'
      redirect_to backup_codes_mfa_path
    end
  end
  
  private
  
  def set_user
    @user = current_user
  end
end