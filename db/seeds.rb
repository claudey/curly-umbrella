# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Starting to seed the database..."

# Clear existing data in development
if Rails.env.development?
  puts "🧹 Clearing existing data..."
  begin
    Quote.delete_all
    InsuranceApplication.delete_all
    Client.delete_all
    BrokerageAgent.delete_all
    User.delete_all
    InsuranceCompany.delete_all
    Organization.delete_all
  rescue => e
    puts "⚠️  Warning: #{e.message}"
  end
end

# 1. Create Organizations (Brokerages)
puts "🏢 Creating brokerage organizations..."

brokerages = [
  {
    name: "Premium Insurance Brokers",
    subdomain: "premium-brokers",
    license_number: "BRK-2024-001",
    billing_email: "billing@premiumbrokers.com",
    contact_info: {
      address: "123 Business District, Accra, Ghana",
      phone: "+233242422604",
      email: "info@premiumbrokers.com"
    }
  },
  {
    name: "Elite Risk Solutions",
    subdomain: "elite-risk",
    license_number: "BRK-2024-002", 
    billing_email: "billing@eliterisk.com",
    contact_info: {
      address: "456 Corporate Avenue, Kumasi, Ghana",
      phone: "+233242422604",
      email: "info@eliterisk.com"
    }
  },
  {
    name: "Secure Shield Brokers",
    subdomain: "secure-shield",
    license_number: "BRK-2024-003",
    billing_email: "billing@secureshield.com",
    contact_info: {
      address: "789 Insurance Row, Takoradi, Ghana",
      phone: "+233242422604",
      email: "info@secureshield.com"
    }
  }
]

created_orgs = brokerages.map do |brokerage_data|
  Organization.find_or_create_by(subdomain: brokerage_data[:subdomain]) do |org|
    org.assign_attributes(brokerage_data)
  end.tap do |org|
    puts "  ✅ Created/Found: #{org.name}"
  end
end

# 2. Create Insurance Companies
puts "🏬 Creating insurance companies..."

insurance_companies_data = [
  {
    name: "Ghana National Insurance Company",
    business_registration_number: "GH-INS-001",
    license_number: "INS-LIC-001",
    contact_person: "Kwame Asante",
    email: "insurance@boughtspot.com",
    phone: "+233242422604",
    website: "https://gnic.com.gh",
    insurance_types: "motor,fire,liability,general_accident",
    commission_rate: 15.0,
    payment_terms: "net_30",
    rating: 4.5,
    active: true,
    approved: true,
    approved_at: 1.month.ago
  },
  {
    name: "Star Assurance Company",
    business_registration_number: "GH-INS-002",
    license_number: "INS-LIC-002",
    contact_person: "Akosua Mensah",
    email: "insure@boughtspot.com",
    phone: "+233242422604",
    website: "https://starassurance.com.gh",
    insurance_types: "motor,fire,bonds,general_accident",
    commission_rate: 18.0,
    payment_terms: "net_15",
    rating: 4.2,
    active: true,
    approved: true,
    approved_at: 2.weeks.ago
  },
  {
    name: "Metropolitan Insurance Ltd",
    business_registration_number: "GH-INS-003",
    license_number: "INS-LIC-003",
    contact_person: "Yaw Osei",
    email: "Insurance@boughtspot.com",
    phone: "+233242422604",
    website: "https://metinsurance.com.gh",
    insurance_types: "liability,bonds,fire",
    commission_rate: 12.0,
    payment_terms: "net_45",
    rating: 4.0,
    active: true,
    approved: true,
    approved_at: 3.weeks.ago
  }
]

created_insurance_companies = insurance_companies_data.map do |company_data|
  InsuranceCompany.find_or_create_by(license_number: company_data[:license_number]) do |company|
    company.assign_attributes(company_data)
  end.tap do |company|
    puts "  ✅ Created/Found: #{company.name}"
  end
end

# 3. Create Users (Agents, Admins, Insurance Company Users)
puts "👥 Creating users..."

# For each organization, create various users
all_users = []

