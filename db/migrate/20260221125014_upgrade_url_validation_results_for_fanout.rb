class UpgradeUrlValidationResultsForFanout < ActiveRecord::Migration[8.1]
  disable_ddl_transaction! if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")

  def up
    change_column_null :url_validation_results, :status, true
    change_column_null :url_validation_results, :checked_at, true

    add_column :url_validation_results, :processing_state, :integer unless column_exists?(:url_validation_results, :processing_state)
    add_column :url_validation_results, :attempts_count, :integer unless column_exists?(:url_validation_results, :attempts_count)
    add_column :url_validation_results, :worker_jid, :string unless column_exists?(:url_validation_results, :worker_jid)
    add_column :url_validation_results, :started_at, :datetime unless column_exists?(:url_validation_results, :started_at)
    add_column :url_validation_results, :finished_at, :datetime unless column_exists?(:url_validation_results, :finished_at)
    add_column :url_validation_results, :lease_expires_at, :datetime unless column_exists?(:url_validation_results, :lease_expires_at)

    if column_exists?(:url_validation_results, :processing_state) || column_exists?(:url_validation_results, :attempts_count)
      say_with_time "Backfilling processing_state and attempts_count" do
        execute <<~SQL.squish
          UPDATE url_validation_results
          SET processing_state = COALESCE(processing_state, 0), attempts_count = COALESCE(attempts_count, 0)
          WHERE processing_state IS NULL OR attempts_count IS NULL
        SQL
      end
    end

    if column_exists?(:url_validation_results, :processing_state)
      change_column_default :url_validation_results, :processing_state, from: nil, to: 0
      change_column_null :url_validation_results, :processing_state, false
    end

    if column_exists?(:url_validation_results, :attempts_count)
      change_column_default :url_validation_results, :attempts_count, from: nil, to: 0
      change_column_null :url_validation_results, :attempts_count, false
    end

    if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
      add_index :url_validation_results, [ :url_validation_run_id, :job_id ], unique: true, name: "idx_uvr_run_job_unique", algorithm: :concurrently unless index_exists?(:url_validation_results, name: "idx_uvr_run_job_unique")
      add_index :url_validation_results, [ :url_validation_run_id, :processing_state ], name: "idx_uvr_run_processing", algorithm: :concurrently unless index_exists?(:url_validation_results, name: "idx_uvr_run_processing")
      add_index :url_validation_results, :lease_expires_at, algorithm: :concurrently unless index_exists?(:url_validation_results, :lease_expires_at)
    else
      add_index :url_validation_results, [ :url_validation_run_id, :job_id ], unique: true, name: "idx_uvr_run_job_unique" unless index_exists?(:url_validation_results, name: "idx_uvr_run_job_unique")
      add_index :url_validation_results, [ :url_validation_run_id, :processing_state ], name: "idx_uvr_run_processing" unless index_exists?(:url_validation_results, name: "idx_uvr_run_processing")
      add_index :url_validation_results, :lease_expires_at unless index_exists?(:url_validation_results, :lease_expires_at)
    end
  end

  def down
    remove_index :url_validation_results, name: "idx_uvr_run_job_unique"
    remove_index :url_validation_results, name: "idx_uvr_run_processing"
    remove_index :url_validation_results, column: :lease_expires_at

    change_column_null :url_validation_results, :processing_state, true
    change_column_null :url_validation_results, :attempts_count, true
    change_column_default :url_validation_results, :processing_state, from: 0, to: nil
    change_column_default :url_validation_results, :attempts_count, from: 0, to: nil

    remove_column :url_validation_results, :processing_state
    remove_column :url_validation_results, :attempts_count
    remove_column :url_validation_results, :worker_jid
    remove_column :url_validation_results, :started_at
    remove_column :url_validation_results, :finished_at
    remove_column :url_validation_results, :lease_expires_at

    change_column_null :url_validation_results, :status, false
    change_column_null :url_validation_results, :checked_at, false
  end
end
