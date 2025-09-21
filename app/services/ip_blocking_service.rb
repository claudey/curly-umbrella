# frozen_string_literal: true

class IpBlockingService
  include Singleton

  # Cache blocked IPs for fast lookup
  BLOCKED_IPS_KEY = "security:blocked_ips"
  TEMPORARY_BLOCK_KEY = "security:temp_blocked_ips"
  WHITELIST_KEY = "security:ip_whitelist"
  DEFAULT_BLOCK_DURATION = 1.hour

  def self.block_ip(ip_address, reason, duration: DEFAULT_BLOCK_DURATION, permanent: false)
    instance.block_ip(ip_address, reason, duration: duration, permanent: permanent)
  end

  def self.unblock_ip(ip_address, reason = nil)
    instance.unblock_ip(ip_address, reason)
  end

  def self.blocked?(ip_address)
    instance.blocked?(ip_address)
  end

  def self.get_block_info(ip_address)
    instance.get_block_info(ip_address)
  end

  def self.cleanup_expired_blocks
    instance.cleanup_expired_blocks
  end

  def self.list_blocked_ips
    instance.list_blocked_ips
  end

  def block_ip(ip_address, reason, duration: DEFAULT_BLOCK_DURATION, permanent: false)
    return false if ip_address.blank? || local_ip?(ip_address)

    block_data = {
      ip_address: ip_address,
      reason: reason,
      blocked_at: Time.current.to_i,
      blocked_until: permanent ? nil : (Time.current + duration).to_i,
      permanent: permanent,
      blocked_by: "system"
    }

    # Store in cache for fast lookup
    if permanent
      blocked_ips = Rails.cache.fetch(BLOCKED_IPS_KEY, expires_in: nil) { {} }
      blocked_ips[ip_address] = block_data
      Rails.cache.write(BLOCKED_IPS_KEY, blocked_ips, expires_in: nil)
    else
      temp_key = "#{TEMPORARY_BLOCK_KEY}:#{ip_address}"
      Rails.cache.write(temp_key, block_data, expires_in: duration)
    end

    # Log the block action
    Rails.logger.warn "IP #{ip_address} blocked: #{reason}"

    # Create audit log
    AuditLog.log_security_event(
      nil,
      "ip_blocked",
      {
        ip_address: ip_address,
        reason: reason,
        duration: duration,
        permanent: permanent,
        expires_at: permanent ? nil : Time.current + duration
      }
    )

    # Notify security team
    notify_ip_block(ip_address, reason, permanent, duration)

    true
  rescue StandardError => e
    Rails.logger.error "Failed to block IP #{ip_address}: #{e.message}"
    false
  end

  def unblock_ip(ip_address, reason = nil)
    return false if ip_address.blank?

    # Remove from permanent blocks
    blocked_ips = Rails.cache.fetch(BLOCKED_IPS_KEY, expires_in: nil) { {} }
    blocked_ips.delete(ip_address)
    Rails.cache.write(BLOCKED_IPS_KEY, blocked_ips, expires_in: nil)

    # Remove from temporary blocks
    temp_key = "#{TEMPORARY_BLOCK_KEY}:#{ip_address}"
    Rails.cache.delete(temp_key)

    Rails.logger.info "IP #{ip_address} unblocked: #{reason || 'Manual unblock'}"

    # Create audit log
    AuditLog.log_security_event(
      nil,
      "ip_unblocked",
      {
        ip_address: ip_address,
        reason: reason || "Manual unblock",
        unblocked_at: Time.current
      }
    )

    true
  rescue StandardError => e
    Rails.logger.error "Failed to unblock IP #{ip_address}: #{e.message}"
    false
  end

  def blocked?(ip_address)
    return false if ip_address.blank? || local_ip?(ip_address)

    # Check permanent blocks
    blocked_ips = Rails.cache.fetch(BLOCKED_IPS_KEY, expires_in: nil) { {} }
    return true if blocked_ips[ip_address]

    # Check temporary blocks
    temp_key = "#{TEMPORARY_BLOCK_KEY}:#{ip_address}"
    temp_block = Rails.cache.read(temp_key)
    temp_block.present?
  rescue StandardError => e
    Rails.logger.error "Error checking IP block status for #{ip_address}: #{e.message}"
    false
  end

  def get_block_info(ip_address)
    return nil unless blocked?(ip_address)

    # Check permanent blocks first
    blocked_ips = Rails.cache.fetch(BLOCKED_IPS_KEY, expires_in: nil) { {} }
    if blocked_ips[ip_address]
      data = blocked_ips[ip_address]
      return {
        ip_address: ip_address,
        reason: data[:reason],
        blocked_at: Time.at(data[:blocked_at]),
        permanent: true,
        expires_at: nil,
        blocked_by: data[:blocked_by]
      }
    end

    # Check temporary blocks
    temp_key = "#{TEMPORARY_BLOCK_KEY}:#{ip_address}"
    temp_block = Rails.cache.read(temp_key)
    if temp_block
      return {
        ip_address: ip_address,
        reason: temp_block[:reason],
        blocked_at: Time.at(temp_block[:blocked_at]),
        permanent: false,
        expires_at: temp_block[:blocked_until] ? Time.at(temp_block[:blocked_until]) : nil,
        blocked_by: temp_block[:blocked_by]
      }
    end

    nil
  rescue StandardError => e
    Rails.logger.error "Error getting block info for #{ip_address}: #{e.message}"
    nil
  end

  def cleanup_expired_blocks
    expired_count = 0

    # Get all temporary blocks
    temp_blocks = redis.hgetall(TEMPORARY_BLOCK_KEY)
    current_time = Time.current.to_i

    temp_blocks.each do |ip, block_json|
      begin
        block_data = JSON.parse(block_json)
        blocked_until = block_data["blocked_until"]

        if blocked_until && current_time > blocked_until
          redis.hdel(TEMPORARY_BLOCK_KEY, ip)
          expired_count += 1
        end
      rescue JSON::ParserError => e
        Rails.logger.error "Invalid JSON in blocked IP data for #{ip}: #{e.message}"
        redis.hdel(TEMPORARY_BLOCK_KEY, ip)
      end
    end

    Rails.logger.info "Cleaned up #{expired_count} expired IP blocks" if expired_count > 0
    expired_count
  end

  def list_blocked_ips
    blocked_ips = []

    # Get permanent blocks
    permanent_blocks = redis.hgetall(BLOCKED_IPS_KEY)
    permanent_blocks.each do |ip, block_json|
      begin
        data = JSON.parse(block_json)
        blocked_ips << {
          ip_address: ip,
          reason: data["reason"],
          blocked_at: Time.at(data["blocked_at"]),
          permanent: true,
          expires_at: nil
        }
      rescue JSON::ParserError
        next
      end
    end

    # Get temporary blocks
    temp_blocks = redis.hgetall(TEMPORARY_BLOCK_KEY)
    current_time = Time.current.to_i

    temp_blocks.each do |ip, block_json|
      begin
        data = JSON.parse(block_json)
        blocked_until = data["blocked_until"]

        # Skip expired blocks
        next if blocked_until && current_time > blocked_until

        blocked_ips << {
          ip_address: ip,
          reason: data["reason"],
          blocked_at: Time.at(data["blocked_at"]),
          permanent: false,
          expires_at: blocked_until ? Time.at(blocked_until) : nil
        }
      rescue JSON::ParserError
        next
      end
    end

    blocked_ips.sort_by { |block| block[:blocked_at] }.reverse
  end

  # Auto-block based on patterns
  def auto_block_suspicious_ips
    # Get IPs with multiple failed login attempts in the last hour
    suspicious_ips = AuditLog.where(
      action: "login_failure",
      created_at: 1.hour.ago..Time.current
    ).group("details->>'ip_address'")
     .having("COUNT(*) >= ?", 10)
     .count

    blocked_count = 0
    suspicious_ips.each do |ip, attempt_count|
      next if ip.blank? || blocked?(ip) || local_ip?(ip)

      if block_ip(ip, "Auto-blocked: #{attempt_count} failed login attempts", duration: 2.hours)
        blocked_count += 1
      end
    end

    Rails.logger.info "Auto-blocked #{blocked_count} suspicious IPs" if blocked_count > 0
    blocked_count
  end

  # Whitelist management
  def add_to_whitelist(ip_address, reason)
    whitelist_data = {
      ip_address: ip_address,
      reason: reason,
      added_at: Time.current.to_i,
      added_by: "system"
    }

    whitelist = Rails.cache.fetch(WHITELIST_KEY, expires_in: nil) { {} }
    whitelist[ip_address] = whitelist_data
    Rails.cache.write(WHITELIST_KEY, whitelist, expires_in: nil)

    # Also unblock if currently blocked
    unblock_ip(ip_address, "Added to whitelist: #{reason}")

    Rails.logger.info "IP #{ip_address} added to whitelist: #{reason}"
  end

  def whitelisted?(ip_address)
    return false if ip_address.blank?

    whitelist = Rails.cache.fetch(WHITELIST_KEY, expires_in: nil) { {} }
    whitelist.key?(ip_address)
  end

  private

  def local_ip?(ip_address)
    # Don't block local/private IPs
    private_ranges = [
      IPAddr.new("127.0.0.0/8"),    # Loopback
      IPAddr.new("10.0.0.0/8"),     # Private Class A
      IPAddr.new("172.16.0.0/12"),  # Private Class B
      IPAddr.new("192.168.0.0/16"), # Private Class C
      IPAddr.new("::1/128"),        # IPv6 loopback
      IPAddr.new("fc00::/7")        # IPv6 private
    ]

    begin
      ip = IPAddr.new(ip_address)
      private_ranges.any? { |range| range.include?(ip) }
    rescue IPAddr::InvalidAddressError
      false
    end
  end

  def notify_ip_block(ip_address, reason, permanent, duration)
    # In production, this could send to Slack, PagerDuty, etc.
    message = if permanent
                "IP #{ip_address} permanently blocked: #{reason}"
    else
                "IP #{ip_address} temporarily blocked for #{duration}: #{reason}"
    end

    Rails.logger.warn "IP_BLOCK_NOTIFICATION: #{message}"

    # Queue email notification to security team
    SecurityBlockNotificationJob.perform_later(ip_address, reason, permanent, duration)
  end
end
