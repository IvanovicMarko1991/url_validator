ActiveSupport::Notifications.subscribe("url_validation.check") do |name, start, finish, id, payload|
  duration_ms = ((finish - start) * 1000).round

  Rails.logger.info(
    {
      event: name,
      duration_ms: duration_ms,
      run_id: payload[:run_id],
      result_id: payload[:result_id],
      job_id: payload[:job_id],
      url: payload[:url]
    }.to_json
  )
end
