#!/bin/bash

echo "Testing Sidebar Navigation URLs..."
echo "================================="

# Base URL
BASE_URL="http://localhost:3000"

# Function to test URL
test_url() {
    local url=$1
    local name=$2
    
    status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$url")
    
    if [[ $status == "302" ]]; then
        echo "✅ $name ($url) - Working (redirects to login)"
    elif [[ $status == "200" ]]; then
        echo "✅ $name ($url) - Working (loads directly)"
    else
        echo "❌ $name ($url) - Error (HTTP $status)"
    fi
}

echo ""
echo "Dashboard & Search:"
test_url "/" "Dashboard"
test_url "/search" "Global Search"

echo ""
echo "Clients Section:"
test_url "/clients" "All Clients"
test_url "/clients/new" "Add Client"

echo ""
echo "Applications Section:"
test_url "/motor_applications" "Motor Insurance"
test_url "/life_applications" "Life Insurance"
test_url "/fire_applications" "Fire Insurance" 
test_url "/residential_applications" "Residential Insurance"

echo ""
echo "Quotes Section:"
test_url "/quotes" "All Quotes"
test_url "/quotes/pending" "Pending Reviews"
test_url "/quotes/expiring_soon" "Expiring Soon"

echo ""
echo "Documents Section:"
test_url "/documents" "All Documents"
test_url "/documents/new" "Upload Document"
test_url "/documents/archived" "Archived"
test_url "/documents/expiring" "Expiring Soon"

echo ""
echo "Insurance Companies Section:"
test_url "/insurance_companies_admin" "All Companies"
test_url "/insurance_companies_admin/pending" "Pending Approval"

echo ""
echo "Reports Section:"
test_url "/executive/performance" "Performance"
test_url "/executive/analytics" "Analytics"

echo ""
echo "Settings Section:"
test_url "/settings/organization" "Organization"
test_url "/settings/users" "Users"
test_url "/settings/preferences" "Preferences"

echo ""
echo "Admin Section:"
test_url "/admin/organizations" "Organizations"
test_url "/admin/organizations/analytics" "Analytics"

echo ""
echo "Test Complete!"
echo "✅ = Working correctly"
echo "❌ = Has issues"