RSpec.configure do |config|
  # Configure different test types with specific metadata
  
  # Model tests - fast unit tests
  config.define_derived_metadata(file_path: %r{/spec/models/}) do |metadata|
    metadata[:type] = :model
    metadata[:focus] = true if metadata[:focus].nil?
  end
  
  # Service tests - business logic tests
  config.define_derived_metadata(file_path: %r{/spec/services/}) do |metadata|
    metadata[:type] = :service
  end
  
  # Integration tests - multi-component workflow tests
  config.define_derived_metadata(file_path: %r{/spec/integration/}) do |metadata|
    metadata[:type] = :integration
    metadata[:slow] = true
  end
  
  # API tests - request/response tests
  config.define_derived_metadata(file_path: %r{/spec/requests/}) do |metadata|
    metadata[:type] = :request
    metadata[:api] = true
  end
  
  # Performance tests - load and timing tests
  config.define_derived_metadata(file_path: %r{/spec/performance/}) do |metadata|
    metadata[:type] = :performance
    metadata[:slow] = true
    metadata[:performance] = true
  end
  
  # Security tests - vulnerability and penetration tests
  config.define_derived_metadata(file_path: %r{/spec/security/}) do |metadata|
    metadata[:type] = :security
    metadata[:security] = true
  end
  
  # Feature tests - end-to-end user journey tests
  config.define_derived_metadata(file_path: %r{/spec/features/}) do |metadata|
    metadata[:type] = :feature
    metadata[:slow] = true
    metadata[:js] = true
  end
  
  # Test suite configurations based on metadata
  
  # Skip slow tests by default unless specifically requested
  config.filter_run_excluding :slow unless ENV['RUN_SLOW_TESTS'] == 'true'
  
  # Run only specific test types when requested
  config.filter_run_including :focus if ENV['FOCUS_TESTS'] == 'true'
  config.filter_run_including :api if ENV['API_TESTS'] == 'true'
  config.filter_run_including :security if ENV['SECURITY_TESTS'] == 'true'
  config.filter_run_including :performance if ENV['PERFORMANCE_TESTS'] == 'true'
  
  # Database configuration for different test types
  config.before(:each, type: :performance) do
    # Use separate test database for performance tests to avoid interference
    ActiveRecord::Base.establish_connection :test_performance if defined?(ActiveRecord::Base)
  end
  
  config.before(:each, type: :security) do
    # Enable additional security logging for security tests
    Rails.logger.level = Logger::DEBUG if Rails.logger
  end
  
  # Memory and performance monitoring
  config.before(:each, :performance) do
    GC.start # Clean garbage before performance tests
    @start_memory = `ps -o pid,rss -p #{Process.pid}`.strip.split.last.to_i
  end
  
  config.after(:each, :performance) do
    GC.start
    end_memory = `ps -o pid,rss -p #{Process.pid}`.strip.split.last.to_i
    memory_growth = end_memory - @start_memory
    
    if memory_growth > 50_000 # More than 50MB growth
      puts "WARNING: Test consumed #{memory_growth}KB memory"
    end
  end
  
  # API test helpers
  config.before(:each, :api) do
    # Set default API headers
    @api_headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
  
  # Security test helpers
  config.before(:each, :security) do
    # Capture security events during tests
    @security_events = []
    allow(SecurityLogger).to receive(:log) { |event| @security_events << event }
  end
  
  # Test reporting and documentation
  config.after(:suite) do
    if ENV['GENERATE_TEST_REPORT'] == 'true'
      generate_test_coverage_report
      generate_test_documentation
    end
  end
  
  # Helper methods for test organization
  def self.generate_test_coverage_report
    puts "\n=== Test Coverage Report ==="
    puts "Models: #{Dir.glob('spec/models/*_spec.rb').count} test files"
    puts "Services: #{Dir.glob('spec/services/*_spec.rb').count} test files"
    puts "Controllers: #{Dir.glob('spec/controllers/*_spec.rb').count} test files"
    puts "Requests: #{Dir.glob('spec/requests/**/*_spec.rb').count} test files"
    puts "Integration: #{Dir.glob('spec/integration/*_spec.rb').count} test files"
    puts "Performance: #{Dir.glob('spec/performance/*_spec.rb').count} test files"
    puts "Security: #{Dir.glob('spec/security/*_spec.rb').count} test files"
    puts "Features: #{Dir.glob('spec/features/*_spec.rb').count} test files"
    puts "===========================\n"
  end
  
  def self.generate_test_documentation
    # Generate markdown documentation of test structure
    test_docs = []
    test_docs << "# BrokerSync Test Suite Documentation"
    test_docs << ""
    test_docs << "## Test Organization"
    test_docs << ""
    test_docs << "### Unit Tests"
    test_docs << "- **Models**: Core business logic validation"
    test_docs << "- **Services**: Business process testing"
    test_docs << "- **Helpers**: Utility function testing"
    test_docs << ""
    test_docs << "### Integration Tests"
    test_docs << "- **Workflows**: Complete business process testing"
    test_docs << "- **API Endpoints**: Request/response validation"
    test_docs << "- **Authentication**: Security flow testing"
    test_docs << ""
    test_docs << "### Performance Tests"
    test_docs << "- **Database Queries**: Optimization validation"
    test_docs << "- **Memory Usage**: Resource consumption testing"
    test_docs << "- **Load Testing**: High-traffic scenario validation"
    test_docs << ""
    test_docs << "### Security Tests"
    test_docs << "- **Authentication**: Login and session security"
    test_docs << "- **Authorization**: Permission and access control"
    test_docs << "- **Input Validation**: XSS and injection prevention"
    test_docs << "- **Data Protection**: Encryption and privacy"
    test_docs << ""
    test_docs << "## Running Tests"
    test_docs << ""
    test_docs << "```bash"
    test_docs << "# Run all tests"
    test_docs << "bundle exec rspec"
    test_docs << ""
    test_docs << "# Run specific test types"
    test_docs << "API_TESTS=true bundle exec rspec"
    test_docs << "SECURITY_TESTS=true bundle exec rspec"
    test_docs << "PERFORMANCE_TESTS=true bundle exec rspec"
    test_docs << ""
    test_docs << "# Run slow tests"
    test_docs << "RUN_SLOW_TESTS=true bundle exec rspec"
    test_docs << ""
    test_docs << "# Generate test report"
    test_docs << "GENERATE_TEST_REPORT=true bundle exec rspec"
    test_docs << "```"
    
    File.write('TEST_DOCUMENTATION.md', test_docs.join("\n"))
    puts "Generated TEST_DOCUMENTATION.md"
  end
