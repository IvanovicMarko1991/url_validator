module UrlValidation
  class GlobalConcurrencyLimiter
    KEY = "url_validator:global_inflight"
    LIMIT = Integer(ENV.fetch("URL_VALIDATOR_GLOBAL_INFLIGHT_LIMIT", 50))
    TTL_SECONDS = Integer(ENV.fetch("URL_VALIDATOR_GLOBAL_INFLIGHT_TTL_SECONDS", 120))

    LUA_ACQUIRE = <<~LUA
      local key = KEYS[1]
      local jid = ARGV[1]
      local now = tonumber(ARGV[2])
      local ttl = tonumber(ARGV[3])
      local limit = tonumber(ARGV[4])

      -- drop expired entries
      redis.call("ZREMRANGEBYSCORE", key, "-inf", now - ttl)

      local current = redis.call("ZCARD", key)
      if current >= limit then
        return 0
      end

      redis.call("ZADD", key, now, jid)
      redis.call("EXPIRE", key, ttl * 2)
      return 1
    LUA

    def self.acquire!(jid)
      now = Time.now.to_i
      Sidekiq.redis do |redis|
        redis.eval(LUA_ACQUIRE, keys: [ KEY ], argv: [ jid, now, TTL_SECONDS, LIMIT ]) == 1
      end
    end

    def self.release!(jid)
      Sidekiq.redis { |redis| redis.zrem(KEY, jid) }
    rescue StandardError
      nil
    end
  end
end
