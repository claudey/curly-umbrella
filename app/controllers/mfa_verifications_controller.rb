class MfaVerificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :check_mfa_required

  def new
    @setup_required = current_user.mfa_setup_required?

    if @setup_required
      current_user.generate_mfa_secret
      @qr_code_svg = current_user.generate_qr_code
    end
  end

  def create
    if current_user.verify_mfa_code(verification_params[:code])
      if current_user.mfa_setup_required?
        # First time setup - enable MFA
        backup_codes = current_user.enable_mfa!
        flash[:notice] = "Two-factor authentication has been set up successfully!"
        flash[:backup_codes] = backup_codes

        # Show backup codes before continuing
        session[:show_backup_codes] = true
      end

      # Mark MFA as verified for this session
      session[:mfa_verified] = current_user.id

      # Redirect to originally requested page or dashboard
      redirect_to stored_location_for(:user) || after_mfa_verification_path
    else
      flash.now[:alert] = "Invalid verification code. Please try again."
      @setup_required = current_user.mfa_setup_required?
      @qr_code_svg = current_user.generate_qr_code if @setup_required
      render :new
    end
  end

  def backup_codes
    return redirect_to root_path unless session.delete(:show_backup_codes)
    @backup_codes = current_user.backup_codes_array
  end

  private

  def verification_params
    params.require(:mfa_verification).permit(:code)
  end

  def check_mfa_required
    redirect_to root_path unless current_user&.mfa_enabled? || current_user&.mfa_setup_required?
  end

  def after_mfa_verification_path
    case current_user.role
    when "super_admin"
      admin_dashboard_path
    when "brokerage_admin"
      dashboard_path
    when "insurance_company"
      insurance_companies_dashboard_path
    else
      root_path
    end
  end
end
