# BrokerSync API Documentation

## Overview

The BrokerSync API provides a comprehensive REST interface for managing insurance applications, quotes, webhooks, and analytics. The API is built using Rails-native controllers and follows RESTful principles.

## Base URL

```
https://your-domain.com/api/v1
```

## Authentication

The API supports two authentication methods:

### 1. JWT Token Authentication
Include the JWT token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

### 2. API Key Authentication
Include the API key in the Authorization header:
```
Authorization: ApiKey <api_key>
```

## Rate Limiting

- **Standard tier**: 1000 requests per hour
- **Premium tier**: 5000 requests per hour
- **Enterprise tier**: 10000 requests per hour

Rate limit headers are included in all responses:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1609459200
```

## Common Response Format

### Success Response
```json
{
  "success": true,
  "data": {
    // Response data
  },
  "meta": {
    "timestamp": "2024-01-01T12:00:00Z",
    "api_version": "v1"
  }
}
```

### Error Response
```json
{
  "success": false,
  "error": {
    "message": "Error description",
    "code": "ERROR_CODE",
    "details": {
      // Additional error details
    }
  },
  "meta": {
    "timestamp": "2024-01-01T12:00:00Z",
    "api_version": "v1"
  }
}
```

### Pagination
Paginated responses include pagination metadata:
```json
{
  "success": true,
  "data": [...],
  "pagination": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 4,
    "total_count": 100,
    "next_page": 2,
    "prev_page": null
  }
}
```

## Applications API

### List Applications
```http
GET /api/v1/applications
```

**Query Parameters:**
- `status` - Filter by application status (draft, submitted, approved, rejected)
- `application_type` - Filter by type (motor, home, life, etc.)
- `client_id` - Filter by client ID
- `created_after` - Filter applications created after date (ISO 8601)
- `created_before` - Filter applications created before date (ISO 8601)
- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 25, max: 100)

**Example Response:**
```json
{
  "success": true,
  "data": {
    "applications": [
      {
        "id": 123,
        "reference_number": "APP001234",
        "status": "submitted",
        "application_type": "motor",
        "application_date": "2024-01-01",
        "client": {
          "id": 456,
          "full_name": "John Doe",
          "email": "john@example.com"
        },
        "coverage_amount": 50000.00,
        "created_at": "2024-01-01T10:00:00Z",
        "updated_at": "2024-01-01T10:30:00Z"
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 25,
      "total_pages": 1,
      "total_count": 5
    }
  }
}
```

### Get Application
```http
GET /api/v1/applications/{id}
```

### Create Application
```http
POST /api/v1/applications
```

**Request Body:**
```json
{
  "application": {
    "client_id": 456,
    "application_type": "motor",
    "coverage_amount": 50000.00,
    "application_data": {
      "vehicle_make": "Toyota",
      "vehicle_model": "Camry",
      "vehicle_year": 2020
    }
  }
}
```

### Update Application
```http
PUT /api/v1/applications/{id}
```

### Submit Application
```http
POST /api/v1/applications/{id}/submit
```

### Get Application Documents
```http
GET /api/v1/applications/{id}/documents
```

### Get Application Quotes
```http
GET /api/v1/applications/{id}/quotes
```

## Quotes API

### List Quotes
```http
GET /api/v1/quotes
```

**Query Parameters:**
- `status` - Filter by quote status (draft, pending, accepted, expired)
- `application_id` - Filter by application ID
- `insurance_company_id` - Filter by insurance company ID
- `created_after` - Filter quotes created after date
- `created_before` - Filter quotes created before date
- `page` - Page number
- `per_page` - Items per page

### Get Quote
```http
GET /api/v1/quotes/{id}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "quote": {
      "id": 789,
      "quote_number": "Q000789",
      "status": "pending",
      "total_premium": 1200.00,
      "coverage_amount": 50000.00,
      "quote_date": "2024-01-01",
      "valid_until": "2024-01-31",
      "insurance_company": {
        "id": 123,
        "name": "ACME Insurance",
        "code": "ACME"
      },
      "financial_details": {
        "base_premium": 1000.00,
        "taxes": 120.00,
        "fees": 80.00,
        "discounts": 0.00,
        "total_premium": 1200.00,
        "currency": "USD"
      },
      "coverage_details": {
        "coverage_type": "comprehensive",
        "coverage_amount": 50000.00,
        "deductible": 500.00,
        "policy_term": "12 months"
      },
      "validity_info": {
        "valid_until": "2024-01-31",
        "days_remaining": 30,
        "is_expired": false
      }
    }
  }
}
```

### Create Quote
```http
POST /api/v1/quotes
```

**Request Body:**
```json
{
  "quote": {
    "application_id": 123,
    "insurance_company_id": 456,
    "total_premium": 1200.00,
    "coverage_amount": 50000.00,
    "coverage_type": "comprehensive",
    "deductible": 500.00,
    "valid_until": "2024-01-31"
  }
}
```

### Update Quote
```http
PUT /api/v1/quotes/{id}
```

### Accept Quote
```http
POST /api/v1/quotes/{id}/accept
```

### Generate Quote PDF
```http
POST /api/v1/quotes/{id}/generate_pdf
```

## Feature Flags API

The Feature Flags API allows you to manage feature flags for your organization, enabling controlled rollouts and A/B testing.

### List Feature Flags
```http
GET /api/v1/feature_flags
```

**Query Parameters:**
- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 50, max: 100)
- `status` - Filter by status (enabled, disabled)
- `search` - Search by name or key

**Example Response:**
```json
{
  "success": true,
  "data": {
    "feature_flags": [
      {
        "id": 123,
        "key": "new_quote_engine",
        "name": "New Quote Engine",
        "description": "Enable the new enhanced quote calculation engine",
        "enabled": true,
        "percentage": 50,
        "user_groups": ["beta_users", "premium_clients"],
        "conditions": {
          "role": "agent",
          "created_after": "2024-01-01"
        },
        "metadata": {
          "owner": "engineering",
          "experiment_id": "exp_001"
        },
        "created_at": "2024-01-01T10:00:00Z",
        "updated_at": "2024-01-01T15:30:00Z",
        "created_by": {
          "id": 456,
          "name": "John Doe",
          "email": "john@company.com"
        }
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 50,
      "total_pages": 1,
      "total_count": 12
    },
    "stats": {
      "enabled": 8,
      "disabled": 4,
      "percentage_rollouts": 3,
      "conditional_flags": 2
    }
  }
}
```

### Get Feature Flag
```http
GET /api/v1/feature_flags/{id}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "feature_flag": {
      "id": 123,
      "key": "new_quote_engine",
      "name": "New Quote Engine",
      "description": "Enable the new enhanced quote calculation engine",
      "enabled": true,
      "percentage": 50,
      "user_groups": ["beta_users"],
      "conditions": {
        "role": "agent"
      },
      "metadata": {
        "owner": "engineering"
      },
      "created_at": "2024-01-01T10:00:00Z",
      "updated_at": "2024-01-01T15:30:00Z"
    },
    "usage_stats": {
      "total_evaluations": 1500,
      "enabled_evaluations": 750,
      "unique_users": 45,
      "last_evaluation": "2024-01-01T15:25:00Z"
    }
  }
}
```

### Create Feature Flag
```http
POST /api/v1/feature_flags
```

**Request Body:**
```json
{
  "feature_flag": {
    "key": "enhanced_dashboard",
    "name": "Enhanced Dashboard",
    "description": "New dashboard with advanced analytics",
    "enabled": false,
    "percentage": 25,
    "user_groups": ["beta_users"],
    "conditions": {
      "role": "admin",
      "email_domain": "company.com"
    },
    "metadata": {
      "owner": "product",
      "experiment_duration": "30d"
    }
  }
}
```

### Update Feature Flag
```http
PUT /api/v1/feature_flags/{id}
```

### Delete Feature Flag
```http
DELETE /api/v1/feature_flags/{id}
```

### Toggle Feature Flag
```http
POST /api/v1/feature_flags/{id}/toggle
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "feature_flag": {
      "id": 123,
      "enabled": true,
      "updated_at": "2024-01-01T16:00:00Z"
    },
    "message": "Feature flag enabled successfully"
  }
}
```

### Check Feature Flag Status
```http
GET /api/v1/feature_flags/{key}/enabled
```

**Query Parameters:**
- `user_id` - User ID to check flag for (optional)
- `context` - Additional context as JSON (optional)

**Example Response:**
```json
{
  "success": true,
  "data": {
    "key": "new_quote_engine",
    "enabled": true,
    "reason": "percentage_rollout",
    "percentage": 50,
    "evaluated_at": "2024-01-01T16:00:00Z"
  }
}
```

## Webhooks API

### List Webhooks
```http
GET /api/v1/webhooks
```

**Query Parameters:**
- `event_type` - Filter by event type
- `status` - Filter by webhook status (active, inactive, failed)
- `page` - Page number
- `per_page` - Items per page

### Get Webhook
```http
GET /api/v1/webhooks/{id}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "webhook": {
      "id": 123,
      "url": "https://example.com/webhook",
      "event_types": [
        "application.created",
        "quote.accepted"
      ],
      "status": "active",
      "description": "Main webhook for application events",
      "retry_count": 3,
      "timeout_seconds": 30,
      "created_at": "2024-01-01T10:00:00Z",
      "last_delivery_at": "2024-01-01T12:00:00Z",
      "delivery_stats": {
        "total_deliveries": 150,
        "successful_deliveries": 148,
        "failed_deliveries": 2,
        "success_rate": 98.67
      },
      "secret": "abc123...",
      "created_by": {
        "id": 456,
        "name": "John Doe",
        "email": "john@example.com"
      }
    }
  }
}
```

### Create Webhook
```http
POST /api/v1/webhooks
```

**Request Body:**
```json
{
  "webhook": {
    "url": "https://example.com/webhook",
    "event_types": [
      "application.created",
      "quote.accepted"
    ],
    "description": "Main webhook for application events",
    "secret": "optional_secret_key",
    "retry_count": 3,
    "timeout_seconds": 30
  }
}
```

### Update Webhook
```http
PUT /api/v1/webhooks/{id}
```

### Delete Webhook
```http
DELETE /api/v1/webhooks/{id}
```

### Test Webhook
```http
POST /api/v1/webhooks/{id}/test
```

### Get Webhook Deliveries
```http
GET /api/v1/webhooks/{id}/deliveries
```

**Query Parameters:**
- `status` - Filter by delivery status (success, failed, pending)
- `event_type` - Filter by event type
- `page` - Page number
- `per_page` - Items per page

### Available Event Types
- `application.created`
- `application.updated`
- `application.submitted`
- `application.approved`
- `application.rejected`
- `quote.created`
- `quote.updated`
- `quote.accepted`
- `quote.expired`
- `document.uploaded`
- `document.processed`
- `policy.created`
- `policy.renewed`
- `payment.received`
- `payment.failed`

## Analytics API

### Usage Analytics
```http
GET /api/v1/analytics/usage
```

**Query Parameters:**
- `period` - Time period (1h, 24h, 7d, 30d, 90d)

**Example Response:**
```json
{
  "success": true,
  "data": {
    "time_period": "7d",
    "usage_metrics": {
      "total_requests": 15000,
      "unique_endpoints": 25,
      "unique_users": 50,
      "successful_requests": 14500,
      "failed_requests": 500,
      "average_response_time": 245.5,
      "requests_per_day": {
        "2024-01-01": 2000,
        "2024-01-02": 2200
      },
      "peak_hour": "14:00"
    },
    "trends": {
      "direction": "increasing",
      "percentage_change": 15.5,
      "daily_average": 2142.86
    },
    "generated_at": "2024-01-01T12:00:00Z"
  }
}
```

### Dashboard Analytics
```http
GET /api/v1/analytics/dashboard
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "dashboard": {
      "overview": {
        "total_applications": 1250,
        "pending_quotes": 45,
        "active_policies": 890,
        "total_premium": 2450000.00,
        "growth_rate": 12.5
      },
      "activity_timeline": [
        {
          "date": "2024-01-01",
          "applications_created": 25,
          "quotes_generated": 20,
          "policies_issued": 15
        }
      ],
      "endpoint_performance": {
        "fastest_endpoint": "/api/v1/applications",
        "slowest_endpoint": "/api/v1/analytics/dashboard",
        "average_response_time": 235.5
      },
      "error_rates": {
        "total_errors": 125,
        "error_rate_percentage": 2.1,
        "most_common_error": "401 Unauthorized"
      },
      "user_activity": {
        "active_users_today": 45,
        "peak_concurrent_users": 23,
        "average_session_duration": 1245
      }
    },
    "refresh_interval": 300,
    "generated_at": "2024-01-01T12:00:00Z"
  }
}
```

### Performance Analytics
```http
GET /api/v1/analytics/performance
```

**Query Parameters:**
- `time_range` - Time range for analysis (1h, 6h, 24h, 7d, 30d)

**Example Response:**
```json
{
  "success": true,
  "data": {
    "time_range": "24h",
    "performance": {
      "response_times": {
        "average": 245.5,
        "p50": 180.0,
        "p95": 650.0,
        "p99": 1200.0,
        "max": 2500.0
      },
      "throughput": {
        "requests_per_second": 12.5,
        "peak_rps": 45.2,
        "total_requests": 10800
      },
      "error_analysis": {
        "total_errors": 54,
        "error_rate": 0.5,
        "errors_by_type": {
          "4xx": 42,
          "5xx": 12
        },
        "common_errors": [
          {
            "status_code": 401,
            "count": 25,
            "endpoint": "/api/v1/applications"
          }
        ]
      },
      "slow_queries": [
        {
          "endpoint": "/api/v1/analytics/dashboard",
          "average_response_time": 1250.0,
          "slowest_response": 3200.0,
          "frequency": 145
        }
      ],
      "resource_usage": {
        "memory_usage": 65.5,
        "cpu_usage": 23.8,
        "database_connections": 12
      }
    },
    "recommendations": [
      "Consider adding caching for /api/v1/analytics/dashboard",
      "Optimize database queries for application endpoints",
      "Review authentication middleware performance"
    ],
    "generated_at": "2024-01-01T12:00:00Z"
  }
}
```

### Export Analytics
```http
GET /api/v1/analytics/export
```

**Query Parameters:**
- `format` - Export format (json, csv, xlsx)
- `period` - Time period (7d, 30d, 90d)
- `metrics` - Specific metrics to include (comma-separated)

**Example Request:**
```http
GET /api/v1/analytics/export?format=csv&period=30d&metrics=usage,performance,errors
```

**Example Response (JSON format):**
```json
{
  "success": true,
  "data": {
    "export_metadata": {
      "format": "json",
      "period": "30d",
      "total_records": 2500,
      "generated_at": "2024-01-01T12:00:00Z"
    },
    "usage_data": [
      {
        "date": "2024-01-01",
        "total_requests": 1500,
        "unique_users": 45,
        "response_time_avg": 235.5
      }
    ],
    "performance_data": [
      {
        "endpoint": "/api/v1/applications",
        "avg_response_time": 180.0,
        "total_requests": 5500,
        "error_rate": 0.2
      }
    ]
  }
}
```

**CSV/XLSX Response:**
Returns a downloadable file with the requested analytics data.

## Security & Compliance API

### Security Alerts

#### List Security Alerts
```http
GET /api/v1/security/alerts
```

**Query Parameters:**
- `severity` - Filter by severity (low, medium, high, critical)
- `status` - Filter by status (active, investigating, resolved, dismissed)
- `alert_type` - Filter by type (multiple_failed_logins, suspicious_ip_activity, etc.)
- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 25, max: 100)

**Example Response:**
```json
{
  "success": true,
  "data": {
    "alerts": [
      {
        "id": 789,
        "alert_type": "multiple_failed_logins",
        "severity": "high",
        "status": "active",
        "message": "Multiple failed login attempts detected from IP 192.168.1.100",
        "triggered_at": "2024-01-01T14:30:00Z",
        "data": {
          "ip_address": "192.168.1.100",
          "attempt_count": 15,
          "user_email": "admin@company.com",
          "time_window": "5m"
        },
        "affected_user": {
          "id": 123,
          "email": "admin@company.com",
          "name": "John Admin"
        },
        "resolved_at": null,
        "resolved_by": null
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 25,
      "total_pages": 3,
      "total_count": 67
    },
    "summary": {
      "total_active": 15,
      "critical_unresolved": 3,
      "resolved_today": 8
    }
  }
}
```

#### Get Security Alert
```http
GET /api/v1/security/alerts/{id}
```

#### Resolve Security Alert
```http
POST /api/v1/security/alerts/{id}/resolve
```

**Request Body:**
```json
{
  "resolution_notes": "False positive - verified legitimate user activity"
}
```

#### Dismiss Security Alert
```http
POST /api/v1/security/alerts/{id}/dismiss
```

**Request Body:**
```json
{
  "reason": "Known behavior pattern"
}
```

### Audit Logs

#### List Audit Logs
```http
GET /api/v1/audit/logs
```

**Query Parameters:**
- `action` - Filter by action type (create, update, delete, etc.)
- `resource_type` - Filter by resource (Application, Quote, User, etc.)
- `user_id` - Filter by user ID
- `date_from` - Start date (ISO 8601)
- `date_to` - End date (ISO 8601)
- `page` - Page number
- `per_page` - Items per page

**Example Response:**
```json
{
  "success": true,
  "data": {
    "audit_logs": [
      {
        "id": 1001,
        "action": "create",
        "resource_type": "Application",
        "resource_id": 456,
        "user_id": 123,
        "user_email": "agent@company.com",
        "changes": {
          "status": ["draft", "submitted"],
          "coverage_amount": [null, 50000.00]
        },
        "ip_address": "192.168.1.50",
        "user_agent": "Mozilla/5.0...",
        "created_at": "2024-01-01T15:00:00Z",
        "metadata": {
          "source": "web_app",
          "session_id": "sess_abc123"
        }
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 50,
      "total_pages": 10,
      "total_count": 500
    }
  }
}
```

### Compliance Reports

#### Generate Compliance Report
```http
POST /api/v1/compliance/reports
```

**Request Body:**
```json
{
  "report_type": "gdpr_data_processing",
  "date_range": {
    "start_date": "2024-01-01",
    "end_date": "2024-01-31"
  },
  "include_sections": ["data_access", "user_activity", "data_changes"],
  "format": "pdf"
}
```

#### Download Compliance Report
```http
GET /api/v1/compliance/reports/{id}/download
```

### Export Analytics
```http
GET /api/v1/analytics/export
```

**Query Parameters:**
- `format` - Export format (json, csv, xlsx)
- `period` - Time period (7d, 30d, 90d)

### Top Endpoints
```http
GET /api/v1/analytics/top_endpoints
```

**Query Parameters:**
- `limit` - Number of top endpoints to return (default: 10)
- `period` - Time period (7d, 30d, 90d)

### Trends
```http
GET /api/v1/analytics/trends
```

**Query Parameters:**
- `metric` - Metric type (requests, errors, response_time, users)
- `period` - Time period (7d, 30d, 90d)
- `granularity` - Data granularity (hourly, daily, weekly)

## Error Codes

### Authentication Errors
- `INVALID_API_KEY` - API key is invalid or expired
- `INVALID_JWT_TOKEN` - JWT token is invalid or expired
- `INSUFFICIENT_PERMISSIONS` - API key lacks required permissions

### Rate Limiting Errors
- `RATE_LIMIT_EXCEEDED` - Too many requests within time window

### Validation Errors
- `INVALID_PARAMETERS` - Request parameters are invalid
- `MISSING_REQUIRED_FIELD` - Required field is missing
- `INVALID_FORMAT` - Field format is invalid

### Resource Errors
- `RESOURCE_NOT_FOUND` - Requested resource does not exist
- `RESOURCE_ALREADY_EXISTS` - Resource already exists
- `RESOURCE_CONFLICT` - Operation conflicts with current state

### Server Errors
- `INTERNAL_SERVER_ERROR` - Unexpected server error
- `SERVICE_UNAVAILABLE` - Service temporarily unavailable

## Webhook Payload Format

When events occur, webhooks receive POST requests with the following format:

```json
{
  "event_type": "application.created",
  "data": {
    "application": {
      // Application data
    }
  },
  "metadata": {
    "api_version": "v1",
    "organization_id": 123,
    "event_id": "evt_123",
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

### Webhook Signature Verification

If a webhook secret is configured, requests include a signature header:
```
X-BrokerSync-Signature: sha256=<signature>
```

To verify the signature:
```ruby
signature = OpenSSL::HMAC.hexdigest('sha256', webhook_secret, request_body)
expected_signature = "sha256=#{signature}"
```

## SDK Examples

### cURL Examples

**Get Applications:**
```bash
curl -X GET "https://api.brokersync.com/api/v1/applications" \
  -H "Authorization: ApiKey your_api_key" \
  -H "Content-Type: application/json"
```

**Create Quote:**
```bash
curl -X POST "https://api.brokersync.com/api/v1/quotes" \
  -H "Authorization: ApiKey your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "quote": {
      "application_id": 123,
      "insurance_company_id": 456,
      "total_premium": 1200.00,
      "coverage_amount": 50000.00
    }
  }'
```

### JavaScript/Node.js Examples

```javascript
const axios = require('axios');

const api = axios.create({
  baseURL: 'https://api.brokersync.com/api/v1',
  headers: {
    'Authorization': 'ApiKey your_api_key',
    'Content-Type': 'application/json'
  }
});

// Get applications
const applications = await api.get('/applications');

// Create webhook
const webhook = await api.post('/webhooks', {
  webhook: {
    url: 'https://your-app.com/webhook',
    event_types: ['application.created', 'quote.accepted'],
    description: 'Main webhook'
  }
});
```

### Python Examples

```python
import requests

base_url = 'https://api.brokersync.com/api/v1'
headers = {
    'Authorization': 'ApiKey your_api_key',
    'Content-Type': 'application/json'
}

# Get usage analytics
response = requests.get(
    f'{base_url}/analytics/usage',
    headers=headers,
    params={'period': '7d'}
)

analytics = response.json()
```

## Best Practices

### 1. Authentication
- Store API keys securely and never expose them in client-side code
- Rotate API keys regularly
- Use JWT tokens for user-specific operations

### 2. Rate Limiting
- Implement exponential backoff for rate limit errors
- Monitor your usage and upgrade tiers as needed
- Cache responses when appropriate

### 3. Error Handling
- Always check the `success` field in responses
- Implement proper error handling for all error codes
- Log errors for debugging purposes

### 4. Webhooks
- Always verify webhook signatures
- Implement idempotency using event IDs
- Return HTTP 200 status for successful webhook processing
- Use HTTPS endpoints only

### 5. Performance
- Use pagination for large datasets
- Implement client-side filtering when possible
- Use appropriate query parameters to limit response size

## Support

For API support, please contact:
- Email: api-support@brokersync.com
- Documentation: https://docs.brokersync.com
- Status Page: https://status.brokersync.com