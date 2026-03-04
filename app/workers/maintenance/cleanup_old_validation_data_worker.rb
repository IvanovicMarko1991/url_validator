module Maintenance
  class CleanupOldValidationDataWorker
    include Sidekiq::Job
    sidekiq_options queue: :maintenance, retry: 3

    def perform(retention_days: Integer(ENV.fetch("URL_VALIDATOR_RETENTION_DAYS", 30)))
      cutoff = Time.current - retention_days.days

      UrlValidationRun
        .where("finished_at IS NOT NULL AND finished_at < ?", cutoff)
        .where(status: [ UrlValidationRun.statuses[:completed], UrlValidationRun.statuses[:failed], UrlValidationRun.statuses[:canceled] ])
        .in_batches(of: 500) do |batch|
        run_ids = batch.pluck(:id)
        UrlValidationResult.where(url_validation_run_id: run_ids).delete_all
        UrlValidationRun.where(id: run_ids).delete_all
      end
    end
  end
end
