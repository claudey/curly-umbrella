# frozen_string_literal: true

class DocumentSearchService
  attr_reader :scope, :params, :current_user

  def initialize(scope, params, current_user)
    @scope = scope
    @params = params
    @current_user = current_user
  end

  def search
    documents = scope
    documents = apply_text_search(documents)
    documents = apply_filters(documents)
    documents = apply_date_filters(documents)
    documents = apply_sorting(documents)
    documents
  end

  def search_suggestions
    return [] if params[:search].blank?

    suggestions = []
    search_term = params[:search].downcase

    # Name suggestions
    name_matches = scope.where("name ILIKE ?", "%#{search_term}%")
                       .limit(5)
                       .pluck(:name)
                       .map { |name| { type: 'name', value: name, label: "Document: #{name}" } }

    # Tag suggestions
    tag_matches = scope.where("tags && ARRAY[?]", [search_term])
                      .limit(5)
                      .pluck(:tags)
                      .flatten
                      .uniq
                      .select { |tag| tag.downcase.include?(search_term) }
                      .map { |tag| { type: 'tag', value: tag, label: "Tag: #{tag}" } }

    # User suggestions
    user_matches = User.where(organization: current_user.organization)
                       .where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?", 
                              "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
                       .limit(3)
                       .map { |user| { type: 'user', value: user.id, label: "Uploaded by: #{user.display_name}" } }

    suggestions.concat(name_matches)
    suggestions.concat(tag_matches)
    suggestions.concat(user_matches)
    suggestions.first(10)
  end

  def facets
    base_scope = apply_text_search(scope)
    
    {
      categories: calculate_facet_counts(base_scope, :category, Document::CATEGORIES),
      document_types: calculate_facet_counts(base_scope, :document_type, Document::DOCUMENT_TYPES),
      access_levels: calculate_facet_counts(base_scope, :access_level, Document::ACCESS_LEVELS),
      uploaders: uploader_facets(base_scope),
      file_types: file_type_facets(base_scope),
      date_ranges: date_range_facets(base_scope)
    }
  end

  private

  def apply_text_search(documents)
    return documents if params[:search].blank?

    search_term = params[:search].strip
    
    # Check if it's a quoted phrase search
    if search_term.starts_with?('"') && search_term.ends_with?('"')
      phrase = search_term[1..-2]
      documents = documents.where(
        "name ILIKE ? OR description ILIKE ? OR ARRAY_TO_STRING(tags, ' ') ILIKE ?",
        "%#{phrase}%", "%#{phrase}%", "%#{phrase}%"
      )
    else
      # Split into words for multi-word search
      words = search_term.split(/\s+/)
      
      words.each do |word|
        next if word.length < 2
        
        documents = documents.where(
          "name ILIKE ? OR description ILIKE ? OR EXISTS(
            SELECT 1 FROM unnest(tags) AS tag WHERE tag ILIKE ?
          )",
          "%#{word}%", "%#{word}%", "%#{word}%"
        )
      end
    end

    documents
  end

  def apply_filters(documents)
    # Category filter
    if params[:category].present? && params[:category] != 'all'
      documents = documents.where(category: params[:category])
    end

    # Document type filter
    if params[:document_type].present? && params[:document_type] != 'all'
      documents = documents.where(document_type: params[:document_type])
    end

    # Access level filter
    if params[:access_level].present? && params[:access_level] != 'all'
      documents = documents.where(access_level: params[:access_level])
    end

    # Tag filter
    if params[:tags].present?
      tags = Array(params[:tags]).reject(&:blank?)
      documents = documents.where("tags && ARRAY[?]", tags) if tags.any?
    end

    # User filter
    if params[:user_id].present? && params[:user_id] != 'all'
      documents = documents.where(user_id: params[:user_id])
    end

    # Status filter
    case params[:status]
    when 'archived'
      documents = documents.archived
    when 'expiring'
      documents = documents.expiring_soon(30)
    when 'expired'
      documents = documents.expired
    when 'current'
      documents = documents.current
    else
      documents = documents.not_archived unless params[:show_archived] == 'true'
    end

    # File type filter
    if params[:file_type].present? && params[:file_type] != 'all'
      case params[:file_type]
      when 'images'
        documents = documents.joins(file_attachment: :blob)
                            .where("active_storage_blobs.content_type LIKE 'image/%'")
      when 'pdfs'
        documents = documents.joins(file_attachment: :blob)
                            .where("active_storage_blobs.content_type = 'application/pdf'")
      when 'documents'
        documents = documents.joins(file_attachment: :blob)
                            .where("active_storage_blobs.content_type IN (?, ?, ?)",
                                   'application/msword',
                                   'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                                   'text/plain')
      when 'spreadsheets'
        documents = documents.joins(file_attachment: :blob)
                            .where("active_storage_blobs.content_type IN (?, ?)",
                                   'application/vnd.ms-excel',
                                   'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      end
    end

    # Size filter
    if params[:size_range].present?
      case params[:size_range]
      when 'small'
        documents = documents.where('file_size < ?', 1.megabyte)
      when 'medium'
        documents = documents.where('file_size BETWEEN ? AND ?', 1.megabyte, 10.megabytes)
      when 'large'
        documents = documents.where('file_size > ?', 10.megabytes)
      end
    end

    documents
  end

  def apply_date_filters(documents)
    # Upload date filter
    if params[:uploaded_after].present?
      documents = documents.where('created_at >= ?', Date.parse(params[:uploaded_after]))
    end

    if params[:uploaded_before].present?
      documents = documents.where('created_at <= ?', Date.parse(params[:uploaded_before]))
    end

    # Expiry date filter
    if params[:expires_after].present?
      documents = documents.where('expires_at >= ?', Date.parse(params[:expires_after]))
    end

    if params[:expires_before].present?
      documents = documents.where('expires_at <= ?', Date.parse(params[:expires_before]))
    end

    # Quick date ranges
    case params[:date_range]
    when 'today'
      documents = documents.where(created_at: Date.current.all_day)
    when 'week'
      documents = documents.where(created_at: 1.week.ago..Time.current)
    when 'month'
      documents = documents.where(created_at: 1.month.ago..Time.current)
    when 'quarter'
      documents = documents.where(created_at: 3.months.ago..Time.current)
    when 'year'
      documents = documents.where(created_at: 1.year.ago..Time.current)
    end

    documents
  end

  def apply_sorting(documents)
    case params[:sort]
    when 'name_asc'
      documents.order(:name)
    when 'name_desc'
      documents.order(name: :desc)
    when 'type_asc'
      documents.order(:document_type)
    when 'type_desc'
      documents.order(document_type: :desc)
    when 'size_asc'
      documents.order(:file_size)
    when 'size_desc'
      documents.order(file_size: :desc)
    when 'updated_asc'
      documents.order(:updated_at)
    when 'updated_desc'
      documents.order(updated_at: :desc)
    when 'expires_asc'
      documents.order(:expires_at)
    when 'expires_desc'
      documents.order(expires_at: :desc)
    else
      documents.order(created_at: :desc)  # Default: newest first
    end
  end

  def calculate_facet_counts(base_scope, field, possible_values)
    counts = base_scope.group(field).count
    
    possible_values.map do |value|
      {
        value: value,
        label: value.humanize,
        count: counts[value] || 0
      }
    end.select { |facet| facet[:count] > 0 }
  end

  def uploader_facets(base_scope)
    base_scope.joins(:user)
              .group('users.id', 'users.first_name', 'users.last_name')
              .count
              .map do |(id, first_name, last_name), count|
                {
                  value: id,
                  label: "#{first_name} #{last_name}",
                  count: count
                }
              end
              .sort_by { |facet| -facet[:count] }
              .first(10)
  end

  def file_type_facets(base_scope)
    content_types = base_scope.joins(file_attachment: :blob)
                              .group('active_storage_blobs.content_type')
                              .count

    grouped_types = {}
    content_types.each do |content_type, count|
      category = categorize_content_type(content_type)
      grouped_types[category] = (grouped_types[category] || 0) + count
    end

    grouped_types.map do |category, count|
      {
        value: category,
        label: category.humanize,
        count: count
      }
    end.sort_by { |facet| -facet[:count] }
  end

  def date_range_facets(base_scope)
    today = Date.current
    ranges = [
      { label: 'Today', value: 'today', start: today.beginning_of_day, end: today.end_of_day },
      { label: 'This Week', value: 'week', start: today.beginning_of_week, end: today.end_of_week },
      { label: 'This Month', value: 'month', start: today.beginning_of_month, end: today.end_of_month },
      { label: 'Last 30 Days', value: '30_days', start: 30.days.ago, end: Time.current },
      { label: 'Last 90 Days', value: '90_days', start: 90.days.ago, end: Time.current },
      { label: 'This Year', value: 'year', start: today.beginning_of_year, end: today.end_of_year }
    ]

    ranges.map do |range|
      count = base_scope.where(created_at: range[:start]..range[:end]).count
      range.merge(count: count)
    end.select { |range| range[:count] > 0 }
  end

  def categorize_content_type(content_type)
    case content_type
    when /^image\//
      'images'
    when 'application/pdf'
      'pdfs'
    when /word|document|text/
      'documents'
    when /excel|spreadsheet/
      'spreadsheets'
    when /zip|compressed/
      'archives'
    else
      'other'
    end
  end
end