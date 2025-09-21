# frozen_string_literal: true

module Entities
  class DocumentEntity < Grape::Entity
    expose :id, documentation: { type: "Integer", desc: "Document ID" }
    expose :filename, documentation: { type: "String", desc: "Original filename" }
    expose :document_type, documentation: { type: "String", desc: "Type of document" }
    expose :file_size, documentation: { type: "Integer", desc: "File size in bytes" }
    expose :content_type, documentation: { type: "String", desc: "MIME content type" }
    expose :status, documentation: { type: "String", desc: "Document processing status" }
    expose :created_at, documentation: { type: "DateTime", desc: "Upload timestamp" }
    expose :updated_at, documentation: { type: "DateTime", desc: "Last update timestamp" }

    # File information
    expose :file_info, documentation: { type: "Object", desc: "File metadata" } do |document|
      {
        size_human: format_file_size(document.file_size),
        extension: File.extname(document.filename),
        is_image: document.content_type&.start_with?("image/"),
        is_pdf: document.content_type == "application/pdf"
      }
    end

    # Download information
    expose :download_info, documentation: { type: "Object", desc: "Download information" } do |document|
      {
        download_url: "/api/v1/documents/#{document.id}/download",
        expires_at: 1.hour.from_now.iso8601
      }
    end

    # Processing information
    expose :processing_info, documentation: { type: "Object", desc: "Document processing information" } do |document|
      {
        status: document.status,
        processed_at: document.processed_at,
        processing_notes: document.processing_notes
      }
    end

    private

    def self.format_file_size(size)
      return "0 B" if size.nil? || size.zero?

      units = [ "B", "KB", "MB", "GB", "TB" ]
      unit_index = 0
      size_float = size.to_f

      while size_float >= 1024 && unit_index < units.length - 1
        size_float /= 1024
        unit_index += 1
      end

      "#{size_float.round(2)} #{units[unit_index]}"
    end
  end
end
