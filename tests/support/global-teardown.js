// tests/support/global-teardown.js
const { execSync } = require('child_process');

async function globalTeardown() {
  console.log('🧹 Starting BrokerSync Test Suite Cleanup...');
  
  try {
    // Clean up test files
    console.log('🗑️  Cleaning up test files...');
    execSync('rm -rf public/test-documents', { stdio: 'inherit' });
    
    // Reset test database
    console.log('🗄️  Resetting test database...');
    execSync('RAILS_ENV=test rails db:drop', { stdio: 'inherit' });
    
    console.log('✅ Test cleanup completed successfully');
  } catch (error) {
    console.error('❌ Test cleanup failed:', error.message);
    // Don't exit with error on cleanup failure
  }
}

module.exports = globalTeardown;