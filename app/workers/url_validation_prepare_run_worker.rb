class UrlValidationPrepareRunWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(run_id, job_ids)
    run = find_run(run_id)
    job_ids = normalize_job_ids(job_ids)

    initialize_run(run, job_ids)
    result_ids = insert_results_for(run, job_ids)
    schedule_workers_for(result_ids)
    schedule_finalize_run(run)
  rescue StandardError => e
    handle_failure(run, e)
    raise
  end

  private

  BATCH_SIZE = 1_000
  private_constant :BATCH_SIZE

  attr_reader :run

  def find_run(run_id)
    UrlValidationRun.find(run_id)
  end

  def normalize_job_ids(job_ids)
    Array(job_ids).map(&:to_i).uniq
  end

  def initialize_run(run, job_ids)
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

  def insert_results_for(run, job_ids)
    return [] if job_ids.empty?

    now = Time.current
    rows = job_ids.map do |job_id|
      {
        url_validation_run_id: run.id,
        job_id: job_id,
        processing_state: UrlValidationResult.processing_states[:pending],
        attempts_count: 0,
        created_at: now,
        updated_at: now
      }
    end

    UrlValidationResult.insert_all(rows, unique_by: :idx_uvr_run_job_unique) if rows.any?

    UrlValidationResult.where(url_validation_run_id: run.id, job_id: job_ids).pluck(:id)
  end

  def schedule_workers_for(result_ids)
    enqueue_result_workers(result_ids)
  end

  def schedule_finalize_run(run)
    UrlValidationFinalizeRunWorker.perform_in(10.seconds, run.id)
  end

  def handle_failure(run_obj, error)
    run_obj&.update!(status: :failed, error_message: error.message, finished_at: Time.current)
    logger.error("UrlValidationPrepareRunWorker failed for run=#{run_obj&.id}: #{error.message}")
  end

  def enqueue_result_workers(result_ids)
    return if result_ids.empty?

    if UrlValidationResultWorker.respond_to?(:perform_bulk)
      result_ids.each_slice(BATCH_SIZE) do |slice|
        UrlValidationResultWorker.perform_bulk(slice.map { |id| [ id ] })
      end
    else
      result_ids.each do |id|
        UrlValidationResultWorker.perform_async(id)
      end
    end
  end
end
