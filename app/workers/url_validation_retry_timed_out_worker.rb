class UrlValidationRetryTimedOutWorker
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 5

  MAX_TIMEOUT_RETRIES = 2
  CHUNK_SIZE = 1000
  RESCHEDULE_DELAY = 30.seconds
  private_constant :RESCHEDULE_DELAY

  def perform(run_id)
    run = find_run(run_id)
    return unless run&.completed?

    timed_out_ids = fetch_timed_out_results(run)
    return if timed_out_ids.empty?

    enqueue_retry_workers(timed_out_ids)
    reschedule_worker(run.id)
  rescue StandardError => e
    logger.error("UrlValidationRetryTimedOutWorker failed for run=#{run_id}: #{e.message}")
    raise
  end

  private

  def find_run(run_id)
    UrlValidationRun.find_by(id: run_id)
  end

  def fetch_timed_out_results(run)
    run.url_validation_results
       .where(status: UrlValidationResult.statuses[:timed_out])
       .where("timeout_retry_count < ?", MAX_TIMEOUT_RETRIES)
       .where(retry_eligible: true)
       .limit(CHUNK_SIZE)
       .pluck(:id)
  end

  def enqueue_retry_workers(ids)
    return if ids.empty?

    if UrlValidationRetryResultWorker.respond_to?(:perform_bulk)
      UrlValidationRetryResultWorker.perform_bulk(ids.map { |id| [ id ] })
    else
      ids.each { |id| UrlValidationRetryResultWorker.perform_async(id) }
    end
  end

  def reschedule_worker(run_id)
    self.class.perform_in(RESCHEDULE_DELAY, run_id)
  end
end
