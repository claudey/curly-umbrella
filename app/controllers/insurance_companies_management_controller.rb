# frozen_string_literal: true

class InsuranceCompaniesManagementController < ApplicationController
  before_action :authenticate_user!
  before_action :set_insurance_company, only: [:show, :edit, :update, :approve, :reject, :activate, :deactivate]

  # GET /insurance_companies
  def index
    @insurance_companies = InsuranceCompany.includes(:users)
    @insurance_companies = @insurance_companies.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @insurance_companies = @insurance_companies.page(params[:page]).per(25)
  end

  # GET /insurance_companies/pending
  def pending
    @insurance_companies = InsuranceCompany.where(status: 'pending_approval')
    @insurance_companies = @insurance_companies.page(params[:page]).per(25)
  end

  # GET /insurance_companies/1
  def show
  end

  # GET /insurance_companies/new
  def new
    @insurance_company = InsuranceCompany.new
  end

  # GET /insurance_companies/1/edit
  def edit
  end

  # POST /insurance_companies
  def create
    @insurance_company = InsuranceCompany.new(insurance_company_params)

    if @insurance_company.save
      redirect_to @insurance_company, notice: 'Insurance company was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /insurance_companies/1
  def update
    if @insurance_company.update(insurance_company_params)
      redirect_to @insurance_company, notice: 'Insurance company was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # PATCH /insurance_companies/1/approve
  def approve
    @insurance_company.update(status: 'approved')
    redirect_to @insurance_company, notice: 'Insurance company was approved.'
  end

  # PATCH /insurance_companies/1/reject
  def reject
    @insurance_company.update(status: 'rejected')
    redirect_to @insurance_company, notice: 'Insurance company was rejected.'
  end

  # PATCH /insurance_companies/1/activate
  def activate
    @insurance_company.update(status: 'active')
    redirect_to @insurance_company, notice: 'Insurance company was activated.'
  end

  # PATCH /insurance_companies/1/deactivate
  def deactivate
    @insurance_company.update(status: 'inactive')
    redirect_to @insurance_company, notice: 'Insurance company was deactivated.'
  end

  private

  def set_insurance_company
    @insurance_company = InsuranceCompany.find(params[:id])
  end

  def insurance_company_params
    params.require(:insurance_company).permit(:name, :email, :phone, :address, :city, :state, :zip_code, :license_number, :status, :contact_person, :website)
  end
end