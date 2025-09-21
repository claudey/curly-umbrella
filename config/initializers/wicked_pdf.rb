WickedPdf.configure do |config|
  # Use binary from gem
  config.exe_path = Gem.bin_path("wkhtmltopdf-binary", "wkhtmltopdf")

  # Global options for all PDFs
  config.orientation = "Portrait"
  config.page_size = "A4"
  config.margin = {
    top: 20,    # mm
    bottom: 20,
    left: 15,
    right: 15
  }
  config.encoding = "UTF-8"
  config.print_media_type = true
  config.disable_smart_shrinking = true
  config.use_xserver = false

  # Additional options for better rendering
  config.dpi = 300
  config.image_dpi = 300
  config.image_quality = 94
  config.lowquality = false

  # JavaScript and CSS handling
  config.javascript_delay = 1000
  config.window_status = "ready"
  config.no_stop_slow_scripts = true
end
