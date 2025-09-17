# BrokerSync API Documentation

## Table of Contents
1. [Overview](#overview)
2. [Authentication](#authentication)
3. [Rate Limiting](#rate-limiting)
4. [Error Handling](#error-handling)
5. [API Endpoints](#api-endpoints)
6. [Code Examples](#code-examples)
7. [SDKs and Libraries](#sdks-and-libraries)
8. [Changelog](#changelog)

---

## Overview

The BrokerSync API provides comprehensive access to the insurance brokerage platform, enabling insurance companies, agents, and third-party integrations to interact with applications, quotes, documents, and analytics data.

### Base URL
```
Production: https://api.brokersync.com/api/v1
Staging: https://staging-api.brokersync.com/api/v1
```

### API Version
Current version: **v1**

### Content Type
All API requests and responses use JSON format:
```
Content-Type: application/json
```

### Response Format
All API responses follow a consistent structure:
```json
{
  "success": true,
  "data": {},
  "meta": {},
  "errors": []
}
```

---

## Authentication

The BrokerSync API supports two authentication methods:

### 1. JWT Authentication (Recommended)
Used for user-based authentication and session management.

**Request Header:**
```
Authorization: Bearer <jwt_token>
```

**Obtaining a JWT Token:**
```bash
curl -X POST https://api.brokersync.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "secure_password"
  }'
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_at": "2024-01-15T10:30:00Z",
    "user": {
      "id": 123,
      "email": "user@example.com",
      "role": "insurance_company"
    }
  }
}
```

### 2. API Key Authentication
Used for server-to-server communication and automated integrations.

**Request Header:**
```
X-API-Key: <api_key>
```

**API Key Scopes:**
- `read`: Read access to applications and quotes
- `write`: Create and update applications and quotes
- `analytics`: Access to analytics and reporting data
- `admin`: Administrative operations (user management, etc.)

---

## Rate Limiting

API requests are subject to rate limiting to ensure fair usage and system stability.

### Rate Limits by Tier

| Tier | Requests per Hour | Burst Limit |
|------|------------------|-------------|
| Free | 1,000 | 100 |
| Professional | 10,000 | 500 |
| Enterprise | 100,000 | 2,000 |

### Rate Limit Headers
Every API response includes rate limiting information:

```
X-RateLimit-Limit: 10000
X-RateLimit-Remaining: 9875
X-RateLimit-Reset: 1640995200
X-RateLimit-Retry-After: 3600
```

### Rate Limit Exceeded Response
```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Try again in 3600 seconds.",
    "retry_after": 3600
  }
}
```

---

## Error Handling

The API uses conventional HTTP response codes and provides detailed error information.

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 422 | Unprocessable Entity |
| 429 | Rate Limited |
| 500 | Internal Server Error |

### Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contains invalid data.",
    "details": {
      "field_errors": {
        "email": ["is required"],
        "amount": ["must be greater than 0"]
      }
    },
    "request_id": "req_1234567890"
  }
}
```

### Common Error Codes

| Code | Description |
|------|-------------|
| `AUTHENTICATION_FAILED` | Invalid credentials or token |
| `AUTHORIZATION_FAILED` | Insufficient permissions |
| `VALIDATION_ERROR` | Request data validation failed |
| `RESOURCE_NOT_FOUND` | Requested resource doesn't exist |
| `RATE_LIMIT_EXCEEDED` | Too many requests |
| `INTERNAL_ERROR` | Server error |

---

## API Endpoints

### Applications

#### List Applications
```
GET /applications
```

**Parameters:**
- `page` (integer, optional): Page number (default: 1)
- `per_page` (integer, optional): Items per page (default: 20, max: 100)
- `status` (string, optional): Filter by status (`draft`, `submitted`, `under_review`, `approved`, `rejected`)
- `insurance_type` (string, optional): Filter by type (`motor`, `fire`, `liability`, `general_accident`, `bonds`)
- `created_after` (string, optional): ISO 8601 date string
- `created_before` (string, optional): ISO 8601 date string

**Example Request:**
```bash
curl -X GET "https://api.brokersync.com/api/v1/applications?status=submitted&per_page=50" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "applications": [
      {
        "id": 12345,
        "application_number": "APP-2024-001234",
        "insurance_type": "motor",
        "status": "submitted",
        "applicant": {
          "name": "John Doe",
          "email": "john@example.com",
          "phone": "+1234567890"
        },
        "coverage": {
          "amount": 50000,
          "currency": "USD",
          "deductible": 1000
        },
        "risk_assessment": {
          "score": 7.5,
          "category": "medium"
        },
        "submitted_at": "2024-01-10T14:30:00Z",
        "created_at": "2024-01-10T10:15:00Z",
        "updated_at": "2024-01-10T14:30:00Z"
      }
    ],
    "pagination": {
      "current_page": 1,
      "total_pages": 25,
      "total_count": 1250,
      "per_page": 50
    }
  }
}
```

#### Get Application Details
```
GET /applications/{id}
```

**Example Request:**
```bash
curl -X GET "https://api.brokersync.com/api/v1/applications/12345" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "application": {
      "id": 12345,
      "application_number": "APP-2024-001234",
      "insurance_type": "motor",
      "status": "submitted",
      "applicant": {
        "name": "John Doe",
        "email": "john@example.com",
        "phone": "+1234567890",
        "address": {
          "street": "123 Main St",
          "city": "New York",
          "state": "NY",
          "zip": "10001",
          "country": "US"
        }
      },
      "vehicle": {
        "make": "Toyota",
        "model": "Camry",
        "year": 2022,
        "vin": "1HGBH41JXMN109186",
        "license_plate": "ABC123",
        "usage": "personal"
      },
      "coverage": {
        "liability": {
          "bodily_injury": 100000,
          "property_damage": 50000
        },
        "comprehensive": 25000,
        "collision": 25000,
        "deductible": 1000
      },
      "documents": [
        {
          "id": 456,
          "type": "drivers_license",
          "filename": "license.pdf",
          "upload_date": "2024-01-10T11:00:00Z",
          "status": "verified"
        }
      ],
      "quotes": [
        {
          "id": 789,
          "insurance_company": "ABC Insurance",
          "premium": 1200,
          "status": "pending"
        }
      ]
    }
  }
}
```

#### Create Application
```
POST /applications
```

**Request Body:**
```json
{
  "application": {
    "insurance_type": "motor",
    "applicant": {
      "name": "John Doe",
      "email": "john@example.com",
      "phone": "+1234567890",
      "date_of_birth": "1985-06-15",
      "address": {
        "street": "123 Main St",
        "city": "New York",
        "state": "NY",
        "zip": "10001",
        "country": "US"
      }
    },
    "vehicle": {
      "make": "Toyota",
      "model": "Camry",
      "year": 2022,
      "vin": "1HGBH41JXMN109186",
      "license_plate": "ABC123",
      "usage": "personal",
      "annual_mileage": 12000
    },
    "coverage": {
      "liability": {
        "bodily_injury": 100000,
        "property_damage": 50000
      },
      "comprehensive": 25000,
      "collision": 25000,
      "deductible": 1000
    }
  }
}
```

#### Submit Application
```
POST /applications/{id}/submit
```

**Example Request:**
```bash
curl -X POST "https://api.brokersync.com/api/v1/applications/12345/submit" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json"
```

### Quotes

#### List Quotes
```
GET /quotes
```

**Parameters:**
- `application_id` (integer, optional): Filter by application
- `status` (string, optional): Filter by status (`pending`, `approved`, `rejected`, `expired`)
- `insurance_company_id` (integer, optional): Filter by insurance company

#### Create Quote
```
POST /quotes
```

**Request Body:**
```json
{
  "quote": {
    "application_id": 12345,
    "premium": 1200.00,
    "coverage_details": {
      "liability": {
        "bodily_injury": 100000,
        "property_damage": 50000
      },
      "comprehensive": 25000,
      "collision": 25000,
      "deductible": 1000
    },
    "terms": {
      "policy_period": 12,
      "effective_date": "2024-02-01",
      "expiration_date": "2025-02-01"
    },
    "conditions": [
      "Driver must complete defensive driving course",
      "Vehicle must have anti-theft device"
    ]
  }
}
```

#### Accept Quote
```
POST /quotes/{id}/accept
```

### Documents

#### Upload Document
```
POST /applications/{application_id}/documents
```

**Request (multipart/form-data):**
```bash
curl -X POST "https://api.brokersync.com/api/v1/applications/12345/documents" \
  -H "Authorization: Bearer <jwt_token>" \
  -F "document[file]=@/path/to/document.pdf" \
  -F "document[type]=drivers_license" \
  -F "document[description]=Driver's license copy"
```

#### Get Documents
```
GET /applications/{application_id}/documents
```

### Analytics

#### Usage Analytics
```
GET /analytics/usage
```

**Parameters:**
- `start_date` (string): ISO 8601 date string
- `end_date` (string): ISO 8601 date string
- `granularity` (string): `hour`, `day`, `week`, `month`

**Example Response:**
```json
{
  "success": true,
  "data": {
    "usage": {
      "api_calls": 15420,
      "applications_created": 45,
      "quotes_generated": 67,
      "documents_uploaded": 123
    },
    "trends": [
      {
        "date": "2024-01-10",
        "api_calls": 1200,
        "applications": 5,
        "quotes": 8
      }
    ]
  }
}
```

### Feature Flags

#### Check Feature Flags
```
GET /feature_flags/check
```

**Parameters:**
- `keys[]` (array): Array of feature flag keys to check
- `user_id` (integer, optional): User ID for user-specific flags
- `context` (object, optional): Additional context for flag evaluation

**Example Request:**
```bash
curl -X GET "https://api.brokersync.com/api/v1/feature_flags/check?keys[]=new_dashboard_ui&keys[]=api_v2&user_id=123" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "results": {
      "new_dashboard_ui": false,
      "api_v2": true
    },
    "user_id": 123,
    "checked_at": "2024-01-10T15:30:00Z"
  }
}
```

---

## Code Examples

### JavaScript/Node.js

```javascript
const axios = require('axios');

