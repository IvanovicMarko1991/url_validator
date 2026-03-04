module UrlValidation
  class RunLifecycle
    def self.pause!(run_id)
      run = UrlValidationRun.find(run_id)
      run.update!(status: :paused, paused_at: Time.current) if run.running?
      run
    end

    def self.resume!(run_id)
      run = UrlValidationRun.find(run_id)
      return run unless run.paused?

      run.update!(status: :running, paused_at: nil)
      UrlValidationFinalizeRunWorker.perform_in(5.seconds, run.id)
      run
    end

    def self.cancel!(run_id, reason: nil)
      run = UrlValidationRun.find(run_id)
      return run if run.completed? || run.failed? || run.canceled?

      now = Time.current

      UrlValidationRun.transaction do
        run.lock!

        unfinished = run.url_validation_results
          .where.not(processing_state: UrlValidationResult.processing_states[:completed])

        canceled_count = unfinished.count

        unfinished.update_all(
          processing_state: UrlValidationResult.processing_states.fetch(:canceled, 3),
          finished_at: now,
          checked_at: nil,
          updated_at: now,
          lease_expires_at: nil,
          worker_jid: nil
        )

        completed_count = run.url_validation_results.where(processing_state: UrlValidationResult.processing_states[:completed]).count

        run.update!(
          status: :canceled,
          canceled_at: now,
          cancel_reason: reason,
          canceled_count: canceled_count,
          processed_count: completed_count + canceled_count,
          finished_at: now
        )
      end

      run
    end
  end
end
