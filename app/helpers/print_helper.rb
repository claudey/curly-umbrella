module PrintHelper
  def print_button(text = "Print", css_class = "btn btn-outline btn-sm")
    content_tag :button,
                class: "#{css_class} print-button",
                onclick: "window.print(); return false;",
                data: { print_button: true } do
      concat content_tag(:i, "", class: "ph ph-printer")
      concat " #{text}"
    end
  end

  def risk_level(score)
    case score.to_i
    when 0..30
      "low"
    when 31..70
      "medium"
    else
      "high"
    end
  end

  def print_status_class(status)
    case status.to_s.downcase
    when "active", "approved", "accepted"
      "print-status active"
    when "pending", "submitted", "under_review"
      "print-status pending"
    when "rejected", "expired", "cancelled"
      "print-status rejected"
    else
      "print-status"
    end
  end

  def print_currency(amount)
    return "-" unless amount
    content_tag :span, number_to_currency(amount), class: "print-amount"
  end

  def print_date(date)
    return "-" unless date
    date.strftime("%B %d, %Y")
  end

  def print_datetime(datetime)
    return "-" unless datetime
    datetime.strftime("%B %d, %Y at %I:%M %p")
  end

  def print_field(label, value, options = {})
    css_class = options[:class] || ""
    value_class = options[:value_class] || "print-field-value"

    content_tag :div, class: "print-field-row #{css_class}" do
      concat content_tag(:span, "#{label}:", class: "print-field-label")
      concat content_tag(:span, value.presence || "-", class: value_class)
    end
  end

  def print_section_title(title)
    content_tag :h3, title, class: "print-form-section-title"
  end

  def print_page_break
    content_tag :div, "", class: "page-break"
  end

  def avoid_page_break(&block)
    content_tag :div, class: "avoid-break", &block
  end

  def print_table(headers, rows, options = {})
    css_class = "print-table #{options[:class]}".strip

    content_tag :table, class: css_class do
      concat(content_tag :thead do
        content_tag :tr do
          headers.each do |header|
            concat content_tag(:th, header)
          end
        end
      end)

      concat(content_tag :tbody do
        rows.each do |row|
          concat(content_tag :tr do
            row.each do |cell|
              concat content_tag(:td, cell)
            end
          end)
        end
      end)
    end
  end

  def print_signature_section(title, date_line = true)
    content_tag :div, class: "print-signature-section" do
      if date_line
        concat content_tag(:div, "Date: _________________", style: "margin-bottom: 20pt;")
      end
      concat content_tag(:div, "", class: "print-signature-line")
      concat content_tag(:div, title, style: "margin-top: 5pt; font-weight: bold;")
    end
  end

  def print_organization_header(organization = nil)
    org = organization || current_user&.organization
    return unless org

    content_tag :div, class: "print-header" do
      concat content_tag(:div, org.name, class: "print-logo")
      concat(content_tag :div, class: "print-organization-info" do
        info_parts = []
        if org.contact_info&.dig("address")
          address_parts = [
            org.contact_info["address"],
            org.contact_info["city"],
            org.contact_info["state"],
            org.contact_info["postal_code"]
          ].compact
          info_parts << address_parts.join(", ") if address_parts.any?
        end

        info_parts << org.contact_info["phone"] if org.contact_info&.dig("phone")
        info_parts << org.contact_info["website"] if org.contact_info&.dig("website")

        info_parts.join(" • ")
      end)
    end
  end

  def printable_document_title(application_or_quote)
    case application_or_quote
    when InsuranceApplication
      "#{application_or_quote.insurance_type.humanize} Insurance Application"
    when Quote
      "Insurance Quote - #{application_or_quote.insurance_company&.name}"
    else
      "Document"
    end
  end
end
