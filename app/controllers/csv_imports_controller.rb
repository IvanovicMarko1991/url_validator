class CsvImportsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    file = extract_file_from_params
    csv_import = create_csv_import(file)
    import_result = import_jobs_from_csv(file, csv_import)
    validation_run = create_validation_run(csv_import, import_result)
    queue_background_validation(validation_run, import_result)

    render_success_response(csv_import, validation_run)
  end

  private

  def extract_file_from_params
    params.require(:file)
  end

  def create_csv_import(file)
    CsvImport.create!(source_file: file.original_filename)
  end

  def import_jobs_from_csv(file, csv_import)
    CsvImports::JobsImporter.call(file: file, csv_import: csv_import)
  end

  def create_validation_run(csv_import, import_result)
    UrlValidationRun.create!(
      csv_import: csv_import,
      status: :pending,
      total_count: import_result.job_ids.size,
      processed_count: 0,
      valid_count: 0,
      invalid_count: 0
    )
  end

  def queue_background_validation(validation_run, import_result)
    UrlValidationRunWorker.perform_async(validation_run.id, import_result.job_ids)
  end

  def render_success_response(csv_import, validation_run)
    render json: build_response_payload(csv_import, validation_run), status: :accepted
  end

  def build_response_payload(csv_import, validation_run)
    {
      csv_import: build_csv_import_data(csv_import),
      validation_run: validation_run.summary,
      message: "Validation has been queued in background"
    }
  end

  def build_csv_import_data(csv_import)
    {
      id: csv_import.id,
      source_file: csv_import.source_file,
      total_rows: csv_import.total_rows,
      imported_rows: csv_import.imported_rows,
      failed_rows: csv_import.failed_rows
    }
  end
end
