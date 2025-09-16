# frozen_string_literal: true

class NewRelicDashboardService
  class << self
    # Generate dashboard configuration for BrokerSync business metrics
    def generate_dashboard_config
      {
        name: "BrokerSync Business Intelligence Dashboard",
        description: "Comprehensive business metrics and performance monitoring for BrokerSync insurance platform",
        permissions: "public_read_only",
        pages: [
          business_overview_page,
          application_processing_page,
          document_management_page,
          user_engagement_page,
          system_performance_page,
          error_monitoring_page
        ]
      }
    end
    
    # Export dashboard configuration as JSON for New Relic API
    def export_dashboard_json
      require 'json'
      JSON.pretty_generate(generate_dashboard_config)
    end
    
    # Generate NRQL queries for business metrics
    def business_metric_queries
      {
        # Application Processing Metrics
        applications_submitted_today: "SELECT count(*) FROM ApplicationSubmitted WHERE timestamp > #{today_timestamp} TIMESERIES AUTO",
        application_approval_rate: "SELECT percentage(count(*), WHERE event = 'ApplicationApproved') FROM ApplicationSubmitted, ApplicationApproved SINCE 24 HOURS AGO",
        average_processing_time: "SELECT average(processing_time_hours) FROM ApplicationApproved SINCE 7 DAYS AGO TIMESERIES AUTO",
        
        # Quote Generation Metrics
        quotes_generated_today: "SELECT count(*) FROM QuoteGenerated WHERE timestamp > #{today_timestamp} TIMESERIES AUTO",
        average_quote_amount: "SELECT average(quote_amount) FROM QuoteGenerated SINCE 24 HOURS AGO",
        quote_conversion_rate: "SELECT percentage(count(*), WHERE status = 'accepted') FROM QuoteGenerated SINCE 7 DAYS AGO",
        
        # Document Processing Metrics
        documents_processed_today: "SELECT count(*) FROM DocumentProcessed WHERE timestamp > #{today_timestamp} TIMESERIES AUTO",
        document_processing_time: "SELECT average(processing_time_seconds) FROM DocumentProcessed SINCE 24 HOURS AGO",
        document_compliance_rate: "SELECT percentage(count(*), WHERE processing_status = 'compliant') FROM DocumentProcessed SINCE 7 DAYS AGO",
        
        # User Engagement Metrics
        active_users_today: "SELECT uniqueCount(user_id) FROM UserSessionActivity WHERE timestamp > #{today_timestamp}",
        average_session_duration: "SELECT average(session_duration_minutes) FROM UserSessionActivity SINCE 24 HOURS AGO",
        user_engagement_distribution: "SELECT count(*) FROM UserSessionActivity FACET engagement_level SINCE 7 DAYS AGO",
        
        # System Performance Metrics
        api_response_times: "SELECT average(duration_ms) FROM APIPerformance FACET endpoint SINCE 1 HOUR AGO TIMESERIES AUTO",
        slow_queries: "SELECT count(*) FROM SlowDatabaseQuery SINCE 1 HOUR AGO TIMESERIES AUTO",
        background_job_performance: "SELECT count(*) FROM BackgroundJobPerformance FACET performance_category SINCE 6 HOURS AGO",
        
        # Error Monitoring
        error_rate_by_type: "SELECT count(*) FROM ApplicationError FACET error_class SINCE 24 HOURS AGO",
        business_impact_errors: "SELECT count(*) FROM ApplicationError FACET business_impact SINCE 24 HOURS AGO",
        error_trends: "SELECT count(*) FROM ApplicationError SINCE 7 DAYS AGO TIMESERIES AUTO"
      }
    end
    
    private
    
    def today_timestamp
      Time.current.beginning_of_day.to_i
    end
    
    def business_overview_page
      {
        name: "Business Overview",
        description: "High-level business metrics and KPIs",
        widgets: [
          {
            title: "Applications Submitted Today",
            layout: { column: 1, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.billboard" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:applications_submitted_today]
                }
              ],
              platformOptions: { ignoreTimeRange: false }
            }
          },
          {
            title: "Application Approval Rate",
            layout: { column: 5, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.billboard" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:application_approval_rate]
                }
              ],
              platformOptions: { ignoreTimeRange: false },
              thresholds: [
                { alertSeverity: "CRITICAL", value: 50 },
                { alertSeverity: "WARNING", value: 70 }
              ]
            }
          },
          {
            title: "Quote Conversion Rate",
            layout: { column: 9, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.billboard" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:quote_conversion_rate]
                }
              ],
              platformOptions: { ignoreTimeRange: false }
            }
          },
          {
            title: "Daily Application Processing Trend",
            layout: { column: 1, row: 4, width: 8, height: 4 },
            visualization: { id: "viz.line" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              legend: { enabled: true },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: "SELECT count(*) FROM ApplicationSubmitted SINCE 30 DAYS AGO TIMESERIES 1 DAY"
                }
              ],
              platformOptions: { ignoreTimeRange: false },
              yAxisLeft: { zero: true }
            }
          },
          {
            title: "Active Organizations",
            layout: { column: 9, row: 4, width: 4, height: 4 },
            visualization: { id: "viz.billboard" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: "SELECT latest(active_organizations) FROM Metric WHERE metricName = 'Custom/Business/active_organizations' SINCE 1 HOUR AGO"
                }
              ],
              platformOptions: { ignoreTimeRange: false }
            }
          }
        ]
      }
    end
    
    def application_processing_page
      {
        name: "Application Processing",
        description: "Detailed metrics for insurance application processing",
        widgets: [
          {
            title: "Processing Time Distribution",
            layout: { column: 1, row: 1, width: 6, height: 4 },
            visualization: { id: "viz.histogram" },
            rawConfiguration: {
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: "SELECT histogram(processing_time_hours, 50, 10) FROM ApplicationApproved SINCE 7 DAYS AGO"
                }
              ]
            }
          },
          {
            title: "Applications by Type",
            layout: { column: 7, row: 1, width: 6, height: 4 },
            visualization: { id: "viz.pie" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: "SELECT count(*) FROM ApplicationSubmitted FACET application_type SINCE 24 HOURS AGO"
                }
              ]
            }
          },
          {
            title: "Processing Efficiency Trend",
            layout: { column: 1, row: 5, width: 12, height: 4 },
            visualization: { id: "viz.line" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              legend: { enabled: true },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: "SELECT count(*) FROM ApplicationApproved FACET approval_efficiency SINCE 7 DAYS AGO TIMESERIES AUTO"
                }
              ],
              yAxisLeft: { zero: true }
            }
          }
        ]
      }
    end
    
    def document_management_page
      {
        name: "Document Management",
        description: "Document processing and compliance metrics",
        widgets: [
          {
            title: "Documents Processed Today",
            layout: { column: 1, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.billboard" },
            rawConfiguration: {
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:documents_processed_today]
                }
              ]
            }
          },
          {
            title: "Document Compliance Rate",
            layout: { column: 5, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.billboard" },
            rawConfiguration: {
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:document_compliance_rate]
                }
              ],
              thresholds: [
                { alertSeverity: "CRITICAL", value: 80 },
                { alertSeverity: "WARNING", value: 90 }
              ]
            }
          },
          {
            title: "Average Processing Time",
            layout: { column: 9, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.billboard" },
            rawConfiguration: {
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:document_processing_time]
                }
              ]
            }
          },
          {
            title: "Document Types Processed",
            layout: { column: 1, row: 4, width: 6, height: 4 },
            visualization: { id: "viz.bar" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: "SELECT count(*) FROM DocumentProcessed FACET document_type SINCE 7 DAYS AGO"
                }
              ]
            }
          },
          {
            title: "File Size Distribution",
            layout: { column: 7, row: 4, width: 6, height: 4 },
            visualization: { id: "viz.histogram" },
            rawConfiguration: {
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: "SELECT histogram(file_size_mb, 20, 50) FROM DocumentProcessed SINCE 7 DAYS AGO"
                }
              ]
            }
          }
        ]
      }
    end
    
    def user_engagement_page
      {
        name: "User Engagement",
        description: "User activity and engagement metrics",
        widgets: [
          {
            title: "Active Users Today",
            layout: { column: 1, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.billboard" },
            rawConfiguration: {
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:active_users_today]
                }
              ]
            }
          },
          {
            title: "Average Session Duration",
            layout: { column: 5, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.billboard" },
            rawConfiguration: {
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:average_session_duration]
                }
              ]
            }
          },
          {
            title: "User Engagement Levels",
            layout: { column: 9, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.pie" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:user_engagement_distribution]
                }
              ]
            }
          },
          {
            title: "User Activity by Role",
            layout: { column: 1, row: 4, width: 12, height: 4 },
            visualization: { id: "viz.bar" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: "SELECT count(*) FROM UserSessionActivity FACET user_role SINCE 7 DAYS AGO TIMESERIES AUTO"
                }
              ]
            }
          }
        ]
      }
    end
    
    def system_performance_page
      {
        name: "System Performance",
        description: "Application performance and infrastructure metrics",
        widgets: [
          {
            title: "API Response Times",
            layout: { column: 1, row: 1, width: 8, height: 4 },
            visualization: { id: "viz.line" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              legend: { enabled: true },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:api_response_times]
                }
              ],
              yAxisLeft: { zero: true }
            }
          },
          {
            title: "Performance Tier Distribution",
            layout: { column: 9, row: 1, width: 4, height: 4 },
            visualization: { id: "viz.pie" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: "SELECT count(*) FROM APIPerformance FACET performance_tier SINCE 1 HOUR AGO"
                }
              ]
            }
          },
          {
            title: "Background Job Performance",
            layout: { column: 1, row: 5, width: 6, height: 4 },
            visualization: { id: "viz.bar" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:background_job_performance]
                }
              ]
            }
          },
          {
            title: "Slow Database Queries",
            layout: { column: 7, row: 5, width: 6, height: 4 },
            visualization: { id: "viz.line" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:slow_queries]
                }
              ],
              yAxisLeft: { zero: true }
            }
          }
        ]
      }
    end
    
    def error_monitoring_page
      {
        name: "Error Monitoring",
        description: "Application errors and system health monitoring",
        widgets: [
          {
            title: "Error Rate (24h)",
            layout: { column: 1, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.billboard" },
            rawConfiguration: {
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: "SELECT count(*) FROM ApplicationError SINCE 24 HOURS AGO"
                }
              ],
              thresholds: [
                { alertSeverity: "CRITICAL", value: 100 },
                { alertSeverity: "WARNING", value: 50 }
              ]
            }
          },
          {
            title: "Business Impact Distribution",
            layout: { column: 5, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.pie" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:business_impact_errors]
                }
              ]
            }
          },
          {
            title: "Top Error Classes",
            layout: { column: 9, row: 1, width: 4, height: 3 },
            visualization: { id: "viz.bar" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:error_rate_by_type]
                }
              ]
            }
          },
          {
            title: "Error Trends",
            layout: { column: 1, row: 4, width: 12, height: 4 },
            visualization: { id: "viz.line" },
            rawConfiguration: {
              facet: { showOtherSeries: false },
              legend: { enabled: true },
              nrqlQueries: [
                {
                  accountId: account_id,
                  query: business_metric_queries[:error_trends]
                }
              ],
              yAxisLeft: { zero: true }
            }
          }
        ]
      }
    end
    
    def account_id
      ENV['NEW_RELIC_ACCOUNT_ID'] || 'YOUR_ACCOUNT_ID'
    end
  end
end