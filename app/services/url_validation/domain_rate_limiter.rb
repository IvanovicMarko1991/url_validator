module UrlValidation
  class DomainRateLimiter
    WINDOW_SECONDS = Integer(ENV.fetch("URL_VALIDATOR_DOMAIN_WINDOW_SECONDS", 1))
    MAX_PER_WINDOW = Integer(ENV.fetch("URL_VALIDATOR_DOMAIN_MAX_PER_WINDOW", 3))

    def self.allow?(host)
      return true if host.blank?

      window = Time.now.to_i / WINDOW_SECONDS
      key = "url_validator:domain_rate:#{host}:#{window}"

      count = nil
      Sidekiq.redis do |redis|
        count = redis.incr(key)
        redis.expire(key, WINDOW_SECONDS + 1)
      end

      count <= MAX_PER_WINDOW
    end
  end
end
