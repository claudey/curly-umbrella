# Claude Development Notes for BrokerSync

## 🔐 Test Login Credentials

**IMPORTANT**: When testing the application or running Playwright tests, use these credentials:

### Universal Password for All Test Accounts
- **Password**: `password123456`
- **Phone**: `+233242422604`

### Test User Accounts
- **Admin User**: `brokersync+admin1@boughtspot.com`
- **Agent User**: `brokers+01@boughtspot.com` (John Doe)
- **Insurance Company User**: `insurance+company1@boughtspot.com`

### Organization Details
- **Premium Insurance Brokers** (primary test org)
  - Subdomain: premium-brokers
  - License: BRK-2024-001
  - Admin: brokersync+admin1@boughtspot.com

## 📋 Application Structure Notes

### Authentication
- ALL controllers require authentication (`before_action :authenticate_user!`)
- Uses Devise for authentication
- Multi-tenant setup with organization-based access

### Navigation Issues Fixed
- Created missing view templates for all sidebar navigation items
- Added routes for clients, life_applications, fire_applications, residential_applications
- Fixed insurance companies route conflicts
- Connected reports to executive dashboard routes

### Database Setup
- Migrations created for new application types (life, fire, residential)
- Models include proper associations and validations
- Status enums and helper methods implemented

## 🧪 Testing Notes

### Running Playwright Tests
- Always use test credentials above when authentication is required
- Server must be running on localhost:3000
- Install browsers first: `npx playwright install`

### Known Working Routes
- `/clients` - Client management
- `/life_applications` - Life insurance applications  
- `/fire_applications` - Fire insurance applications
- `/residential_applications` - Residential insurance applications
- `/insurance_companies_admin` - Insurance company management
- `/settings/organization` - Organization settings
- `/settings/users` - User management
- `/settings/preferences` - User preferences

## 🔧 Development Commands

### Rails Console Access
```bash
rails console -e development
```

### Check User Data
```ruby
User.first.email  # brokersync+admin1@boughtspot.com
User.first.organization.name  # Premium Insurance Brokers
```

### Seed Data
- Full seed data summary available in `SEED_DATA_SUMMARY.md`
- 16 total user accounts across 3 organizations
- Universal password: `password123456`

## 📝 Recent Changes
- Fixed icon rendering issues with phosphor_icons gem
- Created comprehensive view templates for all sidebar sections
- Added database migrations for new application types
- Resolved route naming conflicts
- Updated Organization model with new associations

---
**Last Updated**: Created during sidebar navigation testing session
**Key Reference**: Always check `SEED_DATA_SUMMARY.md` for login credentials