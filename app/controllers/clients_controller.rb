# frozen_string_literal: true

class ClientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client, only: [:show, :edit, :update, :destroy, :activate, :deactivate]

  # GET /clients
  def index
    @clients = current_user.organization.clients.includes(:user)
    @clients = @clients.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?", 
                              "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @clients = @clients.page(params[:page]).per(25)
  end

  # GET /clients/1
  def show
  end

  # GET /clients/new
  def new
    @client = current_user.organization.clients.build
  end

  # GET /clients/1/edit
  def edit
  end

  # POST /clients
  def create
    @client = current_user.organization.clients.build(client_params)
    @client.user = current_user

    if @client.save
      redirect_to @client, notice: 'Client was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /clients/1
  def update
    if @client.update(client_params)
      redirect_to @client, notice: 'Client was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /clients/1
  def destroy
    @client.destroy
    redirect_to clients_url, notice: 'Client was successfully deleted.'
  end

  # PATCH /clients/1/activate
  def activate
    @client.update(status: 'active')
    redirect_to @client, notice: 'Client was activated.'
  end

  # PATCH /clients/1/deactivate
  def deactivate
    @client.update(status: 'inactive')
    redirect_to @client, notice: 'Client was deactivated.'
  end

  # GET /clients/search
  def search
    @clients = current_user.organization.clients.includes(:user)
    @clients = @clients.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?", 
                              "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
    
    render json: @clients.limit(10).map { |client| 
      { 
        id: client.id, 
        name: client.full_name, 
        email: client.email 
      } 
    }
  end

  private

  def set_client
    @client = current_user.organization.clients.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:first_name, :last_name, :email, :phone, :address, :city, :state, :zip_code, :client_type, :status, :notes)
  end
end