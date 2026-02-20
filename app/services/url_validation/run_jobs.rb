module UrlValidation
  class RunJobs
    BATCH_SIZE = 100
    private_constant :BATCH_SIZE

    class << self
      def call(run:, job_ids:)
        new(run:, job_ids:).call
      end
    end

    def initialize(run:, job_ids:)
      @run = run
      @job_ids = Array(job_ids).uniq
      @validation_counts = { valid: 0, invalid: 0 }
    end

    def call
      initialize_validation_run
      process_jobs_in_batches
      complete_validation_run
      @run
    rescue StandardError => e
      handle_validation_failure(e)
      raise
    end

    private

    attr_reader :run, :job_ids, :validation_counts

    def initialize_validation_run
      run.update!(
        status: :running,
        started_at: Time.current,
        total_count: job_ids.size,
        processed_count: 0,
        valid_count: 0,
        invalid_count: 0,
        error_message: nil
      )
    end

    def process_jobs_in_batches
      Job.where(id: job_ids).find_each(batch_size: BATCH_SIZE) do |job|
        process_single_job(job)
      end
    end

    def process_single_job(job)
      validation_result = validate_job_url(job)
      update_job_with_result(job, validation_result)
      track_validation_result(validation_result)
      update_run_counters
    end

    def validate_job_url(job)
      result_data = UrlValidation::Checker.call(job.external_url)
      run.url_validation_results.create!(
        job: job,
        **result_data
      )
    end

    def update_job_with_result(job, result)
      job.update!(
        last_validation_status: result.status,
        last_http_status: result.http_status,
        last_error: result.error_message,
        last_validated_at: result.checked_at
      )
    end

    def track_validation_result(result)
      key = result.valid? ? :valid : :invalid
      validation_counts[key] += 1
    end

    def update_run_counters
      run.update_columns(
        processed_count: run.processed_count + 1,
        valid_count: validation_counts[:valid],
        invalid_count: validation_counts[:invalid]
      )
      run.reload
    end

    def complete_validation_run
      run.update!(
        status: :completed,
        finished_at: Time.current,
        valid_count: validation_counts[:valid],
        invalid_count: validation_counts[:invalid]
      )
    end

    def handle_validation_failure(error)
      run.update!(
        status: :failed,
        error_message: error.message,
        finished_at: Time.current
      )
    end
  end
end
