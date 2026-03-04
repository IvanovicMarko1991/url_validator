class UrlValidationRetryTimedOutWorker
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 5

  CHUNK_SIZE = Integer(ENV.fetch("URL_VALIDATOR_TIMEOUT_RETRY_CHUNK_SIZE", 1000))
  MAX_RETRIES = Integer(ENV.fetch("URL_VALIDATOR_TIMEOUT_RETRY_MAX", 2))

  def perform(run_id)
    run = UrlValidationRun.find_by(id: run_id)
    return unless run&.completed?

    ids = run.url_validation_results
      .where(status: UrlValidationResult.statuses[:timed_out])
      .where(retry_eligible: true)
      .where("timeout_retry_count < ?", MAX_RETRIES)
      .limit(CHUNK_SIZE)
      .pluck(:id)

    return if ids.empty?

    if UrlValidationRetryResultWorker.respond_to?(:perform_bulk)
      UrlValidationRetryResultWorker.perform_bulk(ids.map { |id| [ id ] })
    else
      ids.each { |id| UrlValidationRetryResultWorker.perform_async(id) }
    end

    self.class.perform_in(30.seconds, run.id)
  end
end
