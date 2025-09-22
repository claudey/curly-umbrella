# frozen_string_literal: true

class LifeApplication < ApplicationRecord
  belongs_to :client
  belongs_to :user
  belongs_to :organization

  # Explicitly declare the attribute type for the enum
  attribute :status, :integer, default: 0

  validates :coverage_amount, presence: true, numericality: { greater_than: 0 }
  validates :beneficiary_name, presence: true
  validates :beneficiary_relationship, presence: true
  validates :status, presence: true

  enum :status, {
    draft: 0,
    submitted: 1,
    under_review: 2,
    approved: 3,
    rejected: 4,
    cancelled: 5
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
    draft? && coverage_amount.present? && beneficiary_name.present?
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