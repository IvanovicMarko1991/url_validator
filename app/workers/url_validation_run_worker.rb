class UrlValidationRunWorker
  include Sidekiq::Job

  QUEUE_NAME = :url_validation
  MAX_RETRIES = 5
  private_constant :QUEUE_NAME, :MAX_RETRIES

  sidekiq_options queue: QUEUE_NAME, retry: MAX_RETRIES

  def perform(url_validation_run_id, job_ids)
    run = fetch_validation_run(url_validation_run_id)
    execute_validation(run, job_ids)
  rescue ActiveRecord::RecordNotFound
    handle_run_not_found(url_validation_run_id)
  rescue StandardError => e
    handle_validation_error(url_validation_run_id, e)
    raise
  end

  private

  def fetch_validation_run(url_validation_run_id)
    UrlValidationRun.find(url_validation_run_id)
  end

  def execute_validation(run, job_ids)
    UrlValidation::RunJobs.call(
      run: run,
      job_ids: job_ids
    )
  end

  def handle_run_not_found(url_validation_run_id)
    logger.error(
      "UrlValidationRun with ID #{url_validation_run_id} not found. Skipping URL validation."
    )
  end

  def handle_validation_error(url_validation_run_id, error)
    logger.error(
      "Error processing UrlValidationRun ID #{url_validation_run_id}: #{error.message}"
    )
  end
end
