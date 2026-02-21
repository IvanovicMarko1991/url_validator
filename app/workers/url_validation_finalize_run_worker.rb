class UrlValidationFinalizeRunWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 10

  RESCHEDULE_DELAY = 10.seconds
  UNFINISHED_LIMIT = 5_000
  BULK_BATCH_SIZE = 1_000
  private_constant :RESCHEDULE_DELAY, :UNFINISHED_LIMIT, :BULK_BATCH_SIZE

  def perform(run_id)
    run = find_run(run_id)
    return unless run
    return if run.completed? || run.failed?

    reset_expired_leases(run)

    unfinished_ids = fetch_unfinished_ids(run)

    if unfinished_ids.any?
      enqueue_unfinished(unfinished_ids)
      self.class.perform_in(RESCHEDULE_DELAY, run.id)
      return
    end

    finalize_run(run)
  rescue StandardError => e
    handle_failure(run, e)
    raise
  end

  private

  def find_run(run_id)
    UrlValidationRun.find_by(id: run_id)
  end

  def reset_expired_leases(run)
    expired_scope = run.url_validation_results
                       .where(processing_state: UrlValidationResult.processing_states[:running])
                       .where("lease_expires_at < ?", Time.current)

    expired_scope.update_all(
      processing_state: UrlValidationResult.processing_states[:pending],
      worker_jid: nil,
      lease_expires_at: nil,
      updated_at: Time.current
    )
  end

  def fetch_unfinished_ids(run)
    run.url_validation_results
       .where.not(processing_state: UrlValidationResult.processing_states[:completed])
       .limit(UNFINISHED_LIMIT)
       .pluck(:id)
  end

  def enqueue_unfinished(ids)
    return if ids.empty?

    if UrlValidationResultWorker.respond_to?(:perform_bulk)
      ids.each_slice(BULK_BATCH_SIZE) do |slice|
        UrlValidationResultWorker.perform_bulk(slice.map { |id| [ id ] })
      end
    else
      ids.each { |id| UrlValidationResultWorker.perform_async(id) }
    end
  end

  def finalize_run(run)
    valid_count = run.url_validation_results.where(status: UrlValidationResult.statuses[:valid]).count
    total_count = run.url_validation_results.count
    invalid_count = total_count - valid_count

    run.update!(
      status: :completed,
      total_count: total_count,
      processed_count: total_count,
      valid_count: valid_count,
      invalid_count: invalid_count,
      finished_at: Time.current
    )
  end

  def handle_failure(run, error)
    run&.update!(status: :failed, error_message: error.message, finished_at: Time.current)
    logger.error("UrlValidationFinalizeRunWorker failed for run=#{run&.id}: #{error.message}")
  end
end