class BrokerSyncAPI {
  constructor(apiKey, baseURL = 'https://api.brokersync.com/api/v1') {
    this.apiKey = apiKey;
    this.baseURL = baseURL;
    this.client = axios.create({
      baseURL: this.baseURL,
      headers: {
        'X-API-Key': this.apiKey,
        'Content-Type': 'application/json'
      }
    });
  }

  async getApplications(options = {}) {
    try {
      const response = await this.client.get('/applications', { params: options });
      return response.data;
    } catch (error) {
      throw new Error(`API Error: ${error.response?.data?.error?.message || error.message}`);
    }
  }

  async createApplication(applicationData) {
    try {
      const response = await this.client.post('/applications', { application: applicationData });
      return response.data;
    } catch (error) {
      throw new Error(`API Error: ${error.response?.data?.error?.message || error.message}`);
    }
  }

  async submitApplication(applicationId) {
    try {
      const response = await this.client.post(`/applications/${applicationId}/submit`);
      return response.data;
    } catch (error) {
      throw new Error(`API Error: ${error.response?.data?.error?.message || error.message}`);
    }
  }
}

// Usage Example
const api = new BrokerSyncAPI('your-api-key');

// List applications
api.getApplications({ status: 'submitted', per_page: 10 })
  .then(data => console.log('Applications:', data.data.applications))
  .catch(error => console.error('Error:', error.message));

