require 'rails_helper'

RSpec.describe Document, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:documentable) { create(:insurance_application, organization: organization) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:user) }
    it { should belong_to(:documentable) }
    it { should belong_to(:archived_by).class_name('User').optional }
  end

  describe 'validations' do
    subject { build(:document, organization: organization, user: user, documentable: documentable) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:document_type) }
    it { should validate_inclusion_of(:document_type).in_array(Document::DOCUMENT_TYPES) }
    it { should validate_presence_of(:version) }
    it { should validate_numericality_of(:version).is_greater_than(0) }
    it { should validate_presence_of(:access_level) }
    it { should validate_inclusion_of(:access_level).in_array(Document::ACCESS_LEVELS) }
    it { should validate_inclusion_of(:category).in_array(Document::CATEGORIES).allow_blank }

    it 'requires file attachment' do
      document = build(:document, organization: organization, user: user, documentable: documentable)
      document.file = nil
      expect(document).to_not be_valid
      expect(document.errors[:file]).to include('must be attached')
    end

    it 'validates expires_at is in the future' do
      document = build(:document, 
        organization: organization, 
        user: user, 
        documentable: documentable,
        expires_at: 1.day.ago
      )
      expect(document).to_not be_valid
      expect(document.errors[:expires_at]).to include('must be in the future')
    end
  end

  describe 'scopes' do
    let!(:current_doc) { create(:document, organization: organization, user: user, documentable: documentable, is_current: true) }
    let!(:archived_doc) { create(:document, organization: organization, user: user, documentable: documentable, is_archived: true) }
    let!(:public_doc) { create(:document, organization: organization, user: user, documentable: documentable, is_public: true) }
    let!(:expiring_doc) { create(:document, organization: organization, user: user, documentable: documentable, expires_at: 15.days.from_now) }
    let!(:expired_doc) { create(:document, organization: organization, user: user, documentable: documentable, expires_at: 1.day.ago) }

    it 'filters current documents' do
      expect(Document.current).to include(current_doc)
      expect(Document.current).to_not include(archived_doc)
    end

    it 'filters archived documents' do
      expect(Document.archived).to include(archived_doc)
      expect(Document.archived).to_not include(current_doc)
    end

    it 'filters not archived documents' do
      expect(Document.not_archived).to include(current_doc)
      expect(Document.not_archived).to_not include(archived_doc)
    end

    it 'filters public documents' do
      expect(Document.public_documents).to include(public_doc)
    end

    it 'filters expiring soon documents' do
      expect(Document.expiring_soon(30)).to include(expiring_doc)
      expect(Document.expiring_soon(30)).to_not include(expired_doc)
    end

    it 'filters expired documents' do
      expect(Document.expired).to include(expired_doc)
      expect(Document.expired).to_not include(expiring_doc)
    end
  end

  describe 'file methods' do
    let(:document) { create(:document, organization: organization, user: user, documentable: documentable) }

    it 'returns true when file is attached' do
      expect(document.file_attached?).to be true
    end

    it 'generates file URL when file is attached' do
      expect(document.file_url).to be_present
    end

    it 'generates download URL when file is attached' do
      expect(document.download_url).to include('disposition=attachment')
    end

    it 'generates preview URL when file is attached' do
      expect(document.preview_url).to include('disposition=inline')
    end
  end

  describe '#human_file_size' do
    it 'returns unknown when file_size is nil' do
      document = build(:document, organization: organization, user: user, documentable: documentable, file_size: nil)
      expect(document.human_file_size).to eq("Unknown")
    end

    it 'formats bytes correctly' do
      document = build(:document, organization: organization, user: user, documentable: documentable, file_size: 1024)
      expect(document.human_file_size).to eq("1.0 KB")
    end

    it 'formats megabytes correctly' do
      document = build(:document, organization: organization, user: user, documentable: documentable, file_size: 1024 * 1024)
      expect(document.human_file_size).to eq("1.0 MB")
    end
  end

  describe 'expiration methods' do
    it 'detects expired documents' do
      document = build(:document, expires_at: 1.day.ago)
      expect(document.expired?).to be true
    end

    it 'detects non-expired documents' do
      document = build(:document, expires_at: 1.day.from_now)
      expect(document.expired?).to be false
    end

    it 'detects documents expiring soon' do
      document = build(:document, expires_at: 15.days.from_now)
      expect(document.expiring_soon?(30)).to be true
    end

    it 'detects documents not expiring soon' do
      document = build(:document, expires_at: 60.days.from_now)
      expect(document.expiring_soon?(30)).to be false
    end
  end

  describe 'permission methods' do
    let(:document_owner) { user }
    let(:other_user) { create(:user, organization: organization) }
    let(:admin_user) { create(:user, organization: organization, role: 'brokerage_admin') }
    let(:external_user) { create(:user) }

    context 'public document' do
      let(:document) { create(:document, organization: organization, user: document_owner, documentable: documentable, access_level: 'public') }

      it 'can be viewed by anyone' do
        expect(document.can_be_viewed_by?(other_user)).to be true
        expect(document.can_be_viewed_by?(external_user)).to be true
      end
    end

    context 'private document' do
      let(:document) { create(:document, organization: organization, user: document_owner, documentable: documentable, access_level: 'private') }

      it 'can be viewed by owner' do
        expect(document.can_be_viewed_by?(document_owner)).to be true
      end

      it 'can be viewed by admin' do
        expect(document.can_be_viewed_by?(admin_user)).to be true
      end

      it 'cannot be viewed by other users' do
        expect(document.can_be_viewed_by?(other_user)).to be false
      end
    end

    context 'archived document' do
      let(:document) { create(:document, organization: organization, user: document_owner, documentable: documentable, is_archived: true) }

      it 'cannot be edited when archived' do
        expect(document.can_be_edited_by?(document_owner)).to be false
        expect(document.can_be_edited_by?(admin_user)).to be false
      end

      it 'cannot be deleted when archived' do
        expect(document.can_be_deleted_by?(document_owner)).to be false
        expect(document.can_be_deleted_by?(admin_user)).to be false
      end
    end
  end

  describe 'archiving' do
    let(:document) { create(:document, organization: organization, user: user, documentable: documentable) }
    let(:admin) { create(:user, organization: organization, role: 'brokerage_admin') }

    it 'archives document with reason' do
      reason = "No longer needed"
      expect(document.archive!(admin, reason)).to be true
      
      document.reload
      expect(document.is_archived?).to be true
      expect(document.archived_by).to eq(admin)
      expect(document.archive_reason).to eq(reason)
      expect(document.archived_at).to be_present
    end

    it 'cannot archive already archived document' do
      document.update!(is_archived: true)
      expect(document.archive!(admin)).to be false
    end

    it 'restores archived document' do
      document.update!(is_archived: true, archived_by: admin, archived_at: Time.current)
      
      expect(document.restore!(admin)).to be true
      
      document.reload
      expect(document.is_archived?).to be false
      expect(document.archived_by).to be_nil
      expect(document.archived_at).to be_nil
      expect(document.archive_reason).to be_nil
    end
  end

  describe 'file type detection' do
    it 'detects image files' do
      document = build(:document, content_type: 'image/jpeg')
      expect(document.is_image?).to be true
    end

    it 'detects PDF files' do
      document = build(:document, content_type: 'application/pdf')
      expect(document.is_pdf?).to be true
    end

    it 'detects text files' do
      document = build(:document, content_type: 'text/plain')
      expect(document.is_text?).to be true
    end

    it 'returns correct icon class for different file types' do
      pdf_doc = build(:document, content_type: 'application/pdf')
      image_doc = build(:document, content_type: 'image/jpeg')
      text_doc = build(:document, content_type: 'text/plain')

      expect(pdf_doc.icon_class).to eq('ph-file-pdf')
      expect(image_doc.icon_class).to eq('ph-image')
      expect(text_doc.icon_class).to eq('ph-file-text')
    end
  end

  describe 'versioning' do
    let(:document) { create(:document, organization: organization, user: user, documentable: documentable, name: 'Test Document') }

    it 'creates new version of document' do
      new_file = File.open(Rails.root.join('test-documents/fire-insurance/building_permit.pdf'))
      
      new_document = document.create_new_version!(new_file, user, description: 'Updated version')
      
      expect(new_document.version).to eq(document.version + 1)
      expect(new_document.is_current?).to be true
      
      document.reload
      expect(document.is_current?).to be false
    end

    it 'returns version history' do
      new_file = File.open(Rails.root.join('test-documents/fire-insurance/building_permit.pdf'))
      new_document = document.create_new_version!(new_file, user)
      
      history = new_document.version_history
      expect(history.count).to eq(2)
      expect(history.first).to eq(new_document)
      expect(history.last).to eq(document)
    end

    it 'finds previous and next versions' do
      new_file = File.open(Rails.root.join('test-documents/fire-insurance/building_permit.pdf'))
      new_document = document.create_new_version!(new_file, user)
      
      expect(new_document.previous_version).to eq(document)
      expect(document.next_version).to eq(new_document)
    end
  end

  describe 'callbacks' do
    it 'sets file metadata on save' do
      document = build(:document, organization: organization, user: user, documentable: documentable)
      document.save!
      
      expect(document.file_size).to be_present
      expect(document.content_type).to be_present
      expect(document.checksum).to be_present
    end

    it 'ensures single current version' do
      document1 = create(:document, organization: organization, user: user, documentable: documentable, name: 'Test', is_current: true)
      document2 = create(:document, organization: organization, user: user, documentable: documentable, name: 'Test', is_current: true)
      
      document1.reload
      expect(document1.is_current?).to be false
      expect(document2.is_current?).to be true
    end
  end
end
