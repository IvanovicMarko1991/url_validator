class EnforceNotNullConstraintsOnCoreTables < ActiveRecord::Migration[8.1]
  def change
    change_column_null :jobs, :title, false
    change_column_null :jobs, :external_url, false
    change_column_null :jobs, :company_id, false

    change_column_null :csv_imports, :source_file, false

    change_column_null :url_validation_runs, :status, false
    change_column_null :url_validation_runs, :total_count, false
    change_column_null :url_validation_runs, :processed_count, false
    change_column_null :url_validation_runs, :valid_count, false
    change_column_null :url_validation_runs, :invalid_count, false

    change_column_null :url_validation_results, :url_validation_run_id, false
    change_column_null :url_validation_results, :job_id, false
  end
end
