module DocumentsHelper
  def document_icon_class(document_type)
    case document_type.to_s.downcase
    when 'application'
      'fas fa-file-contract text-primary'
    when 'quote'
      'fas fa-file-invoice-dollar text-success'
    when 'policy'
      'fas fa-shield-alt text-info'
    when 'claim'
      'fas fa-file-medical text-warning'
    when 'contract'
      'fas fa-handshake text-primary'
    when 'certificate'
      'fas fa-certificate text-warning'
    when 'correspondence'
      'fas fa-envelope text-secondary'
    when 'financial'
      'fas fa-chart-line text-success'
    when 'legal'
      'fas fa-gavel text-danger'
    when 'compliance'
      'fas fa-clipboard-check text-info'
    when 'marketing'
      'fas fa-bullhorn text-purple'
    when 'training'
      'fas fa-graduation-cap text-info'
    when 'report'
      'fas fa-chart-bar text-primary'
    when 'invoice'
      'fas fa-file-invoice text-success'
    when 'receipt'
      'fas fa-receipt text-success'
    when 'other'
      'fas fa-file text-muted'
    else
      'fas fa-file-alt text-secondary'
    end
  end
  
  def document_type_badge_class(document_type)
    case document_type.to_s.downcase
    when 'application'
      'bg-primary'
    when 'quote'
      'bg-success'
    when 'policy'
      'bg-info'
    when 'claim'
      'bg-warning'
    when 'contract'
      'bg-primary'
    when 'certificate'
      'bg-warning'
    when 'correspondence'
      'bg-secondary'
    when 'financial'
      'bg-success'
    when 'legal'
      'bg-danger'
    when 'compliance'
      'bg-info'
    when 'marketing'
      'bg-purple'
    when 'training'
      'bg-info'
    when 'report'
      'bg-primary'
    when 'invoice'
      'bg-success'
    when 'receipt'
      'bg-success'
    when 'other'
      'bg-secondary'
    else
      'bg-light text-dark'
    end
  end
  
  def format_file_size(size_in_bytes)
    return '0 B' if size_in_bytes.nil? || size_in_bytes.zero?
    
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    size = size_in_bytes.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    "#{size.round(1)} #{units[unit_index]}"
  end
  
  def document_status_badge(document)
    if document.is_archived?
      content_tag(:span, 'Archived', class: 'badge bg-warning')
    elsif document.expired?
      content_tag(:span, 'Expired', class: 'badge bg-danger')
    elsif document.expiring_soon?
      content_tag(:span, 'Expiring Soon', class: 'badge bg-warning')
    else
      content_tag(:span, 'Active', class: 'badge bg-success')
    end
  end
  
  def access_level_badge(access_level)
    case access_level.to_s.downcase
    when 'private'
      content_tag(:span, 'Private', class: 'badge bg-secondary')
    when 'organization'
      content_tag(:span, 'Organization', class: 'badge bg-info')
    when 'public'
      content_tag(:span, 'Public', class: 'badge bg-success')
    else
      content_tag(:span, access_level.humanize, class: 'badge bg-light text-dark')
    end
  end
end
