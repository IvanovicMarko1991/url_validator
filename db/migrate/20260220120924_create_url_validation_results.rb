class CreateUrlValidationResults < ActiveRecord::Migration[8.1]
  def change
    create_table :url_validation_results do |t|
      t.references :url_validation_run, null: false, foreign_key: true
      t.references :job, null: false, foreign_key: true
      t.integer :status, null: false
      t.integer :http_status
      t.text :final_url
      t.text :error_message
      t.integer :response_time_ms
      t.datetime :checked_at, null: false

      t.timestamps
    end

    add_index :url_validation_results, :status
    add_index :url_validation_results, [ :url_validation_run_id, :status ]
  end
end