// Create new application
const newApplication = {
  insurance_type: 'motor',
  applicant: {
    name: 'John Doe',
    email: 'john@example.com',
    phone: '+1234567890'
  },
  vehicle: {
    make: 'Toyota',
    model: 'Camry',
    year: 2022,
    vin: '1HGBH41JXMN109186'
  }
};

api.createApplication(newApplication)
  .then(data => {
    console.log('Application created:', data.data.application);
    return api.submitApplication(data.data.application.id);
  })
  .then(data => console.log('Application submitted:', data.data))
  .catch(error => console.error('Error:', error.message));
```

### Python

```python
import requests
import json
from typing import Dict, List, Optional

class BrokerSyncAPI:
    def __init__(self, api_key: str, base_url: str = "https://api.brokersync.com/api/v1"):
        self.api_key = api_key
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'X-API-Key': api_key,
            'Content-Type': 'application/json'
        })

    def _make_request(self, method: str, endpoint: str, **kwargs) -> Dict:
        """Make API request with error handling."""
        url = f"{self.base_url}{endpoint}"
        
        try:
            response = self.session.request(method, url, **kwargs)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as e:
            error_data = response.json() if response.content else {}
            error_message = error_data.get('error', {}).get('message', str(e))
            raise Exception(f"API Error: {error_message}")
        except requests.exceptions.RequestException as e:
            raise Exception(f"Request Error: {str(e)}")

    def get_applications(self, **params) -> Dict:
        """List applications with optional filtering."""
        return self._make_request('GET', '/applications', params=params)

    def get_application(self, application_id: int) -> Dict:
        """Get specific application details."""
        return self._make_request('GET', f'/applications/{application_id}')

    def create_application(self, application_data: Dict) -> Dict:
        """Create new application."""
        data = {'application': application_data}
        return self._make_request('POST', '/applications', json=data)

    def submit_application(self, application_id: int) -> Dict:
        """Submit application for review."""
        return self._make_request('POST', f'/applications/{application_id}/submit')

    def create_quote(self, quote_data: Dict) -> Dict:
        """Create new quote."""
        data = {'quote': quote_data}
        return self._make_request('POST', '/quotes', json=data)

    def upload_document(self, application_id: int, file_path: str, document_type: str) -> Dict:
        """Upload document for application."""
        with open(file_path, 'rb') as file:
            files = {'document[file]': file}
            data = {
                'document[type]': document_type,
                'document[description]': f"{document_type} document"
            }
            # Remove Content-Type header for multipart upload
            headers = {key: value for key, value in self.session.headers.items() 
                      if key != 'Content-Type'}
            
            response = requests.post(
                f"{self.base_url}/applications/{application_id}/documents",
                headers=headers,
                files=files,
                data=data
            )
            response.raise_for_status()
            return response.json()

