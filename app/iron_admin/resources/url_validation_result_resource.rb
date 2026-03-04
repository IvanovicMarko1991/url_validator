module IronAdmin
  module Resources
    class UrlValidationResultResource < IronAdmin::Resource
      scope :all, -> { all }
      scope :dead_letter, -> { dead_letter }

      filter :status, type: :select, choices: UrlValidationResult.statuses.keys
      filter :processing_state, type: :select, choices: UrlValidationResult.processing_states.keys

      index_fields :id,
                   :url_validation_run_id,
                   :job_id,
                   :processing_state,
                   :status,
                   :http_status,
                   :attempts_count,
                   :timeout_retry_count,
                   :updated_at

      menu group: "Validation", priority: 3
    end
  end
end
