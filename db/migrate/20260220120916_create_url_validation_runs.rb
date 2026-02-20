class CreateUrlValidationRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :url_validation_runs do |t|
      t.references :csv_import, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :total_count, null: false, default: 0
      t.integer :valid_count, null: false, default: 0
      t.integer :invalid_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message

      t.timestamps
    end
  end
end