created_orgs.each_with_index do |org, org_index|
  # Create admin user
  admin_email = "brokersync+admin#{org_index + 1}@boughtspot.com"
  admin = User.find_or_create_by(email: admin_email) do |user|
    user.organization = org
    user.password = "password123456"
    user.password_confirmation = "password123456"
    user.first_name = "Admin"
    user.last_name = "User#{org_index + 1}"
    user.phone = "+233242422604"
    user.role = "brokerage_admin"
  end
  all_users << admin
  puts "  ✅ Created/Found admin: #{admin.email}"

  # Create 3-4 agents per organization
  agent_count = [3, 4, 3][org_index]
  agent_names = [
    ["John", "Doe"], ["Jane", "Smith"], ["Michael", "Johnson"], ["Sarah", "Wilson"],
    ["David", "Brown"], ["Emma", "Davis"], ["James", "Miller"], ["Lisa", "Garcia"],
    ["Robert", "Martinez"], ["Amanda", "Anderson"]
  ]

  agent_count.times do |i|
    agent_index = (org_index * 4) + i
    first_name, last_name = agent_names[agent_index] || ["Agent#{agent_index}", "User"]
    
    agent_email = "brokers+#{'%02d' % (agent_index + 1)}@boughtspot.com"
    agent = User.find_or_create_by(email: agent_email) do |user|
      user.organization = org
      user.password = "password123456"
      user.password_confirmation = "password123456"
      user.first_name = first_name
      user.last_name = last_name
      user.phone = "+233242422604"
      user.role = "agent"
    end
    all_users << agent
    
    # Create BrokerageAgent record
    brokerage_agent = nil
    if agent.persisted?
      brokerage_agent = BrokerageAgent.find_or_create_by(user: agent, organization: org) do |ba|
        ba.role = ["agent", "senior_agent", "team_lead"].sample
        ba.active = true
        ba.join_date = rand(1..24).months.ago
      end
    end
    
    role_info = brokerage_agent ? brokerage_agent.role : "no role"
    puts "  ✅ Created/Found agent: #{agent.email} (#{role_info})"
  end
end

# Create insurance company users
created_insurance_companies.each_with_index do |company, index|
  # Use the first organization as a default for multi-tenancy
  company_email = "insurance+company#{index + 1}@boughtspot.com"
  company_user = User.find_or_create_by(email: company_email) do |user|
    user.organization = created_orgs.first
    user.password = "password123456"
    user.password_confirmation = "password123456"
    user.first_name = company.contact_person.split.first
    user.last_name = company.contact_person.split.last
    user.phone = "+233242422604"
    user.role = "insurance_company"
  end
  all_users << company_user
  puts "  ✅ Created/Found insurance company user: #{company_user.email}"
end

# 4. Create Clients
puts "👤 Creating clients..."

client_data = [
  {first_name: "Kofi", last_name: "Asante", email: "kofi.asante@example.com", date_of_birth: 35.years.ago, marital_status: "married", id_type: "national_id"},
  {first_name: "Akosua", last_name: "Mensah", email: "akosua.mensah@example.com", date_of_birth: 28.years.ago, marital_status: "single", id_type: "passport"},
  {first_name: "Kwame", last_name: "Osei", email: "kwame.osei@example.com", date_of_birth: 45.years.ago, marital_status: "married", id_type: "drivers_license"},
  {first_name: "Ama", last_name: "Boateng", email: "ama.boateng@example.com", date_of_birth: 32.years.ago, marital_status: "divorced", id_type: "national_id"},
  {first_name: "Yaw", last_name: "Darko", email: "yaw.darko@example.com", date_of_birth: 29.years.ago, marital_status: "single", id_type: "national_id"},
  {first_name: "Efua", last_name: "Ampong", email: "efua.ampong@example.com", date_of_birth: 38.years.ago, marital_status: "married", id_type: "passport"},
  {first_name: "Samuel", last_name: "Adjei", email: "samuel.adjei@example.com", date_of_birth: 42.years.ago, marital_status: "married", id_type: "drivers_license"},
  {first_name: "Grace", last_name: "Owusu", email: "grace.owusu@example.com", date_of_birth: 26.years.ago, marital_status: "single", id_type: "national_id"},
  {first_name: "Daniel", last_name: "Nkrumah", email: "daniel.nkrumah@example.com", date_of_birth: 31.years.ago, marital_status: "married", id_type: "national_id"},
  {first_name: "Abena", last_name: "Sarpong", email: "abena.sarpong@example.com", date_of_birth: 27.years.ago, marital_status: "single", id_type: "passport"},
  {first_name: "Prince", last_name: "Adusei", email: "prince.adusei@example.com", date_of_birth: 39.years.ago, marital_status: "married", id_type: "drivers_license"},
  {first_name: "Mavis", last_name: "Appiah", email: "mavis.appiah@example.com", date_of_birth: 33.years.ago, marital_status: "divorced", id_type: "national_id"},
  {first_name: "Ibrahim", last_name: "Mohammed", email: "ibrahim.mohammed@example.com", date_of_birth: 41.years.ago, marital_status: "married", id_type: "national_id"},
  {first_name: "Gifty", last_name: "Asare", email: "gifty.asare@example.com", date_of_birth: 25.years.ago, marital_status: "single", id_type: "passport"},
  {first_name: "Francis", last_name: "Twum", email: "francis.twum@example.com", date_of_birth: 36.years.ago, marital_status: "married", id_type: "drivers_license"}
]

