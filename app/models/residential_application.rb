# frozen_string_literal: true

class ResidentialApplication < ApplicationRecord
  belongs_to :client
  belongs_to :user
  belongs_to :organization

  # Explicitly declare the attribute types for enums
  attribute :status, :integer, default: 0
  attribute :dwelling_type, :integer
  attribute :roof_type, :integer

  validates :property_address, presence: true
  validates :property_value, presence: true, numericality: { greater_than: 0 }
  validates :dwelling_type, presence: true
  validates :status, presence: true

  enum :status, {
    draft: 0,
    submitted: 1,
    under_review: 2,
    approved: 3,
    rejected: 4,
    cancelled: 5
  }

  enum :dwelling_type, {
    single_family: 0,
    townhouse: 1,
    condominium: 2,
    duplex: 3,
    mobile_home: 4
  }

  enum :roof_type, {
    asphalt_shingles: 0,
    metal: 1,
    tile: 2,
    slate: 3,
    wood: 4,
    other: 5
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