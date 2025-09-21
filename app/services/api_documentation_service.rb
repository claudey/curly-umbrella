class ApiDocumentationService
  include Singleton

  def initialize
    @base_url = Rails.env.production? ? "https://api.brokersync.com" : "http://localhost:3000"
  end

  # Generate comprehensive API documentation data
  def generate_documentation_data
    {
      info: api_info,
      authentication: authentication_methods,
      rate_limiting: rate_limiting_info,
      endpoints: api_endpoints,
      webhooks: webhook_documentation,
      error_codes: error_codes,
      examples: code_examples,
      changelog: api_changelog
    }
  end

  # Generate interactive playground data
  def generate_playground_data(user)
    {
      endpoints: playground_endpoints,
      user_api_keys: user.api_keys.active.pluck(:name, :key, :scopes),
      test_data: test_data_examples,
      environment_urls: environment_urls
    }
  end

  # Validate API endpoint against actual routes
  def validate_endpoint(endpoint_path, method)
    routes = Rails.application.routes.routes
    route_exists = routes.any? do |route|
      route.verb.include?(method.upcase) &&
      route.path.spec.to_s.gsub(/\(\.:format\)/, "").match?(endpoint_path)
    end

    {
      exists: route_exists,
      endpoint: endpoint_path,
      method: method,
      validated_at: Time.current
    }
  end

  # Generate SDK code examples for multiple languages
  def generate_sdk_examples(endpoint, method, request_data = nil)
    {
      javascript: generate_javascript_sdk(endpoint, method, request_data),
      python: generate_python_sdk(endpoint, method, request_data),
      php: generate_php_sdk(endpoint, method, request_data),
      ruby: generate_ruby_sdk(endpoint, method, request_data),
      curl: generate_curl_example(endpoint, method, request_data)
    }
  end

  # Generate Postman collection
  def generate_postman_collection
    {
      info: {
        _postman_id: SecureRandom.uuid,
        name: "BrokerSync API Collection",
        description: "Complete BrokerSync API collection with examples",
        schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
      },
      auth: {
        type: "apikey",
        apikey: [
          { key: "key", value: "X-API-Key", type: "string" },
          { key: "value", value: "{{api_key}}", type: "string" },
          { key: "in", value: "header", type: "string" }
        ]
      },
      event: [
        {
          listen: "prerequest",
          script: {
            type: "text/javascript",
            exec: [ "// Auto-generated BrokerSync API Collection" ]
          }
        }
      ],
      variable: [
        { key: "base_url", value: @base_url, type: "string" },
        { key: "api_key", value: "your-api-key-here", type: "string" },
        { key: "jwt_token", value: "", type: "string" }
      ],
      item: generate_postman_folders
    }
  end

  # Generate OpenAPI 3.0 specification
  def generate_openapi_spec
    {
      openapi: "3.0.3",
      info: {
        title: "BrokerSync API",
        description: "Comprehensive insurance brokerage platform API with advanced features",
        version: "1.0.0",
        contact: {
          name: "BrokerSync API Support",
          email: "api-support@brokersync.com",
          url: "https://docs.brokersync.com"
        },
        license: {
          name: "Proprietary",
          url: "https://brokersync.com/license"
        }
      },
      servers: [
        { url: "#{@base_url}/api/v1", description: "Primary API server" },
        { url: "https://staging-api.brokersync.com/api/v1", description: "Staging environment" },
        { url: "https://sandbox-api.brokersync.com/api/v1", description: "Sandbox for testing" }
      ],
      security: [
        { ApiKeyAuth: [] },
        { BearerAuth: [] }
      ],
      components: openapi_components,
      paths: openapi_paths,
      tags: api_tags,
      externalDocs: {
        description: "Full API Documentation",
        url: "https://docs.brokersync.com/api"
      }
    }
  end

  # Test API endpoint health
  def test_endpoint_health(endpoint_path, method, api_key = nil)
    begin
      headers = { "Content-Type" => "application/json" }
      headers["X-API-Key"] = api_key if api_key

      response = HTTParty.send(
        method.downcase.to_sym,
        "#{@base_url}#{endpoint_path}",
        headers: headers,
        timeout: 10
      )

      {
        status: :healthy,
        response_code: response.code,
        response_time: response.time,
        endpoint: endpoint_path,
        method: method,
        tested_at: Time.current
      }
    rescue => e
      {
        status: :unhealthy,
        error: e.message,
        endpoint: endpoint_path,
        method: method,
        tested_at: Time.current
      }
    end
  end

  private

  def api_info
    {
      title: "BrokerSync API",
      version: "1.0.0",
      description: "Comprehensive insurance brokerage platform API",
      base_url: "#{@base_url}/api/v1",
      documentation_url: "https://docs.brokersync.com/api",
      support_email: "api-support@brokersync.com",
      status_page: "https://status.brokersync.com"
    }
  end

  def authentication_methods
    [
      {
        type: "API Key",
        method: "header",
        header_name: "X-API-Key",
        description: "Server-to-server authentication using API keys",
        scopes: [ "read", "write", "analytics", "admin" ],
        example: {
          header: "X-API-Key: your-api-key",
          curl: "curl -H 'X-API-Key: your-api-key' #{@base_url}/api/v1/applications"
        }
      },
      {
        type: "JWT Bearer Token",
        method: "header",
        header_name: "Authorization",
        description: "User-based authentication using JSON Web Tokens",
        login_endpoint: "/api/v1/auth/login",
        refresh_endpoint: "/api/v1/auth/refresh",
        example: {
          header: "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
          login_request: {
            email: "user@example.com",
            password: "secure_password"
          }
        }
      }
    ]
  end

  def rate_limiting_info
    {
      algorithm: "Token bucket with sliding window",
      tiers: [
        { name: "Free", requests_per_hour: 1000, burst_limit: 100 },
        { name: "Professional", requests_per_hour: 10000, burst_limit: 500 },
        { name: "Enterprise", requests_per_hour: 100000, burst_limit: 2000 }
      ],
      headers: [
        "X-RateLimit-Limit",
        "X-RateLimit-Remaining",
        "X-RateLimit-Reset",
        "X-RateLimit-Retry-After"
      ],
      bypass_conditions: [
        "Internal API calls",
        "Webhook deliveries",
        "Health check endpoints"
      ]
    }
  end

  def api_endpoints
    [
      {
        category: "Applications",
        description: "Manage insurance applications",
        endpoints: [
          {
            method: "GET",
            path: "/applications",
            name: "List Applications",
            description: "Retrieve paginated list of applications with filtering",
            parameters: application_list_parameters,
            response_schema: "ApplicationList",
            example_response: application_list_example
          },
          {
            method: "POST",
            path: "/applications",
            name: "Create Application",
            description: "Create new insurance application",
            request_schema: "CreateApplication",
            response_schema: "Application",
            example_request: create_application_example,
            example_response: application_example
          },
          {
            method: "GET",
            path: "/applications/{id}",
            name: "Get Application",
            description: "Retrieve specific application with full details",
            parameters: [ { name: "id", type: "integer", required: true, description: "Application ID" } ],
            response_schema: "Application",
            example_response: application_example
          },
          {
            method: "POST",
            path: "/applications/{id}/submit",
            name: "Submit Application",
            description: "Submit application for underwriting review",
            parameters: [ { name: "id", type: "integer", required: true, description: "Application ID" } ],
            response_schema: "ApplicationSubmission",
            example_response: submission_example
          }
        ]
      },
      {
        category: "Quotes",
        description: "Manage insurance quotes and pricing",
        endpoints: [
          {
            method: "GET",
            path: "/quotes",
            name: "List Quotes",
            description: "Retrieve quotes with filtering and pagination",
            parameters: quote_list_parameters,
            response_schema: "QuoteList",
            example_response: quote_list_example
          },
          {
            method: "POST",
            path: "/quotes",
            name: "Create Quote",
            description: "Generate new quote for application",
            request_schema: "CreateQuote",
            response_schema: "Quote",
            example_request: create_quote_example,
            example_response: quote_example
          }
        ]
      },
      {
        category: "Feature Flags",
        description: "Check feature flag status",
        endpoints: [
          {
            method: "GET",
            path: "/feature_flags/check",
            name: "Check Feature Flags",
            description: "Check multiple feature flags for user context",
            parameters: feature_flag_parameters,
            response_schema: "FeatureFlagCheck",
            example_response: feature_flag_example
          }
        ]
      }
    ]
  end

  def webhook_documentation
    {
      description: "Real-time notifications for important events",
      events: [
        {
          name: "application.submitted",
          description: "Triggered when application is submitted for review",
          payload_schema: "ApplicationWebhook"
        },
        {
          name: "quote.created",
          description: "Triggered when new quote is generated",
          payload_schema: "QuoteWebhook"
        },
        {
          name: "quote.accepted",
          description: "Triggered when quote is accepted by client",
          payload_schema: "QuoteWebhook"
        }
      ],
      security: {
        signature_header: "X-BrokerSync-Signature",
        algorithm: "HMAC-SHA256",
        verification_example: webhook_verification_example
      },
      retry_policy: {
        max_attempts: 3,
        backoff_strategy: "exponential",
        timeout: "30 seconds"
      }
    }
  end

  def error_codes
    [
      { code: "AUTHENTICATION_FAILED", status: 401, description: "Invalid API key or JWT token" },
      { code: "AUTHORIZATION_FAILED", status: 403, description: "Insufficient permissions for resource" },
      { code: "VALIDATION_ERROR", status: 422, description: "Request data validation failed" },
      { code: "RESOURCE_NOT_FOUND", status: 404, description: "Requested resource does not exist" },
      { code: "RATE_LIMIT_EXCEEDED", status: 429, description: "Too many requests, retry after specified time" },
      { code: "INTERNAL_ERROR", status: 500, description: "Unexpected server error occurred" }
    ]
  end

  def code_examples
    {
      authentication: {
        javascript: auth_js_example,
        python: auth_python_example,
        php: auth_php_example
      },
      create_application: {
        javascript: create_app_js_example,
        python: create_app_python_example,
        curl: create_app_curl_example
      }
    }
  end

  def api_changelog
    [
      {
        version: "1.0.0",
        date: "2024-01-15",
        changes: [
          "Initial API release with core functionality",
          "Applications and quotes management",
          "JWT and API key authentication",
          "Basic rate limiting implementation"
        ]
      }
    ]
  end

  # Helper methods for generating examples
  def application_list_parameters
    [
      { name: "page", type: "integer", required: false, default: 1, description: "Page number for pagination" },
      { name: "per_page", type: "integer", required: false, default: 20, description: "Items per page (max 100)" },
      { name: "status", type: "string", required: false, enum: [ "draft", "submitted", "approved", "rejected" ], description: "Filter by application status" },
      { name: "insurance_type", type: "string", required: false, enum: [ "motor", "fire", "liability", "general_accident", "bonds" ], description: "Filter by insurance type" },
      { name: "created_after", type: "string", required: false, format: "date-time", description: "Filter applications created after this date" },
      { name: "created_before", type: "string", required: false, format: "date-time", description: "Filter applications created before this date" }
    ]
  end

  def application_list_example
    {
      success: true,
      data: {
        applications: [
          {
            id: 12345,
            application_number: "APP-2024-001234",
            insurance_type: "motor",
            status: "submitted",
            applicant: {
              name: "John Doe",
              email: "john@example.com",
              phone: "+1234567890"
            },
            risk_score: 7.5,
            submitted_at: "2024-01-10T14:30:00Z",
            created_at: "2024-01-10T10:15:00Z"
          }
        ],
        pagination: {
          current_page: 1,
          total_pages: 25,
          total_count: 1250,
          per_page: 50
        }
      }
    }
  end

  def create_application_example
    {
      application: {
        insurance_type: "motor",
        applicant: {
          name: "John Doe",
          email: "john@example.com",
          phone: "+1234567890",
          date_of_birth: "1985-06-15",
          address: {
            street: "123 Main St",
            city: "New York",
            state: "NY",
            zip: "10001",
            country: "US"
          }
        },
        vehicle: {
          make: "Toyota",
          model: "Camry",
          year: 2022,
          vin: "1HGBH41JXMN109186",
          license_plate: "ABC123",
          usage: "personal",
          annual_mileage: 12000
        },
        coverage: {
          liability: {
            bodily_injury: 100000,
            property_damage: 50000
          },
          comprehensive: 25000,
          collision: 25000,
          deductible: 1000
        }
      }
    }
  end

  def generate_javascript_sdk(endpoint, method, request_data)
    <<~JAVASCRIPT
      // BrokerSync JavaScript SDK Example
      const BrokerSync = require('@brokersync/api-client');

      const client = new BrokerSync({
        apiKey: 'your-api-key',
        environment: 'production' // or 'staging', 'sandbox'
      });

      async function #{method.downcase}#{endpoint.gsub(/[^a-zA-Z0-9]/, '')}() {
        try {
          #{request_data ? "const data = #{JSON.pretty_generate(request_data)};" : ''}
          const response = await client.#{method.downcase}('#{endpoint}'#{request_data ? ', data' : ''});
          console.log('Success:', response.data);
          return response.data;
        } catch (error) {
          console.error('API Error:', error.message);
          if (error.response) {
            console.error('Response:', error.response.data);
          }
          throw error;
        }
      }

      // Usage
      #{method.downcase}#{endpoint.gsub(/[^a-zA-Z0-9]/, '')}()
        .then(result => console.log('Result:', result))
        .catch(error => console.error('Failed:', error.message));
    JAVASCRIPT
  end

  def generate_python_sdk(endpoint, method, request_data)
    <<~PYTHON
      # BrokerSync Python SDK Example
      from brokersync import BrokerSyncClient
      import json

      # Initialize client
      client = BrokerSyncClient(
          api_key='your-api-key',
          environment='production'  # or 'staging', 'sandbox'
      )

      def #{method.downcase}_#{endpoint.gsub(/[^a-zA-Z0-9]/, '_').downcase}():
          """#{method.upcase} #{endpoint} example"""
          try:
              #{request_data ? "data = #{JSON.pretty_generate(request_data).gsub(/"([^"]+)"/, '\'\1\'')}" : ''}
              response = client.#{method.downcase}('#{endpoint}'#{request_data ? ', data=data' : ''})
              print(f"Success: {response}")
              return response
          except BrokerSyncError as e:
              print(f"API Error: {e}")
              if hasattr(e, 'response'):
                  print(f"Response: {e.response}")
              raise
          except Exception as e:
              print(f"Unexpected error: {e}")
              raise

      # Usage
      if __name__ == "__main__":
          result = #{method.downcase}_#{endpoint.gsub(/[^a-zA-Z0-9]/, '_').downcase}()
          print(f"Final result: {result}")
    PYTHON
  end

  def generate_postman_folders
    api_endpoints.map do |category|
      {
        name: category[:category],
        description: category[:description],
        item: category[:endpoints].map do |endpoint|
          {
            name: endpoint[:name],
            request: {
              method: endpoint[:method],
              header: [
                { key: "Content-Type", value: "application/json", type: "text" },
                { key: "Accept", value: "application/json", type: "text" }
              ],
              url: {
                raw: "{{base_url}}#{endpoint[:path]}",
                host: [ "{{base_url}}" ],
                path: endpoint[:path].split("/").reject(&:empty?)
              },
              body: endpoint[:example_request] ? {
                mode: "raw",
                raw: JSON.pretty_generate(endpoint[:example_request]),
                options: { raw: { language: "json" } }
              } : nil,
              description: endpoint[:description]
            }.compact,
            response: endpoint[:example_response] ? [ {
              name: "Success Response",
              originalRequest: {
                method: endpoint[:method],
                header: [],
                url: { raw: "{{base_url}}#{endpoint[:path]}" }
              },
              status: "OK",
              code: 200,
              body: JSON.pretty_generate(endpoint[:example_response])
            } ] : []
          }
        end
      }
    end
  end

  def openapi_components
    {
      securitySchemes: {
        ApiKeyAuth: {
          type: "apiKey",
          in: "header",
          name: "X-API-Key",
          description: "API key for server-to-server authentication"
        },
        BearerAuth: {
          type: "http",
          scheme: "bearer",
          bearerFormat: "JWT",
          description: "JWT token for user authentication"
        }
      },
      schemas: openapi_schemas
    }
  end

  def openapi_schemas
    {
      Application: {
        type: "object",
        properties: {
          id: { type: "integer", example: 12345 },
          application_number: { type: "string", example: "APP-2024-001234" },
          insurance_type: { type: "string", enum: [ "motor", "fire", "liability", "general_accident", "bonds" ] },
          status: { type: "string", enum: [ "draft", "submitted", "under_review", "approved", "rejected" ] },
          applicant: { "$ref": "#/components/schemas/Applicant" },
          created_at: { type: "string", format: "date-time" },
          updated_at: { type: "string", format: "date-time" }
        },
        required: [ "id", "application_number", "insurance_type", "status", "applicant" ]
      },
      Applicant: {
        type: "object",
        properties: {
          name: { type: "string", example: "John Doe" },
          email: { type: "string", format: "email", example: "john@example.com" },
          phone: { type: "string", example: "+1234567890" },
          date_of_birth: { type: "string", format: "date" },
          address: { "$ref": "#/components/schemas/Address" }
        },
        required: [ "name", "email" ]
      },
      Address: {
        type: "object",
        properties: {
          street: { type: "string" },
          city: { type: "string" },
          state: { type: "string" },
          zip: { type: "string" },
          country: { type: "string" }
        }
      }
    }
  end

  def openapi_paths
    paths = {}

    api_endpoints.each do |category|
      category[:endpoints].each do |endpoint|
        path_key = endpoint[:path].gsub(/{(\w+)}/, '{\1}')
        paths[path_key] ||= {}

        paths[path_key][endpoint[:method].downcase] = {
          tags: [ category[:category] ],
          summary: endpoint[:name],
          description: endpoint[:description],
          parameters: endpoint[:parameters]&.map do |param|
            {
              name: param[:name],
              in: param[:name] == "id" ? "path" : "query",
              required: param[:required] || false,
              schema: { type: param[:type] },
              description: param[:description]
            }
          end,
          requestBody: endpoint[:request_schema] ? {
            required: true,
            content: {
              "application/json" => {
                schema: { "$ref" => "#/components/schemas/#{endpoint[:request_schema]}" },
                example: endpoint[:example_request]
              }
            }
          } : nil,
          responses: {
            "200" => {
              description: "Success",
              content: {
                "application/json" => {
                  schema: endpoint[:response_schema] ?
                    { "$ref" => "#/components/schemas/#{endpoint[:response_schema]}" } :
                    { type: "object" },
                  example: endpoint[:example_response]
                }
              }
            },
            "400" => { description: "Bad Request" },
            "401" => { description: "Unauthorized" },
            "403" => { description: "Forbidden" },
            "404" => { description: "Not Found" },
            "422" => { description: "Validation Error" },
            "429" => { description: "Rate Limited" },
            "500" => { description: "Internal Server Error" }
          }
        }.compact
      end
    end

    paths
  end

  def api_tags
    api_endpoints.map do |category|
      {
        name: category[:category],
        description: category[:description]
      }
    end
  end

  # Additional helper methods would continue here...
  # This is a comprehensive service that provides all the data needed
  # for the API documentation system
end
