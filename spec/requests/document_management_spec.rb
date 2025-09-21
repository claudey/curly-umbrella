require 'rails_helper'

RSpec.describe "Document Management", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:other_organization) { create(:organization) }
  let(:other_user) { create(:user, organization: other_organization) }

  before { sign_in user }

  describe "Document Upload & Storage" do
    it "uploads document successfully" do
      file = fixture_file_upload('spec/fixtures/test_document.pdf', 'application/pdf')

      expect {
        post documents_path, params: {
          document: {
            name: 'Test Document',
            category: 'policy',
            file: file
          }
        }
      }.to change(Document, :count).by(1)

      expect(response).to redirect_to(document_path(Document.last))
      expect(Document.last.name).to eq('Test Document')
      expect(Document.last.category).to eq('policy')
    end

    it "validates file types" do
      file = fixture_file_upload('spec/fixtures/malicious.exe', 'application/octet-stream')

      post documents_path, params: {
        document: {
          name: 'Malicious File',
          file: file
        }
      }

      expect(assigns(:document).errors[:file]).to be_present
      expect(response).to render_template(:new)
    end

    it "validates file size limits" do
      # Mock a large file
      large_file = double('large_file')
      allow(large_file).to receive(:size).and_return(50.megabytes)
      allow(large_file).to receive(:original_filename).and_return('large_file.pdf')
      allow(large_file).to receive(:content_type).and_return('application/pdf')

      post documents_path, params: {
        document: {
          name: 'Large File',
          file: large_file
        }
      }

      expect(assigns(:document).errors[:file]).to include(/too large/)
    end

    it "categorizes documents correctly" do
      valid_categories = %w[policy claim vehicle_documents property_documents identity_documents financial_documents]

      valid_categories.each do |category|
        file = fixture_file_upload('spec/fixtures/test_document.pdf', 'application/pdf')

        post documents_path, params: {
          document: {
            name: "Test #{category} Document",
            category: category,
            file: file
          }
        }

        expect(response).to redirect_to(document_path(Document.last))
        expect(Document.last.category).to eq(category)
      end
    end

    it "rejects invalid categories" do
      file = fixture_file_upload('spec/fixtures/test_document.pdf', 'application/pdf')

      post documents_path, params: {
        document: {
          name: 'Test Document',
          category: 'invalid_category',
          file: file
        }
      }

      expect(assigns(:document).errors[:category]).to be_present
    end

    it "encrypts sensitive document data" do
      file = fixture_file_upload('spec/fixtures/test_document.pdf', 'application/pdf')

      post documents_path, params: {
        document: {
          name: 'Sensitive Document',
          category: 'confidential',
          sensitive_data: "Confidential information",
          file: file
        }
      }

      document = Document.last

      # Data should be encrypted in database
      raw_data = Document.connection.select_value(
        "SELECT sensitive_data FROM documents WHERE id = #{document.id}"
      )
      expect(raw_data).not_to eq("Confidential information")

      # But accessible normally through model
      expect(document.sensitive_data).to eq("Confidential information")
    end
  end

  describe "Document Access Control" do
    let(:document) { create(:document, organization: organization, user: user) }
    let(:other_document) { create(:document, organization: other_organization, user: other_user) }

    it "allows access to own organization's documents" do
      get document_path(document)
      expect(response).to have_http_status(:success)
    end

    it "denies access to other organization's documents" do
      get document_path(other_document)
      expect(response).to have_http_status(:not_found)
    end

    it "scopes document index to organization" do
      create_list(:document, 3, organization: organization, user: user)
      create_list(:document, 2, organization: other_organization, user: other_user)

      get documents_path

      expect(assigns(:documents).count).to eq(3)
      expect(assigns(:documents).map(&:organization).uniq).to eq([ organization ])
    end

    it "tracks document access" do
      expect {
        get document_path(document)
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('document_viewed')
      expect(audit_log.auditable).to eq(document)
      expect(audit_log.user).to eq(user)
    end

    it "requires authentication for document download" do
      sign_out user

      get download_document_path(document)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "allows authorized document download" do
      get download_document_path(document)
      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to eq('application/pdf')
    end
  end

  describe "Document Search and Filtering" do
    before do
      create(:document, name: 'Motor Insurance Policy', category: 'policy', organization: organization, user: user)
      create(:document, name: 'Fire Insurance Claim', category: 'claim', organization: organization, user: user)
      create(:document, name: 'Vehicle Registration', category: 'vehicle_documents', organization: organization, user: user)
    end

    it "searches documents by name" do
      get documents_path, params: { search: 'Motor' }

      expect(assigns(:documents).count).to eq(1)
      expect(assigns(:documents).first.name).to include('Motor')
    end

    it "filters documents by category" do
      get documents_path, params: { category: 'policy' }

      expect(assigns(:documents).count).to eq(1)
      expect(assigns(:documents).first.category).to eq('policy')
    end

    it "filters documents by date range" do
      old_document = create(:document, organization: organization, user: user, created_at: 1.year.ago)
      new_document = create(:document, organization: organization, user: user, created_at: 1.day.ago)

      get documents_path, params: {
        date_from: 1.week.ago.strftime('%Y-%m-%d'),
        date_to: Date.current.strftime('%Y-%m-%d')
      }

      expect(assigns(:documents)).to include(new_document)
      expect(assigns(:documents)).not_to include(old_document)
    end

    it "combines multiple filters" do
      get documents_path, params: {
        search: 'Insurance',
        category: 'policy'
      }

      expect(assigns(:documents).count).to eq(1)
      expect(assigns(:documents).first.name).to include('Motor Insurance')
    end
  end

  describe "Document Versioning" do
    let(:document) { create(:document, organization: organization, user: user) }

    it "tracks document versions" do
      original_version = document.version

      # Upload new version
      file = fixture_file_upload('spec/fixtures/updated_document.pdf', 'application/pdf')
      post new_version_document_path(document), params: { file: file }

      document.reload
      expect(document.version).to eq(original_version + 1)
      expect(response).to redirect_to(document_path(document))
    end

    it "maintains version history" do
      # Create multiple versions
      3.times do |i|
        file = fixture_file_upload('spec/fixtures/test_document.pdf', 'application/pdf')
        post new_version_document_path(document), params: { file: file }
      end

      get document_path(document)

      expect(document.versions.count).to eq(4) # Original + 3 new versions
    end

    it "allows reverting to previous version" do
      # Create new version
      file = fixture_file_upload('spec/fixtures/updated_document.pdf', 'application/pdf')
      post new_version_document_path(document), params: { file: file }

      current_version = document.reload.version

      # Revert to previous version
      patch revert_document_path(document), params: { version: current_version - 1 }

      expect(response).to redirect_to(document_path(document))
      expect(flash[:notice]).to include('reverted')
    end

    it "prevents reverting to non-existent version" do
      patch revert_document_path(document), params: { version: 999 }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Document Organization" do
    it "creates document folders" do
      folder_params = {
        name: 'Motor Insurance Documents',
        description: 'All motor insurance related documents'
      }

      expect {
        post document_folders_path, params: { document_folder: folder_params }
      }.to change(DocumentFolder, :count).by(1)

      folder = DocumentFolder.last
      expect(folder.name).to eq('Motor Insurance Documents')
      expect(folder.organization).to eq(organization)
    end

    it "moves documents to folders" do
      folder = create(:document_folder, organization: organization)
      document = create(:document, organization: organization, user: user)

      patch move_document_path(document), params: { folder_id: folder.id }

      document.reload
      expect(document.document_folder).to eq(folder)
      expect(response).to redirect_to(document_path(document))
    end

    it "handles bulk document operations" do
      documents = create_list(:document, 3, organization: organization, user: user)
      document_ids = documents.map(&:id)

      # Bulk move to folder
      folder = create(:document_folder, organization: organization)

      patch bulk_move_documents_path, params: {
        document_ids: document_ids,
        folder_id: folder.id
      }

      documents.each(&:reload)
      expect(documents.all? { |doc| doc.document_folder == folder }).to be true
    end

    it "handles bulk document deletion" do
      documents = create_list(:document, 3, organization: organization, user: user)
      document_ids = documents.map(&:id)

      expect {
        delete bulk_delete_documents_path, params: { document_ids: document_ids }
      }.to change(Document, :count).by(-3)
    end
  end

  describe "Document Archiving" do
    let(:document) { create(:document, organization: organization, user: user) }

    it "archives documents" do
      patch archive_document_path(document), params: {
        archive_reason: 'Document is outdated'
      }

      document.reload
      expect(document.archived?).to be true
      expect(document.archived_at).to be_present
      expect(document.archive_reason).to eq('Document is outdated')
    end

    it "excludes archived documents from default listing" do
      archived_doc = create(:document, organization: organization, user: user, archived_at: 1.day.ago)
      active_doc = create(:document, organization: organization, user: user)

      get documents_path

      expect(assigns(:documents)).to include(active_doc)
      expect(assigns(:documents)).not_to include(archived_doc)
    end

    it "shows archived documents when requested" do
      archived_doc = create(:document, organization: organization, user: user, archived_at: 1.day.ago)

      get documents_path, params: { show_archived: true }

      expect(assigns(:documents)).to include(archived_doc)
    end

    it "restores archived documents" do
      document.update!(archived_at: 1.day.ago, archive_reason: 'Test archival')

      patch restore_document_path(document)

      document.reload
      expect(document.archived?).to be false
      expect(document.archived_at).to be_nil
    end
  end

  describe "Document Sharing" do
    let(:document) { create(:document, organization: organization, user: user) }
    let(:team_member) { create(:user, organization: organization) }

    it "shares document with team members" do
      share_params = {
        user_ids: [ team_member.id ],
        permission_level: 'view',
        expires_at: 1.week.from_now
      }

      expect {
        post share_document_path(document), params: share_params
      }.to change(DocumentShare, :count).by(1)

      share = DocumentShare.last
      expect(share.document).to eq(document)
      expect(share.user).to eq(team_member)
      expect(share.permission_level).to eq('view')
    end

    it "prevents sharing with users from other organizations" do
      share_params = {
        user_ids: [ other_user.id ],
        permission_level: 'view'
      }

      expect {
        post share_document_path(document), params: share_params
      }.not_to change(DocumentShare, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "allows shared users to access documents" do
      DocumentShare.create!(
        document: document,
        user: team_member,
        permission_level: 'view'
      )

      sign_in team_member
      get document_path(document)

      expect(response).to have_http_status(:success)
    end

    it "respects permission levels in shares" do
      DocumentShare.create!(
        document: document,
        user: team_member,
        permission_level: 'view'
      )

      sign_in team_member

      # Should be able to view
      get document_path(document)
      expect(response).to have_http_status(:success)

      # Should not be able to edit
      patch document_path(document), params: { document: { name: 'Hacked Name' } }
      expect(response).to have_http_status(:forbidden)
    end

    it "expires shared access" do
      DocumentShare.create!(
        document: document,
        user: team_member,
        permission_level: 'view',
        expires_at: 1.day.ago
      )

      sign_in team_member
      get document_path(document)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "Document Analytics" do
    let!(:documents) { create_list(:document, 5, organization: organization, user: user) }

    it "tracks document views" do
      document = documents.first

      expect {
        get document_path(document)
      }.to change { document.reload.view_count }.by(1)
    end

    it "provides usage statistics" do
      # Generate some activity
      documents.each { |doc| get document_path(doc) }

      get document_analytics_path

      expect(assigns(:total_documents)).to eq(5)
      expect(assigns(:total_views)).to eq(5)
      expect(assigns(:storage_used)).to be_present
    end

    it "shows most accessed documents" do
      # Create documents with different view counts
      documents[0].update!(view_count: 10)
      documents[1].update!(view_count: 5)
      documents[2].update!(view_count: 1)

      get document_analytics_path

      most_viewed = assigns(:most_viewed_documents)
      expect(most_viewed.first).to eq(documents[0])
      expect(most_viewed.second).to eq(documents[1])
    end
  end

  describe "Document Security" do
    let(:document) { create(:document, organization: organization, user: user) }

    it "generates secure download URLs" do
      get secure_download_document_path(document)

      expect(response).to redirect_to(/secure_download/)

      # URL should contain security token
      redirect_url = response.headers['Location']
      expect(redirect_url).to include('token=')
    end

    it "validates download tokens" do
      # Generate valid token
      token = document.generate_download_token

      get "/documents/#{document.id}/secure_download", params: { token: token }
      expect(response).to have_http_status(:success)

      # Invalid token should fail
      get "/documents/#{document.id}/secure_download", params: { token: 'invalid' }
      expect(response).to have_http_status(:forbidden)
    end

    it "expires download tokens" do
      # Create expired token
      token = document.generate_download_token(expires_at: 1.hour.ago)

      get "/documents/#{document.id}/secure_download", params: { token: token }
      expect(response).to have_http_status(:forbidden)
    end

    it "detects suspicious download patterns" do
      # Simulate rapid downloads (potential scraping)
      10.times do
        get download_document_path(document)
      end

      # Should trigger security alert
      expect(SecurityAlert.where(
        user: user,
        alert_type: 'suspicious_download_pattern'
      ).count).to be > 0
    end
  end

  describe "Document API Access" do
    let(:api_key) { create(:api_key, organization: organization) }

    it "allows API access with valid key" do
      get api_v1_documents_path, headers: {
        'Authorization' => "Bearer #{api_key.key}",
        'Accept' => 'application/json'
      }

      expect(response).to have_http_status(:success)

      json_response = JSON.parse(response.body)
      expect(json_response['documents']).to be_an(Array)
    end

    it "enforces rate limits on API" do
      # Make multiple rapid requests
      20.times do
        get api_v1_documents_path, headers: {
          'Authorization' => "Bearer #{api_key.key}",
          'Accept' => 'application/json'
        }
      end

      expect(response).to have_http_status(:too_many_requests)
    end

    it "tracks API usage" do
      get api_v1_documents_path, headers: {
        'Authorization' => "Bearer #{api_key.key}",
        'Accept' => 'application/json'
      }

      api_key.reload
      expect(api_key.request_count).to be > 0
      expect(api_key.last_used_at).to be_present
    end
  end

  describe "Error Handling" do
    it "handles file upload errors gracefully" do
      # Simulate storage failure
      allow_any_instance_of(ActiveStorage::Blob).to receive(:upload).and_raise(StandardError)

      file = fixture_file_upload('spec/fixtures/test_document.pdf', 'application/pdf')

      post documents_path, params: {
        document: {
          name: 'Test Document',
          file: file
        }
      }

      expect(response).to render_template(:new)
      expect(flash[:alert]).to include('upload failed')
    end

    it "handles corrupted files" do
      # Mock a corrupted file
      corrupted_file = double('corrupted_file')
      allow(corrupted_file).to receive(:original_filename).and_return('corrupted.pdf')
      allow(corrupted_file).to receive(:content_type).and_return('application/pdf')
      allow(corrupted_file).to receive(:size).and_return(1000)
      allow(corrupted_file).to receive(:read).and_raise(StandardError.new('Corrupted file'))

      post documents_path, params: {
        document: {
          name: 'Corrupted Document',
          file: corrupted_file
        }
      }

      expect(assigns(:document).errors[:file]).to be_present
    end

    it "handles storage quota exceeded" do
      # Mock storage quota exceeded
      allow_any_instance_of(Organization).to receive(:storage_quota_exceeded?).and_return(true)

      file = fixture_file_upload('spec/fixtures/test_document.pdf', 'application/pdf')

      post documents_path, params: {
        document: {
          name: 'Test Document',
          file: file
        }
      }

      expect(response).to render_template(:new)
      expect(assigns(:document).errors[:base]).to include(/storage quota/)
    end
  end
end
