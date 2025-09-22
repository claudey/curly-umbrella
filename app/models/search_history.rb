class SearchHistory < ApplicationRecord
  belongs_to :user

  validates :query, presence: true, length: { maximum: 500 }
  validates :results_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  validate :no_sensitive_information

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :successful, -> { where('results_count > 0') }

  before_save :normalize_query

  def successful?
    results_count > 0
  end

  def formatted_query(limit = nil)
    return query unless limit && query.length > limit
    "#{query[0..limit-1]}..."
  end

  def search_context
    return {} unless metadata.is_a?(Hash)
    metadata.symbolize_keys
  end

  def self.popular_queries(limit = 10)
    group(:query)
      .order('count_query DESC')
      .limit(limit)
      .count(:query)
      .map { |query, count| { query: query, count: count } }
  end

  def self.cleanup_old_searches(days_old = 90)
    where('created_at < ?', days_old.days.ago).delete_all
  end

  def self.trending_searches(since = 1.day.ago)
    where('created_at >= ?', since)
      .group(:query)
      .order('count_query DESC')
      .limit(10)
      .count(:query)
      .map { |query, count| { query: query, count: count } }
  end

  def self.search_analytics(start_date, end_date)
    searches = where(created_at: start_date..end_date)
    successful_searches = searches.successful
    
    {
      total_searches: searches.count,
      successful_searches: successful_searches.count,
      success_rate: searches.count > 0 ? (successful_searches.count.to_f / searches.count * 100).round(2) : 0,
      popular_queries: searches.popular_queries(5),
      average_results: successful_searches.average(:results_count)&.round(2) || 0
    }
  end

  private

  def normalize_query
    return unless query.present?
    
    # Normalize whitespace and remove special characters
    self.query = query.strip
                     .squeeze(' ')
                     .downcase
                     .gsub(/[^\w\s\-_]/, ' ')
                     .squeeze(' ')
                     .strip
  end

  def no_sensitive_information
    return unless query.present?
    
    sensitive_patterns = [
      /\b[\w\.-]+@[\w\.-]+\.\w+\b/,  # Email addresses
      /\b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b/,  # Credit card numbers
      /\b\d{3}[\-\s]?\d{2}[\-\s]?\d{4}\b/,  # SSN format
      /\bpassword\b/i,
      /\bapi[_\s]?key\b/i,
      /\btoken\b/i
    ]
    
    if sensitive_patterns.any? { |pattern| query.match?(pattern) }
      errors.add(:query, 'contains sensitive information')
    end
  end
end
