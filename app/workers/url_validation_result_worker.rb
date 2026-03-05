class UrlValidationResultWorker
  include Sidekiq::Job

  sidekiq_options queue: :url_validation, retry: 8

  LEASE_DURATION = 2.minutes
  REQUEUE_SHORT_DELAY = (1.0..3.0).freeze
  REQUEUE_PAUSED_DELAY = (5.0..10.0).freeze

  sidekiq_retries_exhausted do |msg, ex|
    result_id = msg["args"].first
    UrlValidation::MarkResultAsExhausted.call(result_id: result_id, error_message: ex.message)
  end

  def perform(result_id)
    @result_id = result_id

    return unless claim_lease!

    result = load_result
    return unless result

    run = load_run(result.url_validation_run_id)
    return unless run

    return requeue_if_paused!(run) if run.paused?
    return abandon_if_canceled!(run) if run.canceled?

    acquired = acquire_global_slot
    return requeue_short! unless acquired

    begin
      return requeue_short! unless allow_domain?(result)

      payload = check_url(result)
      complete_result!(payload)
    ensure
      release_global_slot
    end
  rescue => e
    release_lease_best_effort
    log_error(e)
    raise
  end

  private

  attr_reader :result_id

  def claim_lease!
    now = Time.current
    lease_until = now + LEASE_DURATION

    claimed_rows = UrlValidationResult
      .where(id: result_id)
      .where(
        "processing_state = :pending OR (processing_state = :running AND lease_expires_at < :now)",
        pending: UrlValidationResult.processing_states[:pending],
        running: UrlValidationResult.processing_states[:running],
        now: now
      )
      .update_all(
        [
          <<~SQL.squish,
            processing_state = ?,
            attempts_count = attempts_count + 1,
            worker_jid = ?,
            started_at = COALESCE(started_at, ?),
            lease_expires_at = ?,
            updated_at = ?
          SQL
          UrlValidationResult.processing_states[:running],
          jid,
          now,
          lease_until,
          now
        ]
      )

    claimed_rows.positive?
  end

  def release_lease_best_effort
    UrlValidationResult
      .where(id: result_id, worker_jid: jid)
      .update_all(
        worker_jid: nil,
        lease_expires_at: nil,
        processing_state: UrlValidationResult.processing_states[:pending],
        updated_at: Time.current
      )
  rescue StandardError
    nil
  end

  def requeue_pending!(delay_range:)
    now = Time.current

    UrlValidationResult
      .where(id: result_id, worker_jid: jid)
      .update_all(
        worker_jid: nil,
        lease_expires_at: nil,
        processing_state: UrlValidationResult.processing_states[:pending],
        updated_at: now
      )

    self.class.perform_in(rand(delay_range), result_id)
  end

  def requeue_if_paused!(run)
    log_info(event: "url_validation.paused_requeue", run_id: run.id)
    requeue_pending!(delay_range: REQUEUE_PAUSED_DELAY)
  end

  def abandon_if_canceled!(run)
    log_info(event: "url_validation.canceled_skip", run_id: run.id)
    release_lease_best_effort
  end

  def acquire_global_slot
    UrlValidation::GlobalConcurrencyLimiter.acquire!(jid)
  rescue StandardError => e
    log_info(event: "url_validation.global_limiter_error", error: e.message)
    false
  end

  def release_global_slot
    UrlValidation::GlobalConcurrencyLimiter.release!(jid)
  end

  def allow_domain?(result)
    host = result.job.external_host
    allowed = UrlValidation::DomainRateLimiter.allow?(host)

    unless allowed
      log_info(event: "url_validation.domain_throttled", host: host)
    end

    allowed
  rescue StandardError => e
    log_info(event: "url_validation.domain_limiter_error", error: e.message)
    true
  end

  def check_url(result)
    ActiveSupport::Notifications.instrument(
      "url_validation.check",
      run_id: result.url_validation_run_id,
      result_id: result.id,
      job_id: result.job_id,
      url: result.job.external_url,
      host: result.job.external_host
    ) do
      UrlValidation::Checker.call(result.job.external_url, expected_title: result.job.title)
    end
  end

  def complete_result!(payload)
    UrlValidationResult.transaction do
      result = UrlValidationResult.lock.includes(:job).find_by(id: result_id)
      return unless result

      return unless result.worker_jid == jid
      return if result.processing_completed?

      now = Time.current

      result.update!(
        processing_state: :completed,
        status: payload[:status],
        http_status: payload[:http_status],
        final_url: payload[:final_url],
        error_message: payload[:error_message],
        response_time_ms: payload[:response_time_ms],
        checked_at: payload[:checked_at] || now,
        finished_at: now,
        lease_expires_at: nil,
        worker_jid: nil
      )

      result.job.update!(
        last_validation_status: result.status,
        last_http_status: result.http_status,
        last_error: result.error_message,
        last_validated_at: result.checked_at,
        page_title: payload[:page_title],
        title_match: payload[:page_title],
        content_error: payload[:content_error]
      )

      valid_inc = result.status.to_s == "valid" ? 1 : 0
      invalid_inc = valid_inc.zero? ? 1 : 0

      UrlValidationRun.update_counters(
        result.url_validation_run_id,
        processed_count: 1,
        valid_count: valid_inc,
        invalid_count: invalid_inc
      )
    end

    log_info(event: "url_validation.completed")
  end

  def load_result
    UrlValidationResult.includes(:job).find_by(id: result_id)
  end

  def load_run(run_id)
    UrlValidationRun.find_by(id: run_id)
  end

  def requeue_short!
    requeue_pending!(delay_range: REQUEUE_SHORT_DELAY)
  end

  def log_info(event:, **data)
    Rails.logger.info(
      {
        event: event,
        jid: jid,
        result_id: result_id
      }.merge(data).to_json
    )
  end

  def log_error(error)
    Rails.logger.error(
      {
        event: "url_validation.worker_error",
        jid: jid,
        result_id: result_id,
        error_class: error.class.name,
        error_message: error.message
      }.to_json
    )
  end
end
