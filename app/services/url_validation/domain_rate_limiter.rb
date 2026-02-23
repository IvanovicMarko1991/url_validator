module UrlValidation
  class DomainRateLimiter
    WINDOW_SECONDS = 1
    MAX_PER_WINDOW = 3

    def self.allow?(host)
      return true if host.blank?

      redis = Sidekiq.redis_pool.with(&:itself)
      key = "url_validator:domain_rate:#{host}:#{Time.now.to_i}"

      count = nil
      redis.with do |conn|
        count = conn.incr(key)
        conn.expire(key, WINDOW_SECONDS + 1)
      end

      count <= MAX_PER_WINDOW
    end
  end
end
