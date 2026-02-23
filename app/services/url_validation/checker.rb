require "net/http"
require "uri"

module UrlValidation
  class Checker
    SUPPORTED_SCHEMES = %w[http https].freeze
    DEFAULT_USER_AGENT = "RailsUrlValidator/1.0".freeze
    REQUEST_TIMEOUT_OPEN = 3
    REQUEST_TIMEOUT_READ = 5
    HEAD_REQUEST_FALLBACK_STATUSES = [ 405, 403, 501 ].freeze

    class << self
      def call(url)
        new(url).call
      end
    end

    def initialize(url)
      @url = url.to_s.strip
      @checked_at = Time.current
    end

    def call
      started = start_timer
      uri = parse_uri!
      response = perform_request(uri)
      duration_ms = calculate_elapsed_ms(started)

      classify_response(response, uri, duration_ms)
    rescue URI::InvalidURIError, ArgumentError => e
      build_malformed_url_result(e)
    rescue Net::OpenTimeout, Net::ReadTimeout
      build_timeout_result
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, OpenSSL::SSL::SSLError => e
      build_network_error_result(e)
    end

    private

    attr_reader :url, :checked_at

    def start_timer
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def parse_uri!
      uri = URI.parse(url)
      validate_uri_scheme(uri)
      validate_uri_host(uri)
      uri
    end

    def validate_uri_scheme(uri)
      return if SUPPORTED_SCHEMES.include?(uri.scheme)
      raise ArgumentError, "URL must be http or https"
    end

    def validate_uri_host(uri)
      raise ArgumentError, "URL host missing" if uri.host.blank?
    end

    def perform_request(uri)
      use_head_first = Rails.application.config.x.url_validator.head_first

      if use_head_first
        response = perform_head_request(uri)
        # Fallback to GET if HEAD returns specific error statuses or raises timeout
        response = perform_get_request(uri) if should_fallback_to_get?(response)
        response
      else
        perform_get_request(uri)
      end
    end

    def perform_head_request(uri)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: REQUEST_TIMEOUT_OPEN,
        read_timeout: REQUEST_TIMEOUT_READ
      ) do |http|
        request = Net::HTTP::Head.new(uri.request_uri.presence || "/")
        request["User-Agent"] = DEFAULT_USER_AGENT
        http.request(request)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, OpenSSL::SSL::SSLError
      # On timeout or network error, fallback to GET
      nil
    end

    def perform_get_request(uri)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: REQUEST_TIMEOUT_OPEN,
        read_timeout: REQUEST_TIMEOUT_READ
      ) do |http|
        request = build_http_request(uri)
        http.request(request)
      end
    end

    def should_fallback_to_get?(response)
      return false if response.nil?
      return true if HEAD_REQUEST_FALLBACK_STATUSES.include?(response.code.to_i)
      false
    end

    def build_http_request(uri)
      path = uri.request_uri.presence || "/"
      request = Net::HTTP::Get.new(path)
      request["User-Agent"] = DEFAULT_USER_AGENT
      request
    end

    def calculate_elapsed_ms(started)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      (elapsed * 1000).round
    end

    def classify_response(response, uri, duration_ms)
      case response
      when Net::HTTPSuccess
        build_valid_result(response, uri, duration_ms)
      when Net::HTTPRedirection
        build_redirect_result(response, uri, duration_ms)
      else
        build_invalid_http_result(response, uri, duration_ms)
      end
    end

    def build_valid_result(response, uri, duration_ms)
      {
        status: :valid,
        http_status: response.code.to_i,
        final_url: uri.to_s,
        error_message: nil,
        response_time_ms: duration_ms,
        checked_at: checked_at
      }
    end

    def build_redirect_result(response, uri, duration_ms)
      {
        status: :redirected,
        http_status: response.code.to_i,
        final_url: response["location"],
        error_message: "Redirected",
        response_time_ms: duration_ms,
        checked_at: checked_at
      }
    end

    def build_invalid_http_result(response, uri, duration_ms)
      {
        status: :invalid_http,
        http_status: response.code.to_i,
        final_url: uri.to_s,
        error_message: "HTTP #{response.code}",
        response_time_ms: duration_ms,
        checked_at: checked_at
      }
    end

    def build_malformed_url_result(error)
      build_error_result(:malformed_url, error.message)
    end

    def build_timeout_result
      build_error_result(:timed_out, "Request timed out")
    end

    def build_network_error_result(error)
      build_error_result(:network_error, error.message)
    end

    def build_error_result(status, error_message)
      {
        status: status,
        http_status: nil,
        final_url: nil,
        error_message: error_message,
        response_time_ms: nil,
        checked_at: checked_at
      }
    end
  end
end
