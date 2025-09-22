# frozen_string_literal: true

class FireApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_fire_application, only: [:show, :edit, :update, :destroy, :submit_application, :start_review, :approve, :reject, :print]

  # GET /fire_applications
  def index
    @fire_applications = current_user.organization.fire_applications.includes(:client, :user)
    @fire_applications = @fire_applications.where(status: params[:status]) if params[:status].present? && params[:status] != ''
    @fire_applications = @fire_applications.page(params[:page]).per(25)
  end

  # GET /fire_applications/1
  def show
  end

  # GET /fire_applications/new
  def new
    @fire_application = current_user.organization.fire_applications.build
    @clients = current_user.organization.clients.active
  end

  # GET /fire_applications/1/edit
  def edit
    @clients = current_user.organization.clients.active
  end

  # POST /fire_applications
  def create
    @fire_application = current_user.organization.fire_applications.build(fire_application_params)
    @fire_application.user = current_user
    @fire_application.status = 'draft'

    if @fire_application.save
      redirect_to @fire_application, notice: 'Fire insurance application was successfully created.'
    else
      @clients = current_user.organization.clients.active
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /fire_applications/1
  def update
    if @fire_application.update(fire_application_params)
      redirect_to @fire_application, notice: 'Fire insurance application was successfully updated.'
    else
      @clients = current_user.organization.clients.active
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /fire_applications/1
  def destroy
    @fire_application.destroy
    redirect_to fire_applications_url, notice: 'Fire insurance application was successfully deleted.'
  end

  # PATCH /fire_applications/1/submit_application
  def submit_application
    @fire_application.update(status: 'submitted', submitted_at: Time.current)
    redirect_to @fire_application, notice: 'Fire insurance application was submitted.'
  end

  # PATCH /fire_applications/1/start_review
  def start_review
    @fire_application.update(status: 'under_review', reviewed_at: Time.current)
    redirect_to @fire_application, notice: 'Fire insurance application review started.'
  end

  # PATCH /fire_applications/1/approve
  def approve
    @fire_application.update(status: 'approved', approved_at: Time.current)
    redirect_to @fire_application, notice: 'Fire insurance application was approved.'
  end

  # PATCH /fire_applications/1/reject
  def reject
    @fire_application.update(status: 'rejected', rejected_at: Time.current)
    redirect_to @fire_application, notice: 'Fire insurance application was rejected.'
  end

  # GET /fire_applications/1/print
  def print
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "fire_application_#{@fire_application.id}",
               template: 'fire_applications/print',
               layout: 'pdf'
      end
    end
  end

  private

  def set_fire_application
    @fire_application = current_user.organization.fire_applications.find(params[:id])
  end

  def fire_application_params
    params.require(:fire_application).permit(:client_id, :property_address, :property_value, :building_type, :construction_year, :security_features, :fire_safety_measures, :notes)
  end
end