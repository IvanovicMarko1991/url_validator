class AddTimeoutRetryFieldsToUrlValidationResults < ActiveRecord::Migration[8.1]
  def change
    add_column :url_validation_results, :timeout_retry_count, :integer, null: false, default: 0
    add_column :url_validation_results, :last_retry_at, :datetime
    add_column :url_validation_results, :retry_eligible, :boolean, null: false, default: true

    add_index :url_validation_results, [ :url_validation_run_id, :status, :timeout_retry_count ], name: "idx_uvr_timeout_retry"
  end
end
