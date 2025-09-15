class PdfGenerationService
  attr_reader :options, :content, :filename

  def initialize(content, filename = nil, options = {})
    @content = content
    @filename = filename || "document_#{Time.current.to_i}.pdf"
    @options = default_options.merge(options)
  end

  def self.generate_application_pdf(application)
    renderer = ApplicationController.new
    renderer.request = ActionDispatch::TestRequest.create

    content = renderer.render_to_string(
      template: 'shared/print_application',
      layout: 'pdf',
      locals: { application: application },
      formats: [:html]
    )

    filename = "application_#{application.application_number || application.id}.pdf"
    new(content, filename).generate
  end

  def self.generate_quote_pdf(quote)
    renderer = ApplicationController.new  
    renderer.request = ActionDispatch::TestRequest.create

    content = renderer.render_to_string(
      template: 'quotes/print',
      layout: 'pdf', 
      locals: { quote: quote },
      formats: [:html]
    )

    filename = "quote_#{quote.quote_number || quote.id}.pdf"
    new(content, filename).generate
  end

  def self.generate_document_list_pdf(documents, title = "Document List")
    renderer = ApplicationController.new
    renderer.request = ActionDispatch::TestRequest.create

    content = renderer.render_to_string(
      template: 'documents/print_list',
      layout: 'pdf',
      locals: { documents: documents, title: title },
      formats: [:html]
    )

    filename = "document_list_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf"
    new(content, filename).generate
  end

  def self.generate_custom_pdf(template, locals = {}, filename = nil)
    renderer = ApplicationController.new
    renderer.request = ActionDispatch::TestRequest.create

    content = renderer.render_to_string(
      template: template,
      layout: 'pdf',
      locals: locals,
      formats: [:html]
    )

    filename ||= "custom_document_#{Time.current.to_i}.pdf"
    new(content, filename).generate
  end

  def generate
    pdf_data = WickedPdf.new.pdf_from_string(content, @options)
    
    # Create a temporary file to store the PDF
    temp_file = Tempfile.new([@filename.gsub('.pdf', ''), '.pdf'])
    temp_file.binmode
    temp_file.write(pdf_data)
    temp_file.rewind
    
    # Return file path and cleanup callback
    {
      file_path: temp_file.path,
      filename: @filename,
      cleanup: -> { temp_file.close; temp_file.unlink }
    }
  rescue => e
    Rails.logger.error "PDF Generation failed: #{e.message}"
    raise PdfGenerationError, "Failed to generate PDF: #{e.message}"
  end

  def generate_and_attach_to_document!(document)
    result = generate
    
    # Attach the generated PDF to a document
    File.open(result[:file_path], 'rb') do |file|
      document.file.attach(
        io: file,
        filename: result[:filename],
        content_type: 'application/pdf'
      )
    end
    
    # Clean up temporary file
    result[:cleanup].call
    
    document
  rescue => e
    result[:cleanup].call if result&.dig(:cleanup)
    raise e
  end

  def stream_download
    result = generate
    
    # Return the file for streaming download
    {
      file_path: result[:file_path],
      filename: result[:filename],
      content_type: 'application/pdf',
      cleanup: result[:cleanup]
    }
  end

  private

  def default_options
    {
      page_size: 'A4',
      orientation: 'Portrait',
      margin: {
        top: 20,
        bottom: 20,
        left: 15,
        right: 15
      },
      encoding: 'UTF-8',
      print_media_type: true,
      disable_smart_shrinking: true,
      dpi: 300,
      image_dpi: 300,
      image_quality: 94,
      javascript_delay: 1000,
      window_status: 'ready',
      footer: {
        right: 'Page [page] of [topage]',
        font_size: 10,
        spacing: 10
      },
      header: {
        spacing: 10
      }
    }
  end

  class PdfGenerationError < StandardError; end
end