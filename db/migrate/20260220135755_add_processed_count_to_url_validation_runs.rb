class AddProcessedCountToUrlValidationRuns < ActiveRecord::Migration[8.1]
  def change
      add_column :url_validation_runs, :processed_count, :integer, null: false, default: 0
  end
end
