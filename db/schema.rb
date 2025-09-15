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

ActiveRecord::Schema[8.0].define(version: 2025_09_15_010426) do
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

  create_table "motor_applications", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "client_id", null: false
    t.string "application_number", null: false
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "rejected_at"
    t.bigint "rejected_by_id"
    t.text "rejection_reason"
    t.string "vehicle_make", null: false
    t.string "vehicle_model", null: false
    t.integer "vehicle_year", null: false
    t.string "vehicle_color"
    t.string "vehicle_chassis_number"
    t.string "vehicle_engine_number"
    t.string "vehicle_registration_number"
    t.decimal "vehicle_value", precision: 15, scale: 2
    t.string "vehicle_category", null: false
    t.string "vehicle_fuel_type"
    t.string "vehicle_transmission"
    t.integer "vehicle_seating_capacity"
    t.string "vehicle_usage", null: false
    t.integer "vehicle_mileage"
    t.string "driver_license_number", null: false
    t.date "driver_license_expiry", null: false
    t.string "driver_license_class"
    t.integer "driver_years_experience"
    t.integer "driver_age"
    t.string "driver_occupation"
    t.boolean "driver_has_claims", default: false, null: false
    t.text "driver_claims_details"
    t.string "coverage_type", null: false
    t.date "coverage_start_date", null: false
    t.date "coverage_end_date", null: false
    t.decimal "sum_insured", precision: 15, scale: 2
    t.decimal "deductible", precision: 15, scale: 2
    t.decimal "premium_amount", precision: 15, scale: 2
    t.decimal "commission_rate", precision: 5, scale: 2
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["application_number"], name: "index_motor_applications_on_application_number", unique: true
    t.index ["approved_by_id"], name: "index_motor_applications_on_approved_by_id"
    t.index ["client_id"], name: "index_motor_applications_on_client_id"
    t.index ["discarded_at"], name: "index_motor_applications_on_discarded_at"
    t.index ["driver_license_number"], name: "index_motor_applications_on_driver_license_number"
    t.index ["organization_id"], name: "index_motor_applications_on_organization_id"
    t.index ["rejected_by_id"], name: "index_motor_applications_on_rejected_by_id"
    t.index ["reviewed_by_id"], name: "index_motor_applications_on_reviewed_by_id"
    t.index ["status"], name: "index_motor_applications_on_status"
    t.index ["submitted_at"], name: "index_motor_applications_on_submitted_at"
    t.index ["vehicle_registration_number"], name: "index_motor_applications_on_vehicle_registration_number"
  end

  create_table "notification_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.boolean "email_new_applications", default: true, null: false
    t.boolean "email_status_updates", default: true, null: false
    t.boolean "email_user_invitations", default: true, null: false
    t.boolean "email_marketing", default: false, null: false
    t.boolean "sms_new_applications", default: false, null: false
    t.boolean "sms_status_updates", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_notification_preferences_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_notification_preferences_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_notification_preferences_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.string "notification_type", null: false
    t.datetime "read_at"
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["organization_id", "notification_type"], name: "index_notifications_on_organization_id_and_notification_type"
    t.index ["organization_id"], name: "index_notifications_on_organization_id"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
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

  create_table "quotes", force: :cascade do |t|
    t.bigint "motor_application_id", null: false
    t.bigint "insurance_company_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "quoted_by_id", null: false
    t.string "quote_number", null: false
    t.decimal "premium_amount", precision: 12, scale: 2
    t.decimal "coverage_amount", precision: 15, scale: 2
    t.decimal "commission_rate", precision: 5, scale: 2
    t.decimal "commission_amount", precision: 12, scale: 2
    t.json "coverage_details"
    t.text "terms_conditions"
    t.integer "validity_period", default: 30
    t.string "status", default: "draft", null: false
    t.datetime "quoted_at"
    t.datetime "accepted_at"
    t.datetime "rejected_at"
    t.datetime "expires_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_quotes_on_expires_at"
    t.index ["insurance_company_id"], name: "index_quotes_on_insurance_company_id"
    t.index ["motor_application_id", "insurance_company_id"], name: "index_quotes_on_motor_application_id_and_insurance_company_id"
    t.index ["motor_application_id"], name: "index_quotes_on_motor_application_id"
    t.index ["organization_id", "status"], name: "index_quotes_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_quotes_on_organization_id"
    t.index ["quote_number"], name: "index_quotes_on_quote_number", unique: true
    t.index ["quoted_by_id"], name: "index_quotes_on_quoted_by_id"
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
  add_foreign_key "motor_applications", "clients"
  add_foreign_key "motor_applications", "organizations"
  add_foreign_key "motor_applications", "users", column: "approved_by_id"
  add_foreign_key "motor_applications", "users", column: "rejected_by_id"
  add_foreign_key "motor_applications", "users", column: "reviewed_by_id"
  add_foreign_key "notification_preferences", "organizations"
  add_foreign_key "notification_preferences", "users"
  add_foreign_key "notifications", "organizations"
  add_foreign_key "notifications", "users"
  add_foreign_key "quotes", "insurance_companies"
  add_foreign_key "quotes", "motor_applications"
  add_foreign_key "quotes", "organizations"
  add_foreign_key "quotes", "users", column: "quoted_by_id"
  add_foreign_key "users", "organizations"
end
