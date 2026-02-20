module UrlValidation
  class RunJobs
    BATCH_SIZE = 100
    private_constant :BATCH_SIZE

    class << self
      def call(job_ids:, csv_import: nil)
        new(job_ids:, csv_import:).call
      end
    end

    def initialize(job_ids:, csv_import: nil)
      @job_ids = Array(job_ids).uniq
      @csv_import = csv_import
      @run = nil
      @validation_counts = { valid: 0, invalid: 0 }
    end

    def call
      @run = create_validation_run
      process_jobs_batch
      complete_validation_run
      @run
    rescue StandardError => e
      handle_validation_failure(e)
      raise
    end

    private

    attr_reader :job_ids, :csv_import, :run, :validation_counts

    def create_validation_run
      UrlValidationRun.create!(
        csv_import: csv_import,
        status: :running,
        started_at: Time.current,
        total_count: job_ids.size
      )
    end

    def process_jobs_batch
      Job.where(id: job_ids).find_each(batch_size: BATCH_SIZE) do |job|
        process_job(job)
      end
    end

    def process_job(job)
      result = validate_job_url(job)
      update_job_with_result(job, result)
      track_result_status(result)
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

    def track_result_status(result)
      key = result.valid? ? :valid : :invalid
      validation_counts[key] += 1
    end

    def complete_validation_run
      run.update!(
        status: :completed,
        valid_count: validation_counts[:valid],
        invalid_count: validation_counts[:invalid],
        finished_at: Time.current
      )
    end

    def handle_validation_failure(error)
      run&.update!(
        status: :failed,
        error_message: error.message,
        finished_at: Time.current
      )
    end
  end
end
