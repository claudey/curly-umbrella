# frozen_string_literal: true

class Settings::OrganizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access
  before_action :set_organization

  # GET /settings/organization
  def show
  end

  # GET /settings/organization/edit
  def edit
  end

  # PATCH/PUT /settings/organization
  def update
    if @organization.update(organization_params)
      redirect_to settings_organization_path, notice: 'Organization settings were successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_organization
    @organization = current_user.organization
  end

  def organization_params
    params.require(:organization).permit(:name, :email, :phone, :address, :city, :state, :zip_code, :website, :license_number, :tax_id, :description)
  end

  def ensure_admin_access
    redirect_to root_path, alert: 'Access denied.' unless current_user.admin? || current_user.brokerage_admin?
  end
end