class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.string :name, null: false
      t.text :description
      t.string :document_type, null: false
      t.bigint :file_size
      t.string :content_type
      t.string :checksum
      t.integer :version, default: 1, null: false
      t.boolean :is_current, default: true, null: false
      t.json :metadata, default: {}
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :documentable, polymorphic: true, null: false
      
      # Additional fields for enhanced document management
      t.string :category
      t.string :tags, array: true, default: []
      t.boolean :is_public, default: false, null: false
      t.boolean :is_archived, default: false, null: false
      t.datetime :archived_at
      t.references :archived_by, null: true, foreign_key: { to_table: :users }
      t.text :archive_reason
      t.datetime :expires_at
      t.string :access_level, default: 'private', null: false

      t.timestamps
    end
    
    add_index :documents, [:organization_id, :document_type]
    add_index :documents, [:documentable_type, :documentable_id]
    add_index :documents, [:is_current, :version]
    add_index :documents, :category
    add_index :documents, :tags, using: 'gin'
    add_index :documents, [:is_archived, :archived_at]
    add_index :documents, :expires_at
  end
end