# Usage Example
api = BrokerSyncAPI('your-api-key')

# List submitted applications
applications = api.get_applications(status='submitted', per_page=20)
print(f"Found {len(applications['data']['applications'])} applications")

# Create new motor insurance application
new_application = {
    'insurance_type': 'motor',
    'applicant': {
        'name': 'Jane Smith',
        'email': 'jane@example.com',
        'phone': '+1987654321',
        'date_of_birth': '1990-03-20'
    },
    'vehicle': {
        'make': 'Honda',
        'model': 'Civic',
        'year': 2021,
        'vin': '2HGFC2F59MH123456',
        'usage': 'personal'
    },
    'coverage': {
        'liability': {'bodily_injury': 250000, 'property_damage': 100000},
        'comprehensive': 30000,
        'collision': 30000,
        'deductible': 500
    }
}

try:
    # Create application
    result = api.create_application(new_application)
    app_id = result['data']['application']['id']
    print(f"Created application {app_id}")
    
    # Upload driver's license
    api.upload_document(app_id, '/path/to/license.pdf', 'drivers_license')
    print("Document uploaded successfully")
    
    # Submit application
    api.submit_application(app_id)
    print("Application submitted for review")
    
except Exception as e:
    print(f"Error: {e}")
```

### PHP

```php
<?php

class BrokerSyncAPI {
    private $apiKey;
    private $baseUrl;
    private $httpClient;

    public function __construct($apiKey, $baseUrl = 'https://api.brokersync.com/api/v1') {
        $this->apiKey = $apiKey;
        $this->baseUrl = $baseUrl;
        $this->httpClient = new \GuzzleHttp\Client([
            'base_uri' => $this->baseUrl,
            'headers' => [
                'X-API-Key' => $this->apiKey,
                'Content-Type' => 'application/json'
            ]
        ]);
    }

    public function getApplications($options = []) {
        try {
            $response = $this->httpClient->get('/applications', [
                'query' => $options
            ]);
            return json_decode($response->getBody()->getContents(), true);
        } catch (\Exception $e) {
            throw new \Exception("API Error: " . $e->getMessage());
        }
    }

    public function createApplication($applicationData) {
        try {
            $response = $this->httpClient->post('/applications', [
                'json' => ['application' => $applicationData]
            ]);
            return json_decode($response->getBody()->getContents(), true);
        } catch (\Exception $e) {
            throw new \Exception("API Error: " . $e->getMessage());
        }
    }

    public function createQuote($quoteData) {
        try {
            $response = $this->httpClient->post('/quotes', [
                'json' => ['quote' => $quoteData]
            ]);
            return json_decode($response->getBody()->getContents(), true);
        } catch (\Exception $e) {
            throw new \Exception("API Error: " . $e->getMessage());
        }
    }
}

// Usage Example
$api = new BrokerSyncAPI('your-api-key');

