module UrlValidation
  class MarkResultAsExhausted
    def self.call(result_id:, error_message:)
      new(result_id:, error_message:).call
    end

    def initialize(result_id:, error_message:)
      @result_id = result_id
      @error_message = error_message
    end

    def call
      UrlValidationResult.transaction do
        result = find_result
        return unless result
        return if result.processing_completed?

        now = Time.current

        mark_result_exhausted(result, now)
        update_job_from_result(result, now)
        increment_run_counters(result)
      end
    end

    private

    attr_reader :result_id, :error_message

    def find_result
      UrlValidationResult.lock.includes(:job).find_by(id: result_id)
    end

    def mark_result_exhausted(result, now)
      result.update!(
        processing_state: :completed,
        status: :internal_error,
        error_message: error_message,
        checked_at: now,
        finished_at: now,
        lease_expires_at: nil
      )
    end

    def update_job_from_result(result, now)
      result.job.update!(
        last_validation_status: result.status,
        last_http_status: nil,
        last_error: result.error_message,
        last_validated_at: now
      )
    end

    def increment_run_counters(result)
      UrlValidationRun.update_counters(
        result.url_validation_run_id,
        processed_count: 1,
        valid_count: 0,
        invalid_count: 1
      )
    end
  end
end
