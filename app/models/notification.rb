class Notification < ApplicationRecord
  include Discard::Model
  acts_as_tenant :organization

  belongs_to :user
  belongs_to :organization

  validates :title, presence: true
  validates :message, presence: true
  validates :notification_type, presence: true, inclusion: { 
    in: %w[new_application status_update user_invitation system_alert] 
  }

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }

  # Mark notification as read
  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  # Check if notification has been read
  def read?
    read_at.present?
  end

  # Check if notification is unread
  def unread?
    !read?
  end

  # Create notification for user
  def self.create_for_user(user, title:, message:, type:, data: {})
    create!(
      user: user,
      organization: user.organization,
      title: title,
      message: message,
      notification_type: type,
      data: data
    )
  end

  # Bulk mark as read for user
  def self.mark_all_as_read_for_user(user)
    where(user: user, read_at: nil).update_all(read_at: Time.current)
  end
end
