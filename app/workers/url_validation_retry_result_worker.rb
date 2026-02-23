class UrlValidationRetryResultWorker
  include Sidekiq::Job

  sidekiq_options queue: :url_validation, retry: 5

  LEASE_DURATION = 2.minutes
  MAX_TIMEOUT_RETRIES = 2

  def perform(result_id)
    @result_id = result_id

    return unless claim_retry_lease

    result = load_result
    return unless result

    payload = UrlValidation::Checker.call(result.job.external_url)
    persist_retry_outcome(payload)
  rescue => e
    release_retry_lease
    log_error(e)
    raise
  end

  private

  attr_reader :result_id

  def claim_retry_lease
    now = Time.current

    claimed_rows = UrlValidationResult
      .where(id: result_id)
      .where(processing_state: UrlValidationResult.processing_states[:completed])
      .where(status: UrlValidationResult.statuses[:timed_out])
      .where(retry_eligible: true)
      .where("timeout_retry_count < ?", MAX_TIMEOUT_RETRIES)
      .where("lease_expires_at IS NULL OR lease_expires_at < ?", now)
      .update_all(
        [
          <<~SQL.squish,
            timeout_retry_count = timeout_retry_count + 1,
            last_retry_at = ?,
            lease_expires_at = ?,
            worker_jid = ?,
            updated_at = ?
          SQL
          now,
          now + LEASE_DURATION,
          jid,
          now
        ]
      )

    claimed_rows.positive?
  end

  def load_result
    UrlValidationResult.includes(:job).find_by(id: result_id)
  end

  def persist_retry_outcome(payload)
    UrlValidationResult.transaction do
      result = UrlValidationResult.lock.includes(:job).find_by(id: result_id)
      return unless result
      return unless retry_lease_owned_by_current_worker?(result)

      previous_status = result.status.to_s

      update_result_row(result, payload)
      update_job_snapshot(result)
      update_run_counters(result, previous_status: previous_status)
    end

    log_success
  end

  def retry_lease_owned_by_current_worker?(result)
    result.worker_jid == jid
  end

  def update_result_row(result, payload)
    now = Time.current
    new_status = payload.fetch(:status).to_s

    result.update!(
      status: payload[:status],
      http_status: payload[:http_status],
      final_url: payload[:final_url],
      error_message: payload[:error_message],
      response_time_ms: payload[:response_time_ms],
      checked_at: payload[:checked_at] || now,
      finished_at: now,
      lease_expires_at: nil,
      worker_jid: nil,
      retry_eligible: retry_eligible_after_retry?(
        new_status: new_status,
        timeout_retry_count: result.timeout_retry_count
      )
    )
  end

  def update_job_snapshot(result)
    result.job.update!(
      last_validation_status: result.status,
      last_http_status: result.http_status,
      last_error: result.error_message,
      last_validated_at: result.checked_at
    )
  end

  def update_run_counters(result, previous_status:)
    deltas = counter_deltas(
      previous_status: previous_status,
      current_status: result.status.to_s
    )

    return if deltas[:valid_count].zero? && deltas[:invalid_count].zero?

    UrlValidationRun.update_counters(
      result.url_validation_run_id,
      valid_count: deltas[:valid_count],
      invalid_count: deltas[:invalid_count]
    )
  end

  def counter_deltas(previous_status:, current_status:)
    previous_valid = valid_status?(previous_status)
    current_valid  = valid_status?(current_status)

    valid_delta =
      if previous_valid == current_valid
        0
      elsif current_valid
        1
      else
        -1
      end

    previous_invalid = !previous_valid
    current_invalid  = !current_valid

    invalid_delta =
      if previous_invalid == current_invalid
        0
      elsif current_invalid
        1
      else
        -1
      end

    { valid_count: valid_delta, invalid_count: invalid_delta }
  end

  def valid_status?(status)
    status == "valid"
  end

  def retry_eligible_after_retry?(new_status:, timeout_retry_count:)
    still_timed_out = (new_status == "timed_out")
    retries_remaining = timeout_retry_count < MAX_TIMEOUT_RETRIES

    still_timed_out && retries_remaining
  end

  def release_retry_lease
    UrlValidationResult
      .where(id: result_id, worker_jid: jid)
      .update_all(
        lease_expires_at: nil,
        worker_jid: nil,
        updated_at: Time.current
      )
  rescue StandardError
    nil
  end

  def log_success
    Rails.logger.info(
      {
        event: "url_validation.retry_timeout_result",
        result_id: result_id,
        jid: jid,
        status: "ok"
      }.to_json
    )
  end

  def log_error(error)
    Rails.logger.error(
      {
        event: "url_validation.retry_timeout_worker_error",
        result_id: result_id,
        jid: jid,
        error_class: error.class.name,
        error_message: error.message
      }.to_json
    )
  end
end
