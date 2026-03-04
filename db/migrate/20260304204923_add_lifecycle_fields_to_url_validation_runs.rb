class AddLifecycleFieldsToUrlValidationRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :url_validation_runs, :paused_at, :datetime
    add_column :url_validation_runs, :canceled_at, :datetime
    add_column :url_validation_runs, :cancel_reason, :text
    add_column :url_validation_runs, :canceled_count, :integer, null: false, default: 0

    add_index :url_validation_runs, :finished_at
    add_index :url_validation_runs, :status
  end
end
