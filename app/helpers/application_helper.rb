module ApplicationHelper
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
end
