// tests/support/global-setup.js
const { execSync } = require('child_process');

async function globalSetup() {
  console.log('🚀 Starting BrokerSync Test Suite Setup...');
  
  try {
    // Ensure test database is ready
    console.log('📦 Setting up test database...');
    execSync('RAILS_ENV=test rails db:create db:migrate', { stdio: 'inherit' });
    
    // Seed test data
    console.log('🌱 Seeding test data...');
    execSync('RAILS_ENV=test rails db:seed', { stdio: 'inherit' });
    
    // Copy test documents to public directory for tests
    console.log('📄 Setting up test documents...');
    execSync('mkdir -p public/test-documents', { stdio: 'inherit' });
    execSync('cp -r test-documents/* public/test-documents/', { stdio: 'inherit' });
    
    console.log('✅ Test setup completed successfully');
  } catch (error) {
    console.error('❌ Test setup failed:', error.message);
    process.exit(1);
  }
}

module.exports = globalSetup;