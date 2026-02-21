class UrlValidationResultWorker
  include Sidekiq::Job

  sidekiq_options queue: :url_validation, retry: 8

  LEASE_DURATION = 2.minutes

  sidekiq_retries_exhausted do |msg, ex|
    result_id = msg["args"].first
    UrlValidation::MarkResultAsExhausted.call(result_id:, error_message: ex.message)
  end

  def perform(result_id)
    return unless claim_result(result_id)

    result = fetch_result(result_id)
    payload, duration_ms = perform_check(result)
    complete_result!(result_id: result.id, payload: payload, duration_ms: duration_ms)
  rescue => e
    log_worker_error(result_id, e)
    raise
  end

  private

  def complete_result!(result_id:, payload:, duration_ms:)
    UrlValidationResult.transaction do
      result = UrlValidationResult.lock.includes(:job).find(result_id)

      return if result.processing_completed?

      now = Time.current

      result.update!(
        processing_state: :completed,
        status: payload[:status],
        http_status: payload[:http_status],
        final_url: payload[:final_url],
        error_message: payload[:error_message],
        response_time_ms: payload[:response_time_ms] || duration_ms,
        checked_at: payload[:checked_at] || now,
        finished_at: now,
        lease_expires_at: nil
      )

      result.job.update!(
        last_validation_status: result.status,
        last_http_status: result.http_status,
        last_error: result.error_message,
        last_validated_at: result.checked_at
      )

      valid_inc = result.status == "valid" ? 1 : 0
      invalid_inc = valid_inc.zero? ? 1 : 0

      UrlValidationRun.update_counters(
        result.url_validation_run_id,
        processed_count: 1,
        valid_count: valid_inc,
        invalid_count: invalid_inc
      )
    end
  end

  def claim_result(result_id)
    now = Time.current
    lease_until = now + LEASE_DURATION

    claimed = UrlValidationResult
      .where(id: result_id)
      .where(
        "processing_state = :pending OR (processing_state = :running AND lease_expires_at < :now)",
        pending: UrlValidationResult.processing_states[:pending],
        running: UrlValidationResult.processing_states[:running],
        now: now
      )
      .update_all([
        "processing_state = ?, attempts_count = attempts_count + 1, worker_jid = ?, started_at = COALESCE(started_at, ?), lease_expires_at = ?, updated_at = ?",
        UrlValidationResult.processing_states[:running],
        jid,
        now,
        lease_until,
        now
      ])

    claimed.positive?
  end

  def fetch_result(result_id)
    UrlValidationResult.includes(job: :company).find(result_id)
  end

  def perform_check(result)
    payload = nil
    duration_ms = nil

    ActiveSupport::Notifications.instrument(
      "url_validation.check",
      run_id: result.url_validation_run_id,
      result_id: result.id,
      job_id: result.job_id,
      url: result.job.external_url
    ) do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      payload = UrlValidation::Checker.call(result.job.external_url)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    end

    [ payload, duration_ms ]
  end

  def log_worker_error(result_id, error)
    Rails.logger.error(
      {
        event: "url_validation.worker_error",
        result_id: result_id,
        jid: jid,
        error_class: error.class.name,
        error_message: error.message
      }.to_json
    )
  end
end
