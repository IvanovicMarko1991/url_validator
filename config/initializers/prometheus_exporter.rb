# frozen_string_literal: true

return if Rails.env.test?
return unless ENV.fetch("PROMETHEUS_EXPORTER_ENABLED", "true") == "true"

require "prometheus_exporter/middleware"
require "prometheus_exporter/client"
require "prometheus_exporter/instrumentation"

PrometheusExporter::Client.default = PrometheusExporter::Client.new(
  host: ENV.fetch("PROMETHEUS_EXPORTER_HOST", "127.0.0.1"),
  port: Integer(ENV.fetch("PROMETHEUS_EXPORTER_PORT", "9394"))
)

# per-request http/sql/redis timing + counts
Rails.application.middleware.unshift PrometheusExporter::Middleware

# process stats (rss/gc)
PrometheusExporter::Instrumentation::Process.start(type: "web")
