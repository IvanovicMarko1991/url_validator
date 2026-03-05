Sidekiq.configure_server do |config|
  config.on :startup do
    require "prometheus_exporter/client"
    require "prometheus_exporter/instrumentation"

    PrometheusExporter::Client.default = PrometheusExporter::Client.new(
      host: ENV.fetch("PROMETHEUS_EXPORTER_HOST", "127.0.0.1"),
      port: Integer(ENV.fetch("PROMETHEUS_EXPORTER_PORT", "9394"))
    )

    PrometheusExporter::Instrumentation::Process.start(type: "sidekiq")
    PrometheusExporter::Instrumentation::ActiveRecord.start(custom_labels: { type: "sidekiq" })

    PrometheusExporter::Instrumentation::Sidekiq.start
    config.death_handlers << PrometheusExporter::Instrumentation::Sidekiq.death_handler

    PrometheusExporter::Instrumentation::SidekiqProcess.start
    PrometheusExporter::Instrumentation::SidekiqQueue.start(all_queues: true)
    PrometheusExporter::Instrumentation::SidekiqStats.start
  end

  at_exit do
    PrometheusExporter::Client.default.stop(wait_timeout_seconds: 10)
  end
end
