require 'rails_helper'

RSpec.describe DocumentsHelper, type: :helper do
  describe "#document_icon_class" do
    it "returns correct icon class for application document type" do
      expect(helper.document_icon_class("application")).to eq("fas fa-file-contract text-primary")
    end

    it "returns correct icon class for quote document type" do
      expect(helper.document_icon_class("quote")).to eq("fas fa-file-invoice-dollar text-success")
    end

    it "returns correct icon class for policy document type" do
      expect(helper.document_icon_class("policy")).to eq("fas fa-shield-alt text-info")
    end

    it "returns correct icon class for claim document type" do
      expect(helper.document_icon_class("claim")).to eq("fas fa-file-medical text-warning")
    end

    it "returns default icon class for unknown document type" do
      expect(helper.document_icon_class("unknown")).to eq("fas fa-file-alt text-secondary")
    end

    it "handles case insensitive document types" do
      expect(helper.document_icon_class("APPLICATION")).to eq("fas fa-file-contract text-primary")
      expect(helper.document_icon_class("Quote")).to eq("fas fa-file-invoice-dollar text-success")
    end

    it "handles nil document type" do
      expect(helper.document_icon_class(nil)).to eq("fas fa-file-alt text-secondary")
    end
  end

  describe "#document_type_badge_class" do
    it "returns correct badge class for application document type" do
      expect(helper.document_type_badge_class("application")).to eq("bg-primary")
    end

    it "returns correct badge class for quote document type" do
      expect(helper.document_type_badge_class("quote")).to eq("bg-success")
    end

    it "returns correct badge class for policy document type" do
      expect(helper.document_type_badge_class("policy")).to eq("bg-info")
    end

    it "returns default badge class for unknown document type" do
      expect(helper.document_type_badge_class("unknown")).to eq("bg-light text-dark")
    end

    it "handles case insensitive document types" do
      expect(helper.document_type_badge_class("APPLICATION")).to eq("bg-primary")
      expect(helper.document_type_badge_class("Quote")).to eq("bg-success")
    end
  end

  describe "#format_file_size" do
    it "formats bytes correctly" do
      expect(helper.format_file_size(0)).to eq("0 B")
      expect(helper.format_file_size(512)).to eq("512.0 B")
      expect(helper.format_file_size(1023)).to eq("1023.0 B")
    end

    it "formats kilobytes correctly" do
      expect(helper.format_file_size(1024)).to eq("1.0 KB")
      expect(helper.format_file_size(1536)).to eq("1.5 KB")
      expect(helper.format_file_size(1024 * 1023)).to eq("1023.0 KB")
    end

    it "formats megabytes correctly" do
      expect(helper.format_file_size(1024 * 1024)).to eq("1.0 MB")
      expect(helper.format_file_size(1024 * 1024 * 1.5)).to eq("1.5 MB")
    end

    it "formats gigabytes correctly" do
      expect(helper.format_file_size(1024 * 1024 * 1024)).to eq("1.0 GB")
      expect(helper.format_file_size(1024 * 1024 * 1024 * 2.5)).to eq("2.5 GB")
    end

    it "formats terabytes correctly" do
      expect(helper.format_file_size(1024 * 1024 * 1024 * 1024)).to eq("1.0 TB")
    end

    it "handles nil and zero values" do
      expect(helper.format_file_size(nil)).to eq("0 B")
      expect(helper.format_file_size(0)).to eq("0 B")
    end
  end

  describe "#document_status_badge" do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, organization: organization) }
    let(:documentable) { create(:insurance_application, organization: organization) }

    it "returns archived badge for archived document" do
      document = create(:document,
        organization: organization,
        user: user,
        documentable: documentable,
        is_archived: true
      )

      expect(helper.document_status_badge(document)).to include("Archived")
      expect(helper.document_status_badge(document)).to include("badge bg-warning")
    end

    it "returns expired badge for expired document" do
      document = create(:document,
        organization: organization,
        user: user,
        documentable: documentable,
        expires_at: 1.day.ago
      )

      expect(helper.document_status_badge(document)).to include("Expired")
      expect(helper.document_status_badge(document)).to include("badge bg-danger")
    end

    it "returns expiring soon badge for document expiring soon" do
      document = create(:document,
        organization: organization,
        user: user,
        documentable: documentable,
        expires_at: 15.days.from_now
      )

      expect(helper.document_status_badge(document)).to include("Expiring Soon")
      expect(helper.document_status_badge(document)).to include("badge bg-warning")
    end

    it "returns active badge for active document" do
      document = create(:document,
        organization: organization,
        user: user,
        documentable: documentable,
        expires_at: 60.days.from_now
      )

      expect(helper.document_status_badge(document)).to include("Active")
      expect(helper.document_status_badge(document)).to include("badge bg-success")
    end
  end

  describe "#access_level_badge" do
    it "returns correct badge for private access level" do
      result = helper.access_level_badge("private")
      expect(result).to include("Private")
      expect(result).to include("badge bg-secondary")
    end

    it "returns correct badge for organization access level" do
      result = helper.access_level_badge("organization")
      expect(result).to include("Organization")
      expect(result).to include("badge bg-info")
    end

    it "returns correct badge for public access level" do
      result = helper.access_level_badge("public")
      expect(result).to include("Public")
      expect(result).to include("badge bg-success")
    end

    it "returns default badge for unknown access level" do
      result = helper.access_level_badge("confidential")
      expect(result).to include("Confidential")
      expect(result).to include("badge bg-light text-dark")
    end

    it "handles case insensitive access levels" do
      result = helper.access_level_badge("PRIVATE")
      expect(result).to include("Private")
      expect(result).to include("badge bg-secondary")
    end
  end
end
