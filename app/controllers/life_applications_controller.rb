# frozen_string_literal: true

class LifeApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_life_application, only: [:show, :edit, :update, :destroy, :submit_application, :start_review, :approve, :reject, :print]

  # GET /life_applications
  def index
    @life_applications = current_user.organization.life_applications.includes(:client, :user)
    @life_applications = @life_applications.where(status: params[:status]) if params[:status].present? && params[:status] != ''
    @life_applications = @life_applications.page(params[:page]).per(25)
  end

  # GET /life_applications/1
  def show
  end

  # GET /life_applications/new
  def new
    @life_application = current_user.organization.life_applications.build
    @clients = current_user.organization.clients.active
  end

  # GET /life_applications/1/edit
  def edit
    @clients = current_user.organization.clients.active
  end

  # POST /life_applications
  def create
    @life_application = current_user.organization.life_applications.build(life_application_params)
    @life_application.user = current_user
    @life_application.status = 'draft'

    if @life_application.save
      redirect_to @life_application, notice: 'Life insurance application was successfully created.'
    else
      @clients = current_user.organization.clients.active
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /life_applications/1
  def update
    if @life_application.update(life_application_params)
      redirect_to @life_application, notice: 'Life insurance application was successfully updated.'
    else
      @clients = current_user.organization.clients.active
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /life_applications/1
  def destroy
    @life_application.destroy
    redirect_to life_applications_url, notice: 'Life insurance application was successfully deleted.'
  end

  # PATCH /life_applications/1/submit_application
  def submit_application
    @life_application.update(status: 'submitted', submitted_at: Time.current)
    redirect_to @life_application, notice: 'Life insurance application was submitted.'
  end

  # PATCH /life_applications/1/start_review
  def start_review
    @life_application.update(status: 'under_review', reviewed_at: Time.current)
    redirect_to @life_application, notice: 'Life insurance application review started.'
  end

  # PATCH /life_applications/1/approve
  def approve
    @life_application.update(status: 'approved', approved_at: Time.current)
    redirect_to @life_application, notice: 'Life insurance application was approved.'
  end

  # PATCH /life_applications/1/reject
  def reject
    @life_application.update(status: 'rejected', rejected_at: Time.current)
    redirect_to @life_application, notice: 'Life insurance application was rejected.'
  end

  # GET /life_applications/1/print
  def print
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "life_application_#{@life_application.id}",
               template: 'life_applications/print',
               layout: 'pdf'
      end
    end
  end

  private

  def set_life_application
    @life_application = current_user.organization.life_applications.find(params[:id])
  end

  def life_application_params
    params.require(:life_application).permit(:client_id, :coverage_amount, :beneficiary_name, :beneficiary_relationship, :medical_history, :lifestyle_factors, :notes)
  end
end