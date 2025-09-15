class Admin::OrganizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_super_admin
  before_action :set_organization, only: [:show, :edit, :update, :destroy, :activate, :deactivate]
  
  def index
    @organizations = Organization.includes(:users)
                                .order(:name)
                                .page(params[:page])
                                .per(20)
    
    if params[:search].present?
      @organizations = @organizations.where(
        "name ILIKE ? OR subdomain ILIKE ?", 
        "%#{params[:search]}%", 
        "%#{params[:search]}%"
      )
    end
    
    if params[:status].present?
      case params[:status]
      when 'active'
        @organizations = @organizations.where(active: true)
      when 'inactive'
        @organizations = @organizations.where(active: false)
      end
    end
    
    @stats = {
      total: Organization.count,
      active: Organization.where(active: true).count,
      inactive: Organization.where(active: false).count,
      this_month: Organization.where(created_at: Time.current.beginning_of_month..Time.current).count
    }
  end
  
  def show
    @users_count = @organization.users.count
    @recent_users = @organization.users.order(created_at: :desc).limit(5)
    @applications_count = @organization.insurance_applications.count
    @quotes_count = @organization.quotes.count
    @recent_activity = recent_activity_for_organization(@organization)
  end
  
  def new
    @organization = Organization.new
  end
  
  def create
    @organization = Organization.new(organization_params)
    
    if @organization.save
      # Create default admin user if provided
      if admin_user_params[:email].present?
        create_default_admin_user
      end
      
      redirect_to admin_organization_path(@organization), 
                  notice: 'Organization created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @organization.update(organization_params)
      redirect_to admin_organization_path(@organization), 
                  notice: 'Organization updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @organization.users.any?
      redirect_to admin_organizations_path, 
                  alert: 'Cannot delete organization with existing users. Please remove all users first.'
      return
    end
    
    @organization.destroy
    redirect_to admin_organizations_path, 
                notice: 'Organization deleted successfully.'
  end
  
  def activate
    @organization.update!(active: true)
    redirect_to admin_organization_path(@organization), 
                notice: 'Organization activated successfully.'
  end
  
  def deactivate
    @organization.update!(active: false)
    redirect_to admin_organization_path(@organization), 
                notice: 'Organization deactivated successfully.'
  end
  
  def analytics
    @organizations = Organization.includes(:users, :insurance_applications, :quotes)
    
    @analytics = {
      total_organizations: @organizations.count,
      active_organizations: @organizations.where(active: true).count,
      total_users: User.where.not(role: 'super_admin').count,
      total_applications: InsuranceApplication.count,
      total_quotes: Quote.count,
      monthly_growth: monthly_organization_growth,
      top_organizations: top_organizations_by_activity,
      recent_signups: Organization.order(created_at: :desc).limit(10)
    }
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:id])
  end
  
  def organization_params
    params.require(:organization).permit(
      :name, :subdomain, :description, :active, :plan,
      :max_users, :max_applications, :billing_email,
      contact_info: [:address, :city, :state, :postal_code, :country, :phone, :website],
      settings: [:theme, :timezone, :currency, :language, :features]
    )
  end
  
  def admin_user_params
    params.permit(:admin_email, :admin_first_name, :admin_last_name)
  end
  
  def ensure_super_admin
    redirect_to root_path, alert: 'Access denied.' unless current_user.super_admin?
  end
  
  def create_default_admin_user
    temp_password = SecureRandom.alphanumeric(12)
    
    admin_user = @organization.users.build(
      email: admin_user_params[:admin_email],
      first_name: admin_user_params[:admin_first_name] || 'Admin',
      last_name: admin_user_params[:admin_last_name] || 'User',
      phone: '000-000-0000', # Placeholder
      role: 'brokerage_admin',
      password: temp_password,
      password_confirmation: temp_password
    )
    
    if admin_user.save
      # Send welcome email with temporary password
      AdminMailer.organization_created(admin_user, temp_password).deliver_later
    end
  end
  
  def recent_activity_for_organization(organization)
    activities = []
    
    # Recent applications
    organization.insurance_applications.order(created_at: :desc).limit(3).each do |app|
      activities << {
        type: 'application',
        title: "New #{app.insurance_type} application",
        description: "Application ##{app.id} for #{app.client_name}",
        timestamp: app.created_at,
        icon: 'ph-file-text'
      }
    end
    
    # Recent users
    organization.users.where.not(role: 'super_admin').order(created_at: :desc).limit(3).each do |user|
      activities << {
        type: 'user',
        title: "New user joined",
        description: "#{user.full_name} (#{user.role.humanize})",
        timestamp: user.created_at,
        icon: 'ph-user-plus'
      }
    end
    
    activities.sort_by { |a| a[:timestamp] }.reverse.first(5)
  end
  
  def monthly_organization_growth
    months = (0..11).map do |i|
      date = i.months.ago.beginning_of_month
      {
        month: date.strftime('%b %Y'),
        count: Organization.where(created_at: date..date.end_of_month).count
      }
    end.reverse
  end
  
  def top_organizations_by_activity
    Organization.joins(:insurance_applications)
                .group('organizations.id', 'organizations.name')
                .order('COUNT(insurance_applications.id) DESC')
                .limit(5)
                .pluck('organizations.name', 'COUNT(insurance_applications.id)')
                .map { |name, count| { name: name, applications: count } }
  end
end