require "uri"
require "cgi"

module UrlValidation
  class UrlNormalizer
    STRIP_TRACKING = ENV.fetch("URL_VALIDATOR_STRIP_TRACKING_PARAMS", "true") == "true"
    TRACKING_KEYS = %w[utm_source utm_medium utm_campaign utm_term utm_content gclid fbclid].freeze

    def self.normalize(raw_url)
      raw = raw_url.to_s.strip
      uri = URI.parse(raw)

      raise ArgumentError, "URL must be http or https" unless %w[http https].include?(uri.scheme)
      raise ArgumentError, "URL host missing" if uri.host.blank?

      uri.scheme = uri.scheme.downcase
      uri.host = uri.host.downcase

      # remove fragments
      uri.fragment = nil

      # normalize path
      uri.path = "/" if uri.path.blank?

      # normalize query (optionally remove tracking)
      if uri.query.present?
        params = CGI.parse(uri.query)

        if STRIP_TRACKING
          TRACKING_KEYS.each { |k| params.delete(k) }
        end

        # stable ordering
        query = params.sort.flat_map { |k, vs| vs.sort.map { |v| "#{CGI.escape(k)}=#{CGI.escape(v)}" } }.join("&")
        uri.query = query.presence
      end

      # remove trailing slash (except root)
      if uri.path.length > 1
        uri.path = uri.path.sub(%r{/\z}, "")
      end

      uri.to_s
    rescue URI::InvalidURIError => e
      raise ArgumentError, e.message
    end

    def self.host(normalized_url)
      URI.parse(normalized_url).host
    rescue URI::InvalidURIError
      nil
    end
  end
end
