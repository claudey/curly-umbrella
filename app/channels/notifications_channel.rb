class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_user
    
    # Stream from user-specific notification channel
    stream_from "notifications_#{current_user.id}"
    
    # If user is an insurance company, also stream from company-specific channel
    if current_user.insurance_company? && current_user.organization_id
      stream_from "insurance_company_notifications_#{current_user.organization_id}"
    end
    
    # Stream from organization-specific channel for brokerages
    if current_user.organization_id && !current_user.insurance_company?
      stream_from "organization_notifications_#{current_user.organization_id}"
    end
    
    Rails.logger.info "User #{current_user.id} subscribed to notifications"
  end

  def unsubscribed
    Rails.logger.info "User #{current_user&.id} unsubscribed from notifications"
  end
  
  def mark_as_read(data)
    notification_id = data['notification_id']
    notification = current_user.notifications.find_by(id: notification_id)
    
    if notification&.update(read_at: Time.current)
      broadcast_to_user(current_user, {
        type: 'notification_marked_read',
        notification_id: notification_id,
        unread_count: current_user.notifications.unread.count
      })
    end
  end
  
  def mark_all_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    
    broadcast_to_user(current_user, {
      type: 'all_notifications_marked_read',
      unread_count: 0
    })
  end
  
  private
  
  def broadcast_to_user(user, data)
    ActionCable.server.broadcast("notifications_#{user.id}", data)
  end
end