try {
    // Get applications
    $applications = $api->getApplications(['status' => 'submitted']);
    echo "Found " . count($applications['data']['applications']) . " applications\n";

    // Create quote for application
    $quote = [
        'application_id' => 12345,
        'premium' => 1500.00,
        'coverage_details' => [
            'liability' => [
                'bodily_injury' => 250000,
                'property_damage' => 100000
            ],
            'comprehensive' => 30000,
            'collision' => 30000,
            'deductible' => 500
        ],
        'terms' => [
            'policy_period' => 12,
            'effective_date' => '2024-02-01',
            'expiration_date' => '2025-02-01'
        ]
    ];

    $result = $api->createQuote($quote);
    echo "Quote created with ID: " . $result['data']['quote']['id'] . "\n";

} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>
```

---

## SDKs and Libraries

### Official SDKs

| Language | Repository | Documentation |
|----------|------------|---------------|
| JavaScript/Node.js | [brokersync-js](https://github.com/brokersync/brokersync-js) | [JS Docs](https://docs.brokersync.com/js) |
| Python | [brokersync-python](https://github.com/brokersync/brokersync-python) | [Python Docs](https://docs.brokersync.com/python) |
| PHP | [brokersync-php](https://github.com/brokersync/brokersync-php) | [PHP Docs](https://docs.brokersync.com/php) |
| Ruby | [brokersync-ruby](https://github.com/brokersync/brokersync-ruby) | [Ruby Docs](https://docs.brokersync.com/ruby) |

### Installation

**Node.js:**
```bash
npm install @brokersync/api-client
```

**Python:**
```bash
pip install brokersync-api
```

**PHP:**
```bash
composer require brokersync/api-client
```

**Ruby:**
```bash
gem install brokersync-api
```

---

## Webhooks

### Webhook Events

BrokerSync can send webhooks to your application when certain events occur:

| Event | Description |
|-------|-------------|
| `application.submitted` | Application submitted for review |
| `application.approved` | Application approved |
| `application.rejected` | Application rejected |
| `quote.created` | New quote generated |
| `quote.accepted` | Quote accepted by applicant |
| `quote.expired` | Quote expired |
| `document.uploaded` | Document uploaded |
| `document.verified` | Document verified |

### Webhook Payload Example

```json
{
  "event": "application.submitted",
  "timestamp": "2024-01-10T15:30:00Z",
  "data": {
    "application": {
      "id": 12345,
      "application_number": "APP-2024-001234",
      "status": "submitted",
      "insurance_type": "motor",
      "applicant": {
        "name": "John Doe",
        "email": "john@example.com"
      }
    }
  },
  "webhook": {
    "id": "webhook_789",
    "attempt": 1,
    "max_attempts": 3
  }
}
```

### Webhook Security

Webhooks are signed using HMAC-SHA256. Verify the signature using the `X-BrokerSync-Signature` header:

```javascript
const crypto = require('crypto');

function verifyWebhookSignature(payload, signature, secret) {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  
  return `sha256=${expectedSignature}` === signature;
}
```

---

## Testing

### Sandbox Environment

Use the sandbox environment for testing:
```
Sandbox URL: https://sandbox-api.brokersync.com/api/v1
```

### Test Data

The sandbox includes test data for various scenarios:

**Test Applications:**
- `APP-TEST-001`: Approved motor insurance application
- `APP-TEST-002`: Rejected fire insurance application
- `APP-TEST-003`: Pending liability insurance application

**Test API Keys:**
- Read-only: `test_readonly_key_123`
- Full access: `test_fullaccess_key_456`

---

## Changelog

### Version 1.3.0 (2024-01-15)
- Added feature flags API endpoints
- Enhanced analytics with trend data
- Improved error messages and debugging info
- Added webhook signature verification

### Version 1.2.0 (2024-01-01)
- Added document upload API
- Enhanced quote creation with terms and conditions
- Added bulk operations for applications
- Improved rate limiting with tier-based quotas

### Version 1.1.0 (2023-12-15)
- Added analytics endpoints
- Enhanced application filtering options
- Added webhook support
- Improved authentication with JWT refresh tokens

### Version 1.0.0 (2023-12-01)
- Initial API release
- Core application and quote management
- JWT and API key authentication
- Basic rate limiting

---

## Support

### Getting Help

- **Documentation:** [https://docs.brokersync.com](https://docs.brokersync.com)
- **API Status:** [https://status.brokersync.com](https://status.brokersync.com)
- **Support Email:** api-support@brokersync.com
- **Developer Forum:** [https://community.brokersync.com](https://community.brokersync.com)

### Response Times

| Support Tier | Response Time |
|--------------|---------------|
| Free | 72 hours |
| Professional | 24 hours |
| Enterprise | 4 hours |
| Critical Issues | 1 hour |

---

*Last updated: January 15, 2024*