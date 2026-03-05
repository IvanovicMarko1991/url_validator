# frozen_string_literal: true

endpoint = ENV["OTEL_EXPORTER_OTLP_ENDPOINT"]
return if endpoint.blank?

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "url-validator")
  c.use_all
end
