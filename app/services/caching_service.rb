# frozen_string_literal: true

# Comprehensive caching service for BrokerSync
# Handles Redis caching with intelligent fallback to Rails.cache
class CachingService
  # Cache expiration times
  CACHE_EXPIRES = {
    short: 5.minutes,
    medium: 30.minutes,
    long: 4.hours,
    daily: 24.hours,
    weekly: 7.days
  }.freeze

  class << self
    # Fetch data with caching
    def fetch(key, expires_in: :medium, &block)
      cache_key = normalize_key(key)
      expiration = CACHE_EXPIRES[expires_in] || expires_in

      if use_redis?
        fetch_from_redis(cache_key, expiration, &block)
      else
        Rails.cache.fetch(cache_key, expires_in: expiration, &block)
      end
    end

    # Write to cache
    def write(key, value, expires_in: :medium)
      cache_key = normalize_key(key)
      expiration = CACHE_EXPIRES[expires_in] || expires_in

      if use_redis?
        $redis.setex(cache_key, expiration.to_i, serialize_value(value))
      else
        Rails.cache.write(cache_key, value, expires_in: expiration)
      end
    end

    # Read from cache
    def read(key)
      cache_key = normalize_key(key)

      if use_redis?
        value = $redis.get(cache_key)
        value ? deserialize_value(value) : nil
      else
        Rails.cache.read(cache_key)
      end
    end

    # Delete from cache
    def delete(key)
      cache_key = normalize_key(key)

      if use_redis?
        $redis.del(cache_key)
      else
        Rails.cache.delete(cache_key)
      end
    end

    # Delete multiple keys
    def delete_matched(pattern)
      pattern_key = normalize_key(pattern)

      if use_redis?
        keys = $redis.keys(pattern_key)
        $redis.del(*keys) if keys.any?
      else
        Rails.cache.delete_matched(pattern_key)
      end
    end

    # Increment counter
    def increment(key, amount = 1, expires_in: :medium)
      cache_key = normalize_key(key)
      expiration = CACHE_EXPIRES[expires_in] || expires_in

      if use_redis?
        $redis.multi do |multi|
          multi.incrby(cache_key, amount)
          multi.expire(cache_key, expiration.to_i)
        end.first
      else
        current = Rails.cache.read(cache_key) || 0
        new_value = current + amount
        Rails.cache.write(cache_key, new_value, expires_in: expiration)
        new_value
      end
    end

    # Get cache statistics
    def stats
      if use_redis?
        redis_info = $redis.info
        {
          type: "Redis",
          memory_used: redis_info["used_memory_human"],
          keys_count: $redis.dbsize,
          connected_clients: redis_info["connected_clients"],
          uptime: redis_info["uptime_in_seconds"]
        }
      else
        {
          type: "Rails.cache",
          memory_used: "N/A",
          keys_count: "N/A",
          connected_clients: "N/A",
          uptime: "N/A"
        }
      end
    end

    # Clear all cache
    def clear_all
      if use_redis?
        $redis.flushdb
      else
        Rails.cache.clear
      end
    end

    # Cache frequently accessed organization data
    def cache_organization_data(organization)
      return unless organization

      org_key = "org:#{organization.id}"

      # Cache organization basics
      write("#{org_key}:info", {
        id: organization.id,
        name: organization.name,
        subdomain: organization.subdomain,
        active: organization.active?
      }, expires_in: :long)

      # Cache user count
      write("#{org_key}:user_count", organization.users.count, expires_in: :medium)

      # Cache application counts by status
      app_counts = organization.insurance_applications
                              .group(:status)
                              .count
      write("#{org_key}:app_counts", app_counts, expires_in: :short)

      # Cache recent activity
      recent_apps = organization.insurance_applications
                               .includes(:user, :client)
                               .limit(10)
                               .order(created_at: :desc)
                               .pluck(:id, :status, :insurance_type, :created_at)
      write("#{org_key}:recent_activity", recent_apps, expires_in: :short)
    end

    # Cache user session data
    def cache_user_session(user, session_data)
      user_key = "user:#{user.id}:session"
      write(user_key, session_data, expires_in: :medium)
    end

    # Cache security metrics
    def cache_security_metrics(organization_id, metrics)
      security_key = "security:#{organization_id}:metrics"
      write(security_key, metrics, expires_in: :short)
    end

    # Cache quote statistics
    def cache_quote_stats(organization_id, stats)
      quote_key = "quotes:#{organization_id}:stats"
      write(quote_key, stats, expires_in: :medium)
    end

    # Cache document counts
    def cache_document_counts(organization_id, counts)
      doc_key = "documents:#{organization_id}:counts"
      write(doc_key, counts, expires_in: :medium)
    end

    # Get cached organization data
    def get_organization_cache(organization_id)
      org_key = "org:#{organization_id}"
      {
        info: read("#{org_key}:info"),
        user_count: read("#{org_key}:user_count"),
        app_counts: read("#{org_key}:app_counts"),
        recent_activity: read("#{org_key}:recent_activity")
      }
    end

    # Invalidate organization cache
    def invalidate_organization_cache(organization_id)
      delete_matched("org:#{organization_id}:*")
    end

    # Invalidate user cache
    def invalidate_user_cache(user_id)
      delete_matched("user:#{user_id}:*")
    end

    private

    def use_redis?
      $redis&.connected?
    rescue
      false
    end

    def normalize_key(key)
      # Add namespace and ensure string
      "brokersync:#{key}".gsub(/\s+/, "_")
    end

    def fetch_from_redis(key, expiration, &block)
      value = $redis.get(key)

      if value
        deserialize_value(value)
      else
        result = yield
        $redis.setex(key, expiration.to_i, serialize_value(result))
        result
      end
    end

    def serialize_value(value)
      # Use JSON for simple serialization
      JSON.generate(value)
    rescue JSON::GeneratorError
      # Fallback for complex objects
      Marshal.dump(value)
    end

    def deserialize_value(value)
      # Try JSON first
      JSON.parse(value)
    rescue JSON::ParserError
      # Fallback to Marshal
      Marshal.load(value)
    rescue => e
      Rails.logger.warn "Cache deserialization failed: #{e.message}"
      nil
    end
  end
end
