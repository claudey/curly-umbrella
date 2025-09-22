# frozen_string_literal: true

class ResidentialApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_residential_application, only: [:show, :edit, :update, :destroy, :submit_application, :start_review, :approve, :reject, :print]

  # GET /residential_applications
  def index
    @residential_applications = current_user.organization.residential_applications.includes(:client, :user)
    @residential_applications = @residential_applications.where(status: params[:status]) if params[:status].present? && params[:status] != ''
    @residential_applications = @residential_applications.page(params[:page]).per(25)
  end

  # GET /residential_applications/1
  def show
  end

  # GET /residential_applications/new
  def new
    @residential_application = current_user.organization.residential_applications.build
    @clients = current_user.organization.clients.active
  end

  # GET /residential_applications/1/edit
  def edit
    @clients = current_user.organization.clients.active
  end

  # POST /residential_applications
  def create
    @residential_application = current_user.organization.residential_applications.build(residential_application_params)
    @residential_application.user = current_user
    @residential_application.status = 'draft'

    if @residential_application.save
      redirect_to @residential_application, notice: 'Residential insurance application was successfully created.'
    else
      @clients = current_user.organization.clients.active
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /residential_applications/1
  def update
    if @residential_application.update(residential_application_params)
      redirect_to @residential_application, notice: 'Residential insurance application was successfully updated.'
    else
      @clients = current_user.organization.clients.active
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /residential_applications/1
  def destroy
    @residential_application.destroy
    redirect_to residential_applications_url, notice: 'Residential insurance application was successfully deleted.'
  end

  # PATCH /residential_applications/1/submit_application
  def submit_application
    @residential_application.update(status: 'submitted', submitted_at: Time.current)
    redirect_to @residential_application, notice: 'Residential insurance application was submitted.'
  end

  # PATCH /residential_applications/1/start_review
  def start_review
    @residential_application.update(status: 'under_review', reviewed_at: Time.current)
    redirect_to @residential_application, notice: 'Residential insurance application review started.'
  end

  # PATCH /residential_applications/1/approve
  def approve
    @residential_application.update(status: 'approved', approved_at: Time.current)
    redirect_to @residential_application, notice: 'Residential insurance application was approved.'
  end

  # PATCH /residential_applications/1/reject
  def reject
    @residential_application.update(status: 'rejected', rejected_at: Time.current)
    redirect_to @residential_application, notice: 'Residential insurance application was rejected.'
  end

  # GET /residential_applications/1/print
  def print
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "residential_application_#{@residential_application.id}",
               template: 'residential_applications/print',
               layout: 'pdf'
      end
    end
  end

  private

  def set_residential_application
    @residential_application = current_user.organization.residential_applications.find(params[:id])
  end

  def residential_application_params
    params.require(:residential_application).permit(:client_id, :property_address, :property_value, :dwelling_type, :construction_year, :roof_type, :heating_system, :security_features, :notes)
  end
end