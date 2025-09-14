# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_14_231742) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "brokerage_agents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "agent", null: false
    t.boolean "active", default: true, null: false
    t.date "join_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["active"], name: "index_brokerage_agents_on_active"
    t.index ["discarded_at"], name: "index_brokerage_agents_on_discarded_at"
    t.index ["organization_id"], name: "index_brokerage_agents_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_brokerage_agents_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_brokerage_agents_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.date "date_of_birth"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "Ghana"
    t.string "id_number"
    t.string "id_type"
    t.string "occupation"
    t.string "employer"
    t.decimal "annual_income", precision: 15, scale: 2
    t.string "marital_status"
    t.string "next_of_kin"
    t.string "next_of_kin_phone"
    t.string "emergency_contact"
    t.string "emergency_contact_phone"
    t.string "preferred_contact_method", default: "email"
    t.text "communication_preferences"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_clients_on_discarded_at"
    t.index ["email"], name: "index_clients_on_email"
    t.index ["first_name", "last_name"], name: "index_clients_on_first_name_and_last_name"
    t.index ["id_number"], name: "index_clients_on_id_number"
    t.index ["organization_id"], name: "index_clients_on_organization_id"
    t.index ["phone"], name: "index_clients_on_phone"
  end

  create_table "insurance_companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "business_registration_number", null: false
    t.string "license_number", null: false
    t.string "contact_person", null: false
    t.string "email", null: false
    t.string "phone"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "Ghana"
    t.string "website"
    t.text "insurance_types"
    t.decimal "rating", precision: 3, scale: 2, default: "0.0"
    t.decimal "commission_rate", precision: 5, scale: 2, default: "0.0"
    t.text "terms_and_conditions"
    t.string "payment_terms", default: "net_30"
    t.boolean "active", default: true, null: false
    t.boolean "approved", default: false, null: false
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["active"], name: "index_insurance_companies_on_active"
    t.index ["approved"], name: "index_insurance_companies_on_approved"
    t.index ["approved_by_id"], name: "index_insurance_companies_on_approved_by_id"
    t.index ["business_registration_number"], name: "index_insurance_companies_on_business_registration_number", unique: true
    t.index ["discarded_at"], name: "index_insurance_companies_on_discarded_at"
    t.index ["email"], name: "index_insurance_companies_on_email", unique: true
    t.index ["license_number"], name: "index_insurance_companies_on_license_number", unique: true
    t.index ["name"], name: "index_insurance_companies_on_name"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "license_number", null: false
    t.jsonb "contact_info", default: {}
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["license_number"], name: "index_organizations_on_license_number", unique: true
    t.index ["name"], name: "index_organizations_on_name"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.integer "role"
    t.bigint "organization_id", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "brokerage_agents", "organizations"
  add_foreign_key "brokerage_agents", "users"
  add_foreign_key "clients", "organizations"
  add_foreign_key "insurance_companies", "users", column: "approved_by_id"
  add_foreign_key "users", "organizations"
end
