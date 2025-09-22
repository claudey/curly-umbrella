# frozen_string_literal: true

class FireApplication < ApplicationRecord
  belongs_to :client
  belongs_to :user
  belongs_to :organization

  # Explicitly declare the attribute types for enums
  attribute :status, :integer, default: 0
  attribute :building_type, :integer

  validates :property_address, presence: true
  validates :property_value, presence: true, numericality: { greater_than: 0 }
  validates :building_type, presence: true
  validates :status, presence: true

  enum :status, {
    draft: 0,
    submitted: 1,
    under_review: 2,
    approved: 3,
    rejected: 4,
    cancelled: 5
  }

  enum :building_type, {
    residential: 0,
    commercial: 1,
    industrial: 2,
    mixed_use: 3
  }

  scope :active, -> { where.not(status: :cancelled) }
  scope :pending, -> { where(status: [:submitted, :under_review]) }

  def status_color
    case status
    when 'draft' then 'bg-gray-100 text-gray-800'
    when 'submitted' then 'bg-blue-100 text-blue-800'
    when 'under_review' then 'bg-yellow-100 text-yellow-800'
    when 'approved' then 'bg-green-100 text-green-800'
    when 'rejected' then 'bg-red-100 text-red-800'
    when 'cancelled' then 'bg-gray-100 text-gray-800'
    else 'bg-gray-100 text-gray-800'
    end
  end

  def can_be_submitted?
    draft? && property_address.present? && property_value.present?
  end

  def can_be_reviewed?
    submitted?
  end

  def can_be_approved?
    under_review?
  end

  def can_be_rejected?
    under_review? || submitted?
  end
end