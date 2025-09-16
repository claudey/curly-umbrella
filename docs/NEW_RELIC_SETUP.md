# New Relic Application Performance Monitoring Setup Guide

This guide covers the complete setup and configuration of New Relic APM for the BrokerSync insurance platform.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Custom Instrumentation](#custom-instrumentation)
6. [Dashboard Setup](#dashboard-setup)
7. [Alerts and Notifications](#alerts-and-notifications)
8. [Production Deployment](#production-deployment)
9. [Troubleshooting](#troubleshooting)

## Overview

The BrokerSync New Relic implementation provides comprehensive monitoring including:

- **Application Performance Monitoring**: Real-time performance tracking
- **Business Intelligence**: Custom metrics for insurance-specific KPIs
- **Error Tracking**: Advanced error monitoring with business impact assessment
- **Infrastructure Monitoring**: Database, Redis, and system health tracking
- **User Experience Monitoring**: Real user monitoring and engagement tracking
- **Custom Dashboards**: Pre-configured dashboards for business insights

## Prerequisites

### Required Software
- Ruby on Rails 8.x
- New Relic account (sign up at https://newrelic.com)
- Redis (for caching metrics)
- PostgreSQL (for data persistence)

### Required Information
- New Relic License Key
- New Relic Account ID
- Application deployment environment details

## Installation

### 1. Add New Relic Gem

The `newrelic_rpm` gem has already been added to the Gemfile:

```ruby
# Application Performance Monitoring
gem "newrelic_rpm", "~> 9.19"
```

Install dependencies:

```bash
bundle install
```

### 2. Generate Configuration

The New Relic configuration file is already created at `config/newrelic.yml`. This file includes:

- Environment-specific settings
- Custom instrumentation configuration
- Security and compliance settings
- Business-specific attribute collection

## Configuration

### Environment Variables

Set the following environment variables in your production environment:

```bash
# Required
NEW_RELIC_LICENSE_KEY=your_license_key_here
NEW_RELIC_APP_NAME="BrokerSync (Production)"
NEW_RELIC_ACCOUNT_ID=your_account_id_here

# Optional but recommended
APP_VERSION=1.0.0
GIT_COMMIT=your_git_commit_hash
DEPLOYMENT_TIME=2024-12-16T10:00:00Z
SERVER_ROLE=web

# For Infinite Tracing (optional)
NEW_RELIC_INFINITE_TRACING_TRACE_OBSERVER_HOST=your_trace_observer_host
```

### Application Configuration

1. **Review `config/newrelic.yml`** - Ensure all settings match your environment
2. **Update `config/environments/production.rb`** - Add monitoring-specific configurations
3. **Configure SSL** - Ensure proper SSL configuration for secure data transmission

## Custom Instrumentation

### Business Metrics Tracking

The implementation includes custom tracking for:

#### Application Processing
```ruby
# Track application submissions
NewRelicInstrumentationService.track_application_submitted(application)

# Track application approvals with processing time
NewRelicInstrumentationService.track_application_approved(application, processing_time_hours)
```

#### Document Management
```ruby
# Track document processing
NewRelicInstrumentationService.track_document_processed(document, processing_time_seconds)
```

#### Quote Generation
```ruby
# Track quote generation with performance metrics
NewRelicInstrumentationService.track_quote_generated(quote, generation_time_seconds)
```

#### User Engagement
```ruby
# Track user session activity
NewRelicInstrumentationService.track_user_session_activity(user, session_duration, actions_count)
```

### Automatic Instrumentation

The following components are automatically instrumented:

- **Controllers**: All controller actions with custom attributes
- **Models**: Key business model methods (Application, Quote, Document)
- **Background Jobs**: Job performance and error tracking
- **Database Queries**: Slow query detection and tracking
- **API Endpoints**: Response time and error rate monitoring

### Custom Events

Business events are automatically tracked:

- `ApplicationSubmitted`
- `ApplicationApproved`
- `QuoteGenerated`
- `DocumentProcessed`
- `UserSessionActivity`
- `SystemPerformanceAlert`
- `ApplicationError`
- `SlowDatabaseQuery`
- `APIPerformance`
- `BackgroundJobPerformance`

## Dashboard Setup

### Automated Dashboard Creation

Use the dashboard service to generate New Relic dashboards:

```ruby
# Generate dashboard configuration
config = NewRelicDashboardService.generate_dashboard_config

# Export as JSON for New Relic API
json_config = NewRelicDashboardService.export_dashboard_json
```

### Pre-configured Dashboards

The implementation includes 6 pre-configured dashboard pages:

1. **Business Overview**: High-level KPIs and metrics
2. **Application Processing**: Insurance application workflow metrics
3. **Document Management**: Document processing and compliance
4. **User Engagement**: User activity and engagement tracking
5. **System Performance**: Application and infrastructure performance
6. **Error Monitoring**: Error tracking and system health

### Manual Dashboard Setup

1. Log into your New Relic account
2. Navigate to Dashboards
3. Create a new dashboard
4. Use the provided NRQL queries from `NewRelicDashboardService.business_metric_queries`

## Alerts and Notifications

### Recommended Alerts

Set up alerts for the following conditions:

#### Business Critical
- Application approval rate < 70%
- Quote conversion rate < 50%
- Document compliance rate < 90%
- System uptime < 99%

#### Performance
- API response time > 2 seconds
- Database query time > 1 second
- Background job failure rate > 5%
- Error rate > 1%

#### Infrastructure
- Memory usage > 85%
- CPU usage > 80%
- Database connection pool > 90% utilized
- Redis memory usage > 1GB

### Alert Configuration

```sql
-- Example NRQL for application approval rate alert
SELECT percentage(count(*), WHERE event = 'ApplicationApproved') 
FROM ApplicationSubmitted, ApplicationApproved 
SINCE 24 HOURS AGO
```

## Production Deployment

### Pre-deployment Checklist

- [ ] New Relic license key configured
- [ ] Environment variables set
- [ ] SSL certificates configured
- [ ] Database migrations completed
- [ ] Background job queues running

### Deployment Steps

1. **Deploy Application**
   ```bash
   # Deploy with environment variables
   RAILS_ENV=production bundle exec rails server
   ```

2. **Verify New Relic Connection**
   - Check New Relic dashboard for incoming data
   - Verify application appears in APM
   - Confirm custom events are being received

3. **Test Custom Instrumentation**
   ```ruby
   # Test business event tracking
   NewRelicInstrumentationService.track_business_event('DeploymentTest', {
     version: ENV['APP_VERSION'],
     environment: Rails.env
   })
   ```

4. **Set Up Dashboards**
   - Import pre-configured dashboards
   - Customize for your specific needs
   - Set up team access permissions

5. **Configure Alerts**
   - Set up business-critical alerts
   - Configure notification channels
   - Test alert delivery

### Post-deployment Verification

1. **Check Data Flow**
   - APM data appearing in New Relic
   - Custom events being recorded
   - Business metrics updating

2. **Validate Dashboards**
   - All widgets loading data
   - Metrics displaying correctly
   - Time ranges working properly

3. **Test Alerts**
   - Trigger test alerts
   - Verify notification delivery
   - Confirm escalation policies

## Troubleshooting

### Common Issues

#### New Relic Agent Not Starting
```bash
# Check logs for agent status
tail -f log/newrelic_agent.log

# Verify license key
echo $NEW_RELIC_LICENSE_KEY

# Check agent configuration
bundle exec rails runner "puts NewRelic::Agent.config.inspect"
```

#### Missing Custom Events
```ruby
# Verify instrumentation service is loaded
NewRelicInstrumentationService.new_relic_enabled?

# Check for custom event limits
# New Relic has limits on custom events per minute
```

#### Dashboard Not Loading Data
- Verify NRQL queries are correct
- Check account ID in dashboard configuration
- Ensure time range is appropriate
- Confirm custom events are being sent

#### Performance Impact
- Monitor agent overhead (should be < 5%)
- Adjust sampling rates if needed
- Review custom instrumentation frequency

### Debug Mode

Enable debug mode in development:

```yaml
# config/newrelic.yml
development:
  log_level: debug
  agent_enabled: true
```

### Support Resources

- [New Relic Ruby Agent Documentation](https://docs.newrelic.com/docs/agents/ruby-agent/)
- [NRQL Query Language Reference](https://docs.newrelic.com/docs/query-your-data/nrql-new-relic-query-language/)
- [Custom Instrumentation Guide](https://docs.newrelic.com/docs/agents/ruby-agent/api-guides/)

## Maintenance

### Regular Tasks

1. **Monthly Review**
   - Review dashboard metrics
   - Update alert thresholds
   - Analyze performance trends

2. **Quarterly Optimization**
   - Review custom instrumentation performance
   - Update dashboard queries
   - Optimize data retention policies

3. **Annual Assessment**
   - Evaluate monitoring strategy
   - Review business metric relevance
   - Update documentation

### Data Retention

- APM data: 8 days (standard plan)
- Custom events: 30 days
- Dashboard data: Varies by subscription
- Consider data export for long-term analysis

## Security Considerations

### Data Privacy
- PII filtering configured in `config/newrelic.yml`
- Sensitive parameters excluded from traces
- SQL obfuscation enabled in production

### Access Control
- Limit New Relic account access
- Use read-only keys for dashboards
- Regular access review

### Compliance
- GDPR compliance through data filtering
- HIPAA considerations for healthcare data
- SOC 2 compliance with proper configuration

---

For additional support or questions about the New Relic setup, please refer to the BrokerSync technical documentation or contact the development team.