end

# Custom matchers for BrokerSync-specific testing
RSpec::Matchers.define :be_valid_application_number do
  match do |actual|
    actual.match?(/^APP\d{6}$/)
  end
  
  failure_message do |actual|
    "expected '#{actual}' to be a valid application number (format: APP######)"
  end
end

RSpec::Matchers.define :be_valid_quote_number do
  match do |actual|
    actual.match?(/^QTE\d{6}$/)
  end
  
  failure_message do |actual|
    "expected '#{actual}' to be a valid quote number (format: QTE######)"
  end
end

RSpec::Matchers.define :have_audit_trail do
  match do |actual|
    actual.respond_to?(:audits) && actual.audits.any?
  end
  
  failure_message do |actual|
    "expected #{actual.class.name} to have audit trail"
  end
end

RSpec::Matchers.define :be_encrypted_field do |field_name|
  match do |model_class|
    model_class.respond_to?(:encrypted_fields_metadata) &&
    model_class.encrypted_fields_metadata.key?(field_name.to_sym)
  end
  
  failure_message do |model_class|
    "expected #{model_class.name} to encrypt field '#{field_name}'"
  end
end

RSpec::Matchers.define :respond_within do |expected_time|
  match do |block|
    start_time = Time.current
    block.call
    execution_time = Time.current - start_time
    execution_time <= expected_time
  end
  
  failure_message do |block|
    "expected code block to execute within #{expected_time} seconds"
  end
end