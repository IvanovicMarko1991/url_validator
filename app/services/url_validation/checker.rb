require "net/http"
require "uri"

module UrlValidation
  class Checker
    MAX_REDIRECTS = Integer(ENV.fetch("URL_VALIDATOR_MAX_REDIRECTS", 5))
    HEAD_FIRST = ENV.fetch("URL_VALIDATOR_HEAD_FIRST", "true") == "true"
    FOLLOW_REDIRECTS = ENV.fetch("URL_VALIDATOR_FOLLOW_REDIRECTS", "false") == "true"

    FALLBACK_TO_GET_HTTP_CODES = [ 403, 405, 501 ].freeze

    def self.call(url)
      new(url).call
    end

    def initialize(url)
      @url = url.to_s.strip
    end

    def call
      started = mono_time
      uri = parse_uri!(@url)

      response, final_uri = perform_request_flow(uri)

      build_result(response:, final_uri:, started:)
    rescue URI::InvalidURIError, ArgumentError => e
      malformed(e)
    rescue Net::OpenTimeout, Net::ReadTimeout
      timed_out
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, OpenSSL::SSL::SSLError => e
      network_error(e)
    end

    private

    def perform_request_flow(uri)
      if HEAD_FIRST
        head = request(uri, Net::HTTP::Head)
        return follow_redirects_if_needed(head, uri) unless fallback_to_get?(head)

        get = request(uri, Net::HTTP::Get)
        return follow_redirects_if_needed(get, uri)
      end

      get = request(uri, Net::HTTP::Get)
      follow_redirects_if_needed(get, uri)
    end

    def follow_redirects_if_needed(response, uri)
      return [ response, uri ] unless response.is_a?(Net::HTTPRedirection)

      return [ response, uri ] unless FOLLOW_REDIRECTS

      current_uri = uri
      current_response = response

      MAX_REDIRECTS.times do
        location = current_response["location"]
        break if location.blank?

        next_uri = resolve_location(current_uri, location)
        current_uri = next_uri

        current_response = request(current_uri, Net::HTTP::Get)
        return [ current_response, current_uri ] unless current_response.is_a?(Net::HTTPRedirection)
      end

      [ current_response, current_uri ]
    end

    def resolve_location(base_uri, location)
      loc = URI.parse(location)
      loc = base_uri + location if loc.relative?
      raise ArgumentError, "Redirect to non-http(s) URL" unless %w[http https].include?(loc.scheme)
      loc
    end

    def fallback_to_get?(response)
      FALLBACK_TO_GET_HTTP_CODES.include?(response.code.to_i)
    end

    def request(uri, request_class)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 3,
        read_timeout: 5
      ) do |http|
        req = request_class.new(uri.request_uri.presence || "/")
        req["User-Agent"] = "RailsUrlValidator/1.0"
        http.request(req)
      end
    end

    def parse_uri!(raw)
      uri = URI.parse(raw)
      raise ArgumentError, "URL must be http or https" unless %w[http https].include?(uri.scheme)
      raise ArgumentError, "URL host missing" if uri.host.blank?
      uri
    end

    def build_result(response:, final_uri:, started:)
      duration_ms = elapsed_ms(started)
      code = response.code.to_i

      if response.is_a?(Net::HTTPSuccess)
        ok(:valid, code, final_uri, nil, duration_ms)
      elsif response.is_a?(Net::HTTPRedirection)
        ok(:redirected, code, response["location"], "Redirected", duration_ms)
      else
        ok(:invalid_http, code, final_uri, "HTTP #{code}", duration_ms)
      end
    end

    def ok(status, http_status, final_uri, error_message, ms)
      {
        status: status,
        http_status: http_status,
        final_url: final_uri.to_s,
        error_message: error_message,
        response_time_ms: ms,
        checked_at: Time.current
      }
    end

    def malformed(e)
      { status: :malformed_url, http_status: nil, final_url: nil, error_message: e.message, response_time_ms: nil, checked_at: Time.current }
    end

    def timed_out
      { status: :timed_out, http_status: nil, final_url: nil, error_message: "Request timed out", response_time_ms: nil, checked_at: Time.current }
    end

    def network_error(e)
      { status: :network_error, http_status: nil, final_url: nil, error_message: e.message, response_time_ms: nil, checked_at: Time.current }
    end

    def mono_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def elapsed_ms(started)
      ((mono_time - started) * 1000).round
    end
  end
end
