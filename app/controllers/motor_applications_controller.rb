class MotorApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_motor_application, only: [ :show, :edit, :update, :destroy, :submit_application, :start_review, :approve, :reject, :print ]
  before_action :ensure_can_edit, only: [ :edit, :update ]

  def index
    @motor_applications = current_tenant.motor_applications
                                       .includes(:client, :reviewed_by, :approved_by, :rejected_by)
                                       .recent

    # Filter by status if provided
    @motor_applications = @motor_applications.by_status(params[:status]) if params[:status].present?

    # Search functionality
    if params[:search].present?
      @motor_applications = @motor_applications.joins(:client)
                                             .where("clients.first_name ILIKE ? OR clients.last_name ILIKE ? OR motor_applications.application_number ILIKE ?",
                                                    "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    @motor_applications = @motor_applications.page(params[:page])
  end

  def show
    @can_review = @motor_application.can_review? && can_review_applications?
    @can_approve = @motor_application.under_review? && can_approve_applications?
  end

  def new
    @motor_application = current_tenant.motor_applications.build

    # Pre-populate client if provided
    if params[:client_id].present?
      @motor_application.client = current_tenant.clients.find(params[:client_id])
    end
  end

  def create
    @motor_application = current_tenant.motor_applications.build(motor_application_params)

    if @motor_application.save
      redirect_to @motor_application, notice: "Motor insurance application was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @motor_application.update(motor_application_params)
      redirect_to @motor_application, notice: "Motor insurance application was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @motor_application.discard
    redirect_to motor_applications_path, notice: "Motor insurance application was successfully deleted."
  end

  def submit_application
    if @motor_application.submit!
      redirect_to @motor_application, notice: "Application has been submitted for review."
    else
      redirect_to @motor_application, alert: "Unable to submit application. Please ensure all required fields are completed."
    end
  end

  def start_review
    if @motor_application.start_review!(current_user)
      redirect_to @motor_application, notice: "Application review has been started."
    else
      redirect_to @motor_application, alert: "Unable to start review."
    end
  end

  def approve
    if @motor_application.approve!(current_user)
      redirect_to @motor_application, notice: "Application has been approved."
    else
      redirect_to @motor_application, alert: "Unable to approve application."
    end
  end

  def reject
    reason = params[:rejection_reason]

    if reason.blank?
      redirect_to @motor_application, alert: "Rejection reason is required."
      return
    end

    if @motor_application.reject!(current_user, reason)
      redirect_to @motor_application, notice: "Application has been rejected."
    else
      redirect_to @motor_application, alert: "Unable to reject application."
    end
  end

  def print
    @application = @motor_application # For consistency with print template
    render layout: "print"
  end

  private

  def set_motor_application
    @motor_application = current_tenant.motor_applications.find(params[:id])
  end

  def motor_application_params
    params.require(:motor_application).permit(
      :client_id, :vehicle_make, :vehicle_model, :vehicle_year, :vehicle_color,
      :vehicle_chassis_number, :vehicle_engine_number, :vehicle_registration_number,
      :vehicle_value, :vehicle_category, :vehicle_fuel_type, :vehicle_transmission,
      :vehicle_seating_capacity, :vehicle_usage, :vehicle_mileage,
      :driver_license_number, :driver_license_expiry, :driver_license_class,
      :driver_years_experience, :driver_occupation, :driver_has_claims,
      :driver_claims_details, :coverage_type, :coverage_start_date,
      :coverage_end_date, :sum_insured, :deductible, :premium_amount,
      :commission_rate, :notes, documents: []
    )
  end

  def ensure_can_edit
    unless @motor_application.can_edit?
      redirect_to @motor_application, alert: "This application cannot be edited."
    end
  end

  def can_review_applications?
    # This would typically check user roles/permissions
    # For now, allowing all authenticated users
    current_user.present?
  end

  def can_approve_applications?
    # This would typically check user roles/permissions
    # For now, allowing all authenticated users
    current_user.present?
  end

  def current_tenant
    current_user.organization
  end
end
