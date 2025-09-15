class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:show, :update]

  def index
    @notifications = current_user.notifications
                                .includes(:organization)
                                .recent
                                .page(params[:page])
                                .per(20)
    
    @unread_count = current_user.notifications.unread.count
  end

  def show
    @notification.mark_as_read! if @notification.unread?
    
    respond_to do |format|
      format.html
      format.json { render json: @notification }
    end
  end

  def update
    if params[:action_type] == 'mark_as_read'
      @notification.mark_as_read!
      redirect_back(fallback_location: notifications_path, notice: 'Notification marked as read.')
    elsif params[:action_type] == 'mark_all_as_read'
      Notification.mark_all_as_read_for_user(current_user)
      redirect_to notifications_path, notice: 'All notifications marked as read.'
    end
  end

  def unread_count
    render json: { count: current_user.notifications.unread.count }
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