clients_per_org = (client_data.length / created_orgs.length.to_f).ceil
all_clients = []

created_orgs.each_with_index do |org, org_index|
  start_index = org_index * clients_per_org
  end_index = [start_index + clients_per_org - 1, client_data.length - 1].min
  
  (start_index..end_index).each do |i|
    next if client_data[i].nil?
    
    client = Client.create!(
      organization: org,
      phone: "+233242422604",
      preferred_contact_method: ["email", "phone", "sms"].sample,
      **client_data[i]
    )
    all_clients << client
    puts "  ✅ Created client: #{client.full_name}"
  end
end

# 5. Create Insurance Applications
puts "📋 Creating insurance applications..."

insurance_types = ["motor", "fire", "liability", "general_accident", "bonds"]
statuses = ["draft", "submitted", "under_review", "approved", "rejected"]

applications_data = []

# Create 20 applications distributed across types
20.times do |i|
  org = created_orgs.sample
  client = all_clients.select { |c| c.organization_id == org.id }.sample
  agents = all_users.select { |u| u.organization_id == org.id && u.role == "agent" }
  agent = agents.sample
  
  # Skip if no agent found
  next if agent.nil?
  insurance_type = insurance_types.sample
  
  # Create appropriate application data based on type
  application_data = case insurance_type
  when "motor"
    {
      "vehicle_make" => ["Toyota", "Honda", "Nissan", "Hyundai", "Kia"].sample,
      "vehicle_model" => ["Camry", "Corolla", "Civic", "Accord", "Elantra"].sample,
      "vehicle_year" => rand(2015..2024).to_s,
      "registration_number" => "GR-#{rand(1000..9999)}-#{('A'..'Z').to_a.sample(2).join}",
      "chassis_number" => "#{('A'..'Z').to_a.sample(3).join}#{rand(1000000..9999999)}",
      "engine_number" => "ENG#{rand(100000..999999)}",
      "driver_license_number" => "DL#{rand(100000..999999)}",
      "vehicle_usage" => ["personal", "business", "commercial"].sample,
      "vehicle_color" => ["White", "Black", "Silver", "Blue", "Red"].sample
    }
  when "fire"
    {
      "property_type" => ["residential", "commercial", "industrial"].sample,
      "property_value" => rand(100000..5000000).to_s,
      "property_address" => "#{rand(1..999)} #{['Airport', 'Cantonments', 'East Legon', 'Labone', 'Osu'].sample} Street, Accra",
      "construction_type" => ["concrete", "wood", "mixed"].sample,
      "occupancy_type" => ["owner_occupied", "tenant_occupied", "vacant"].sample,
      "fire_safety_measures" => ["smoke_detectors", "fire_extinguishers", "sprinkler_system"].sample(rand(1..3)).join(", ")
    }
  when "liability"
    {
      "business_type" => ["retail", "office", "manufacturing", "construction"].sample,
      "liability_type" => ["public", "professional", "product"].sample,
      "coverage_scope" => "General business operations",
      "annual_turnover" => rand(500000..10000000).to_s,
      "number_of_employees" => rand(5..100).to_s,
      "business_description" => "Standard business operations requiring liability coverage"
    }
  when "general_accident"
    {
      "coverage_type" => ["personal_accident", "group_accident", "travel_accident"].sample,
      "occupation" => ["office", "education", "transport", "construction"].sample,
      "annual_income" => rand(50000..500000).to_s,
      "beneficiary_details" => "Primary beneficiary information on file",
      "medical_history" => "No significant medical history",
      "lifestyle_factors" => ["non_smoker", "occasional_drinker", "regular_exercise"].sample(rand(1..3)).join(", ")
    }
  when "bonds"
    {
      "bond_type" => ["performance", "payment", "bid"].sample,
      "principal_amount" => rand(1000000..50000000).to_s,
      "contract_details" => "Government contract requiring bond coverage",
      "project_description" => "Infrastructure development project",
      "contractor_experience" => "#{rand(5..20)} years in construction",
      "performance_history" => "Excellent track record with previous projects"
    }
  end
  
  applications_data << {
    organization: org,
    client: client,
    user: agent,
    insurance_type: insurance_type,
    status: ["draft", "submitted"].sample,
    application_data: application_data,
    sum_insured: rand(100000..5000000).to_f,
    premium_amount: rand(5000..50000).to_f,
    commission_rate: rand(10.0..20.0).round(2).to_f
  }
