# BrokerSync Seed Data Summary

## Overview
This document summarizes the sample data that has been seeded into the BrokerSync application for development and testing purposes.

## 🏢 Brokerage Organizations (3)

### 1. Premium Insurance Brokers
- **Subdomain**: premium-brokers
- **License Number**: BRK-2024-001
- **Users**: 7 (1 admin + 3 agents + 3 insurance company users)
- **Location**: 123 Business District, Accra, Ghana

### 2. Elite Risk Solutions
- **Subdomain**: elite-risk  
- **License Number**: BRK-2024-002
- **Users**: 5 (1 admin + 4 agents)
- **Location**: 456 Corporate Avenue, Kumasi, Ghana

### 3. Secure Shield Brokers
- **Subdomain**: secure-shield
- **License Number**: BRK-2024-003
- **Users**: 4 (1 admin + 3 agents)
- **Location**: 789 Insurance Row, Takoradi, Ghana

## 🏬 Insurance Companies (2)

### 1. Ghana National Insurance Company
- **Email**: insurance@boughtspot.com
- **License**: INS-LIC-001
- **Commission Rate**: 15.0%
- **Insurance Types**: Motor, Fire, Liability, General Accident
- **Payment Terms**: Net 30 days
- **Rating**: 4.5/5.0

### 2. Star Assurance Company
- **Email**: insure@boughtspot.com
- **License**: INS-LIC-002
- **Commission Rate**: 18.0%
- **Insurance Types**: Motor, Fire, Bonds, General Accident
- **Payment Terms**: Net 15 days
- **Rating**: 4.2/5.0

## 👥 User Accounts (16 total)

### Brokerage Administrators (3)
- **brokersync+admin1@boughtspot.com** - Admin User1 (Premium Insurance Brokers)
- **brokersync+admin2@boughtspot.com** - Admin User2 (Elite Risk Solutions)
- **brokersync+admin3@boughtspot.com** - Admin User3 (Secure Shield Brokers)

### Insurance Agents (10)
| Email | Name | Organization | Role |
|-------|------|-------------|------|
| brokers+01@boughtspot.com | John Doe | Premium Insurance Brokers | Agent |
| brokers+02@boughtspot.com | Jane Smith | Premium Insurance Brokers | Team Lead |
| brokers+03@boughtspot.com | Michael Johnson | Premium Insurance Brokers | Senior Agent |
| brokers+05@boughtspot.com | David Brown | Elite Risk Solutions | Agent |
| brokers+06@boughtspot.com | Emma Davis | Elite Risk Solutions | Team Lead |
| brokers+07@boughtspot.com | James Miller | Elite Risk Solutions | Team Lead |
| brokers+08@boughtspot.com | Lisa Garcia | Elite Risk Solutions | Team Lead |
| brokers+09@boughtspot.com | Robert Martinez | Secure Shield Brokers | Agent |
| brokers+10@boughtspot.com | Amanda Anderson | Secure Shield Brokers | Senior Agent |
| brokers+11@boughtspot.com | Agent10 User | Secure Shield Brokers | Senior Agent |

### Insurance Company Users (3)
- **insurance+company1@boughtspot.com** - Kwame Asante (Ghana National Insurance Company)
- **insurance+company2@boughtspot.com** - Akosua Mensah (Star Assurance Company)
- **insurance+company3@boughtspot.com** - Yaw Osei (Insurance Company User)

## 👤 Client Records (15 total)

### Premium Insurance Brokers Clients (5)
- **Kofi Asante** (kofi.asante@example.com) - Age 35, Married
- **Akosua Mensah** (akosua.mensah@example.com) - Age 28, Single  
- **Kwame Osei** (kwame.osei@example.com) - Age 45, Married
- **Ama Boateng** (ama.boateng@example.com) - Age 32, Divorced
- **Yaw Darko** (yaw.darko@example.com) - Age 29, Single

### Elite Risk Solutions Clients (5)
- **Efua Ampong** (efua.ampong@example.com) - Age 38, Married
- **Samuel Adjei** (samuel.adjei@example.com) - Age 42, Married
- **Grace Owusu** (grace.owusu@example.com) - Age 26, Single
- **Daniel Nkrumah** (daniel.nkrumah@example.com) - Age 31, Married
- **Abena Sarpong** (abena.sarpong@example.com) - Age 27, Single

### Secure Shield Brokers Clients (5)
- **Prince Adusei** (prince.adusei@example.com) - Age 39, Married
- **Mavis Appiah** (mavis.appiah@example.com) - Age 33, Divorced
- **Ibrahim Mohammed** (ibrahim.mohammed@example.com) - Age 41, Married
- **Gifty Asare** (gifty.asare@example.com) - Age 25, Single
- **Francis Twum** (francis.twum@example.com) - Age 36, Married

## 📋 Insurance Applications (1)

### Sample Applications
- **MI2025090001** - Motor Insurance (Draft Status)
  - Vehicle: Toyota Camry (2020)
  - Registration: GR-1234-AB
  - Client: Kofi Asante
  - Agent: John Doe

## 🔐 Login Credentials

**Universal Password**: `password123456`
**Universal Phone Number**: `+233242422604`

### Test Account Access
You can log in to any of the above accounts using:
- Email address from the lists above
- Password: `password123456`

## 📧 Email Variants Used

The seed data uses email variants as specified:
- **brokersync@boughtspot.com** variants for admins
- **broker@boughtspot.com** / **brokers@boughtspot.com** variants for agents  
- **insurance@boughtspot.com** / **insure@boughtspot.com** variants for insurance companies

## 🎯 Key Features Demonstrated

### Multi-Tenancy
- Each organization operates independently with its own users and clients
- Cross-organization data isolation is maintained

### Role-Based Access
- **Brokerage Admins**: Full access to their organization's data
- **Agents**: Can create applications and manage client relationships
- **Insurance Company Users**: Can view distributed applications and create quotes

### Insurance Types Supported
- **Motor Insurance**: Vehicle-related coverage
- **Fire Insurance**: Property fire damage coverage  
- **Liability Insurance**: Business liability coverage
- **General Accident Insurance**: Personal accident coverage
- **Bonds Insurance**: Contract and performance bonds

### Application Workflow
- Applications start in **Draft** status
- Can be **Submitted** for review
- Progress through **Under Review**, **Approved**, or **Rejected** states

## 🚀 Next Steps

To extend the seed data:
1. Run `bin/rails db:seed` to create the base data
2. Manually create additional applications using the Rails console
3. Generate quotes for submitted applications
4. Create notification preferences and audit logs

## 📝 Notes

- All timestamps are set to realistic values within the past 30 days
- Client ages range from 25-45 years with realistic demographic data
- Insurance companies have different commission rates and coverage types
- All data follows the application's validation rules and business logic