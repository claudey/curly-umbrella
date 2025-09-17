class ApiDocsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_api_access
  
  def index
    @api_endpoints = load_api_endpoints
    @authentication_methods = load_authentication_methods
    @rate_limits = load_rate_limits
    @recent_api_usage = load_recent_api_usage if current_user.api_keys.any?
  end
  
  def playground
    @endpoints = load_api_endpoints_for_playground
    @user_api_keys = current_user.api_keys.active
  end
  
  def try_endpoint
    endpoint_name = params[:endpoint]
    endpoint_config = find_endpoint_config(endpoint_name)
    
    return render json: { error: 'Endpoint not found' }, status: :not_found unless endpoint_config
    
    begin
      result = execute_api_request(endpoint_config, request_params)
      render json: { success: true, data: result }
    rescue => e
      render json: { 
        success: false, 
        error: e.message,
        details: format_api_error(e)
      }, status: :unprocessable_entity
    end
  end
  
  def generate_code_example
    language = params[:language]
    endpoint = params[:endpoint]
    method = params[:method]
    
    code_example = generate_code_for_language(language, endpoint, method, params[:example_data])
    
    render json: {
      success: true,
      code: code_example,
      language: language
    }
  end
  
  def download_postman_collection
    collection = generate_postman_collection
    
    send_data collection.to_json,
              filename: "brokersync-api-collection.json",
              type: 'application/json',
              disposition: 'attachment'
  end
  
  def download_openapi_spec
    spec = generate_openapi_specification
    
    send_data spec.to_yaml,
              filename: "brokersync-openapi-spec.yml",
              type: 'application/x-yaml',
              disposition: 'attachment'
  end
  
  private
  
  def require_api_access
    unless current_user.has_api_access?
      redirect_to root_path, alert: 'API access required to view documentation.'
    end
  end
  
  def load_api_endpoints
    [
      {
        name: 'Applications',
        base_path: '/api/v1/applications',
        description: 'Manage insurance applications',
        endpoints: [
          {
            method: 'GET',
            path: '/api/v1/applications',
            name: 'List Applications',
            description: 'Retrieve paginated list of applications',
            parameters: [
              { name: 'page', type: 'integer', required: false, description: 'Page number' },
              { name: 'per_page', type: 'integer', required: false, description: 'Items per page' },
              { name: 'status', type: 'string', required: false, description: 'Filter by status' },
              { name: 'insurance_type', type: 'string', required: false, description: 'Filter by insurance type' }
            ],
            response_example: load_example_response('applications_list')
          },
          {
            method: 'GET',
            path: '/api/v1/applications/{id}',
            name: 'Get Application',
            description: 'Retrieve specific application details',
            parameters: [
              { name: 'id', type: 'integer', required: true, description: 'Application ID' }
            ],
            response_example: load_example_response('application_details')
          },
          {
            method: 'POST',
            path: '/api/v1/applications',
            name: 'Create Application',
            description: 'Create new insurance application',
            request_example: load_example_request('create_application'),
            response_example: load_example_response('application_created')
          },
          {
            method: 'POST',
            path: '/api/v1/applications/{id}/submit',
            name: 'Submit Application',
            description: 'Submit application for review',
            parameters: [
              { name: 'id', type: 'integer', required: true, description: 'Application ID' }
            ],
            response_example: load_example_response('application_submitted')
          }
        ]
      },
      {
        name: 'Quotes',
        base_path: '/api/v1/quotes',
        description: 'Manage insurance quotes',
        endpoints: [
          {
            method: 'GET',
            path: '/api/v1/quotes',
            name: 'List Quotes',
            description: 'Retrieve paginated list of quotes',
            parameters: [
              { name: 'application_id', type: 'integer', required: false, description: 'Filter by application' },
              { name: 'status', type: 'string', required: false, description: 'Filter by status' }
            ],
            response_example: load_example_response('quotes_list')
          },
          {
            method: 'POST',
            path: '/api/v1/quotes',
            name: 'Create Quote',
            description: 'Create new quote for application',
            request_example: load_example_request('create_quote'),
            response_example: load_example_response('quote_created')
          },
          {
            method: 'POST',
            path: '/api/v1/quotes/{id}/accept',
            name: 'Accept Quote',
            description: 'Accept quote and initiate policy creation',
            parameters: [
              { name: 'id', type: 'integer', required: true, description: 'Quote ID' }
            ],
            response_example: load_example_response('quote_accepted')
          }
        ]
      },
      {
        name: 'Feature Flags',
        base_path: '/api/v1/feature_flags',
        description: 'Manage feature flags',
        endpoints: [
          {
            method: 'GET',
            path: '/api/v1/feature_flags/check',
            name: 'Check Feature Flags',
            description: 'Check multiple feature flags for user',
            parameters: [
              { name: 'keys[]', type: 'array', required: true, description: 'Feature flag keys to check' },
              { name: 'user_id', type: 'integer', required: false, description: 'User ID for user-specific flags' },
              { name: 'context', type: 'object', required: false, description: 'Additional context for evaluation' }
            ],
            response_example: load_example_response('feature_flags_check')
          }
        ]
      },
      {
        name: 'Analytics',
        base_path: '/api/v1/analytics',
        description: 'Access analytics and reporting data',
        endpoints: [
          {
            method: 'GET',
            path: '/api/v1/analytics/usage',
            name: 'Usage Analytics',
            description: 'Get API usage analytics',
            parameters: [
              { name: 'start_date', type: 'string', required: true, description: 'Start date (ISO 8601)' },
              { name: 'end_date', type: 'string', required: true, description: 'End date (ISO 8601)' },
              { name: 'granularity', type: 'string', required: false, description: 'Data granularity (hour, day, week, month)' }
            ],
            response_example: load_example_response('usage_analytics')
          }
        ]
      }
    ]
  end
  
  def load_authentication_methods
    [
      {
        type: 'JWT Authentication',
        description: 'User-based authentication using JSON Web Tokens',
        header: 'Authorization: Bearer <jwt_token>',
        example: {
          request: 'POST /api/v1/auth/login',
          body: { email: 'user@example.com', password: 'password' },
          response: { token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...', expires_at: '2024-01-15T10:30:00Z' }
        }
      },
      {
        type: 'API Key Authentication',
        description: 'Server-to-server authentication using API keys',
        header: 'X-API-Key: <api_key>',
        scopes: ['read', 'write', 'analytics', 'admin'],
        example: {
          request: 'GET /api/v1/applications',
          headers: { 'X-API-Key': 'your-api-key' }
        }
      }
    ]
  end
  
  def load_rate_limits
    [
      { tier: 'Free', requests_per_hour: 1000, burst_limit: 100 },
      { tier: 'Professional', requests_per_hour: 10000, burst_limit: 500 },
      { tier: 'Enterprise', requests_per_hour: 100000, burst_limit: 2000 }
    ]
  end
  
  def load_recent_api_usage
    return {} unless current_user.api_keys.any?
    
    # Mock data - replace with actual analytics
    {
      last_24_hours: {
        requests: 250,
        successful: 245,
        errors: 5,
        rate_limited: 0
      },
      popular_endpoints: [
        { endpoint: '/api/v1/applications', requests: 150 },
        { endpoint: '/api/v1/quotes', requests: 75 },
        { endpoint: '/api/v1/analytics/usage', requests: 25 }
      ]
    }
  end
  
  def load_api_endpoints_for_playground
    load_api_endpoints.flat_map { |group| group[:endpoints] }
  end
  
  def find_endpoint_config(endpoint_name)
    load_api_endpoints_for_playground.find { |ep| ep[:name] == endpoint_name }
  end
  
  def execute_api_request(endpoint_config, params)
    # This would make actual API calls in a real implementation
    # For demo purposes, return mock data
    {
      endpoint: endpoint_config[:name],
      method: endpoint_config[:method],
      path: endpoint_config[:path],
      response: endpoint_config[:response_example],
      timestamp: Time.current
    }
  end
  
  def format_api_error(error)
    {
      type: error.class.name,
      message: error.message,
      backtrace: Rails.env.development? ? error.backtrace.first(5) : nil
    }
  end
  
  def generate_code_for_language(language, endpoint, method, example_data)
    case language.downcase
    when 'javascript'
      generate_javascript_example(endpoint, method, example_data)
    when 'python'
      generate_python_example(endpoint, method, example_data)
    when 'php'
      generate_php_example(endpoint, method, example_data)
    when 'curl'
      generate_curl_example(endpoint, method, example_data)
    else
      "// Code example for #{language} not available"
    end
  end
  
  def generate_javascript_example(endpoint, method, example_data)
    <<~JAVASCRIPT
      // JavaScript/Node.js Example
      const axios = require('axios');
      
      const api = axios.create({
        baseURL: 'https://api.brokersync.com/api/v1',
        headers: {
          'X-API-Key': 'your-api-key',
          'Content-Type': 'application/json'
        }
      });
      
      async function #{method.downcase}#{endpoint.gsub(/[^a-zA-Z0-9]/, '')}() {
        try {
          const response = await api.#{method.downcase}('#{endpoint}', #{example_data ? JSON.pretty_generate(example_data) : ''});
          console.log('Success:', response.data);
          return response.data;
        } catch (error) {
          console.error('Error:', error.response?.data || error.message);
          throw error;
        }
      }
      
      // Usage
      #{method.downcase}#{endpoint.gsub(/[^a-zA-Z0-9]/, '')}()
        .then(data => console.log('Result:', data))
        .catch(error => console.error('Failed:', error));
    JAVASCRIPT
  end
  
  def generate_python_example(endpoint, method, example_data)
    <<~PYTHON
      # Python Example
      import requests
      import json
      
      # API Configuration
      BASE_URL = 'https://api.brokersync.com/api/v1'
      API_KEY = 'your-api-key'
      
      headers = {
          'X-API-Key': API_KEY,
          'Content-Type': 'application/json'
      }
      
      def #{method.downcase}_#{endpoint.gsub(/[^a-zA-Z0-9]/, '_').downcase}():
          url = f"{BASE_URL}#{endpoint}"
          #{example_data ? "data = #{JSON.pretty_generate(example_data).gsub(/[{}]/, '{"' => '{', '"}' => '}')}" : ''}
          
          try:
              response = requests.#{method.downcase}(url, headers=headers#{example_data ? ', json=data' : ''})
              response.raise_for_status()
              result = response.json()
              print(f"Success: {result}")
              return result
          except requests.exceptions.RequestException as e:
              print(f"Error: {e}")
              if hasattr(e, 'response') and e.response is not None:
                  print(f"Response: {e.response.text}")
              raise
      
      # Usage
      if __name__ == "__main__":
          result = #{method.downcase}_#{endpoint.gsub(/[^a-zA-Z0-9]/, '_').downcase}()
    PYTHON
  end
  
  def generate_curl_example(endpoint, method, example_data)
    <<~CURL
      # cURL Example
      curl -X #{method.upcase} "https://api.brokersync.com/api/v1#{endpoint}" \\
        -H "X-API-Key: your-api-key" \\
        -H "Content-Type: application/json" #{example_data ? "\\\n  -d '#{JSON.pretty_generate(example_data)}'" : ''}
    CURL
  end
  
  def generate_postman_collection
    {
      info: {
        name: "BrokerSync API",
        description: "Complete BrokerSync API collection",
        version: "1.0.0"
      },
      auth: {
        type: "apikey",
        apikey: [
          { key: "key", value: "X-API-Key" },
          { key: "value", value: "{{api_key}}" }
        ]
      },
      variable: [
        { key: "base_url", value: "https://api.brokersync.com/api/v1" },
        { key: "api_key", value: "your-api-key" }
      ],
      item: generate_postman_items
    }
  end
  
  def generate_postman_items
    load_api_endpoints.map do |group|
      {
        name: group[:name],
        description: group[:description],
        item: group[:endpoints].map do |endpoint|
          {
            name: endpoint[:name],
            request: {
              method: endpoint[:method],
              header: [
                { key: "Content-Type", value: "application/json" }
              ],
              url: {
                raw: "{{base_url}}#{endpoint[:path]}",
                host: ["{{base_url}}"],
                path: endpoint[:path].split('/').reject(&:empty?)
              },
              body: endpoint[:request_example] ? {
                mode: "raw",
                raw: JSON.pretty_generate(endpoint[:request_example])
              } : nil
            }.compact,
            response: endpoint[:response_example] ? [{
              name: "Success Response",
              body: JSON.pretty_generate(endpoint[:response_example])
            }] : []
          }
        end
      }
    end
  end
  
  def generate_openapi_specification
    {
      openapi: "3.0.0",
      info: {
        title: "BrokerSync API",
        description: "Comprehensive insurance brokerage platform API",
        version: "1.0.0",
        contact: {
          name: "API Support",
          email: "api-support@brokersync.com"
        }
      },
      servers: [
        { url: "https://api.brokersync.com/api/v1", description: "Production" },
        { url: "https://staging-api.brokersync.com/api/v1", description: "Staging" }
      ],
      security: [
        { ApiKeyAuth: [] },
        { BearerAuth: [] }
      ],
      components: {
        securitySchemes: {
          ApiKeyAuth: {
            type: "apiKey",
            in: "header",
            name: "X-API-Key"
          },
          BearerAuth: {
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT"
          }
        }
      },
      paths: generate_openapi_paths
    }
  end
  
  def generate_openapi_paths
    paths = {}
    
    load_api_endpoints.each do |group|
      group[:endpoints].each do |endpoint|
        path_key = endpoint[:path].gsub(/{(\w+)}/, '{\1}')
        paths[path_key] ||= {}
        
        paths[path_key][endpoint[:method].downcase] = {
          summary: endpoint[:name],
          description: endpoint[:description],
          parameters: endpoint[:parameters]&.map do |param|
            {
              name: param[:name],
              in: param[:name] == 'id' ? 'path' : 'query',
              required: param[:required],
              schema: { type: param[:type] },
              description: param[:description]
            }
          end,
          responses: {
            '200' => {
              description: 'Success',
              content: {
                'application/json' => {
                  example: endpoint[:response_example]
                }
              }
            }
          }
        }.compact
      end
    end
    
    paths
  end
  
  def load_example_response(type)
    examples = {
      'applications_list' => {
        success: true,
        data: {
          applications: [
            {
              id: 12345,
              application_number: "APP-2024-001234",
              insurance_type: "motor",
              status: "submitted",
              applicant: { name: "John Doe", email: "john@example.com" },
              created_at: "2024-01-10T10:15:00Z"
            }
          ],
          pagination: { current_page: 1, total_pages: 25, total_count: 1250 }
        }
      },
      'feature_flags_check' => {
        success: true,
        data: {
          results: { new_dashboard_ui: false, api_v2: true },
          user_id: 123,
          checked_at: "2024-01-10T15:30:00Z"
        }
      }
    }
    
    examples[type] || { success: true, data: {} }
  end
  
  def load_example_request(type)
    examples = {
      'create_application' => {
        application: {
          insurance_type: "motor",
          applicant: {
            name: "John Doe",
            email: "john@example.com",
            phone: "+1234567890"
          },
          vehicle: {
            make: "Toyota",
            model: "Camry",
            year: 2022,
            vin: "1HGBH41JXMN109186"
          }
        }
      }
    }
    
    examples[type] || {}
  end
  
  def request_params
    params.except(:controller, :action, :endpoint)
  end
end