end

created_applications = []
applications_data.each_with_index do |app_data, index|
  application = InsuranceApplication.create!(app_data)
  created_applications << application
  puts "  ✅ Created application #{index + 1}: #{application.insurance_type_display_name} (#{application.application_number})"
end

# 6. Create Quotes for some applications
puts "💰 Creating quotes..."

# Create 1-3 quotes for submitted/approved applications
quote_count = 0
created_applications.select { |app| ["submitted", "under_review", "approved"].include?(app.status) }.each do |application|
  quotes_to_create = rand(1..3)
  
  quotes_to_create.times do |i|
    company = created_insurance_companies.sample
    agent = all_users.select { |u| u.role == "insurance_company" }.sample
    
    # Vary quote amounts around the application premium
    base_premium = application.premium_amount || rand(5000..50000)
    quote_premium = (base_premium * (0.8 + rand * 0.4)).round(2)
    
    quote = Quote.create!(
      insurance_application: application,
      insurance_company: company,
      organization: application.organization,
      quoted_by: agent,
      premium_amount: quote_premium,
      coverage_amount: application.sum_insured || rand(100000..5000000),
      commission_rate: company.commission_rate,
      validity_period: [7, 14, 21, 30].sample,
      status: ["draft", "submitted", "approved", "rejected"].sample,
      coverage_details: {
        "basic_coverage" => "Standard coverage as per policy terms",
        "deductible" => rand(1000..10000),
        "policy_term" => "12 months"
      },
      notes: "Competitive quote based on risk assessment",
      quoted_at: rand(14.days).seconds.ago
    )
    quote_count += 1
    puts "  ✅ Created quote #{quote_count}: #{quote.quote_number} (#{company.name})"
  end
end

# 7. Create some additional relevant data
puts "📊 Creating additional data..."

# Create notification preferences for all users
all_users.each do |user|
  unless user.notification_preference
    NotificationPreference.create!(
      user: user,
      organization: user.organization,
      email_enabled: true,
      sms_enabled: [true, false].sample,
      whatsapp_enabled: [true, false].sample,
      application_submitted: true,
      application_approved: true,
      quote_received: true,
      quote_expiring: true,
      system_alerts: user.role.in?(["super_admin", "brokerage_admin"])
    )
  end
end

puts "  ✅ Created notification preferences for all users"

# Summary
puts "\n🎉 Database seeding completed successfully!"
puts "\n📊 Summary of created records:"
puts "  🏢 Organizations (Brokerages): #{created_orgs.count}"
puts "  🏬 Insurance Companies: #{created_insurance_companies.count}"
puts "  👥 Users: #{all_users.count}"
puts "     - Admins: #{all_users.count { |u| u.role == 'brokerage_admin' }}"
puts "     - Agents: #{all_users.count { |u| u.role == 'agent' }}"
puts "     - Insurance Company Users: #{all_users.count { |u| u.role == 'insurance_company' }}"
puts "  👤 Clients: #{all_clients.count}"
puts "  📋 Insurance Applications: #{created_applications.count}"
puts "     - Motor: #{created_applications.count { |a| a.insurance_type == 'motor' }}"
puts "     - Fire: #{created_applications.count { |a| a.insurance_type == 'fire' }}"
puts "     - Liability: #{created_applications.count { |a| a.insurance_type == 'liability' }}"
puts "     - General Accident: #{created_applications.count { |a| a.insurance_type == 'general_accident' }}"
puts "     - Bonds: #{created_applications.count { |a| a.insurance_type == 'bonds' }}"
puts "  💰 Quotes: #{quote_count}"
puts "\n🔐 All accounts use password: password123456"
puts "📞 All phone numbers: +233242422604"