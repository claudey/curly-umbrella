namespace :admin do
  desc "Create a super admin user"
  task create_super_admin: :environment do
    # Temporarily disable tenant isolation for this task
    ActsAsTenant.without_tenant do
    email = ENV['ADMIN_EMAIL'] || 'admin@brokersync.com'
    password = ENV['ADMIN_PASSWORD'] || 'SuperAdmin123!'
    first_name = ENV['ADMIN_FIRST_NAME'] || 'Super'
    last_name = ENV['ADMIN_LAST_NAME'] || 'Admin'
    
    # Create a dummy organization for the super admin
    admin_org = Organization.find_or_create_by(name: 'BrokerSync Admin') do |org|
      org.subdomain = 'admin'
      org.license_number = 'ADMIN-001'
      org.description = 'System administration organization'
      org.active = true
    end
    
    # Create or find the super admin user
    admin_user = User.find_or_initialize_by(email: email) do |user|
      user.first_name = first_name
      user.last_name = last_name
      user.phone = '000-000-0000'
      user.role = 'super_admin'
      user.organization = admin_org
      user.password = password
      user.password_confirmation = password
    end
    
    if admin_user.persisted?
      puts "Super admin already exists: #{admin_user.email}"
    elsif admin_user.save
      puts "Super admin created successfully!"
      puts "Email: #{admin_user.email}"
      puts "Password: #{password}"
      puts "Role: #{admin_user.role}"
      puts ""
      puts "You can now sign in at: http://localhost:3000/users/sign_in"
    else
      puts "Failed to create super admin:"
      admin_user.errors.full_messages.each do |error|
        puts "  - #{error}"
      end
    end
    end # ActsAsTenant.without_tenant
  end
  
  desc "List all super admin users"
  task list_super_admins: :environment do
    ActsAsTenant.without_tenant do
      super_admins = User.where(role: 'super_admin')
      
      if super_admins.any?
        puts "Super Admin Users:"
        puts "-" * 50
        super_admins.each do |admin|
          puts "Name: #{admin.full_name}"
          puts "Email: #{admin.email}"
          puts "Organization: #{admin.organization.name}"
          puts "Created: #{admin.created_at.strftime('%B %d, %Y at %I:%M %p')}"
          puts "-" * 30
        end
      else
        puts "No super admin users found."
        puts "Run 'rake admin:create_super_admin' to create one."
      end
    end
  end
end