class CsvImportsController < ApplicationController
  def create
    file = extract_file_from_params
    csv_import = create_csv_import(file)
    import_result = import_jobs_from_csv(file, csv_import)
    validation_run = start_url_validation(import_result, csv_import)

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

  def start_url_validation(import_result, csv_import)
    UrlValidation::RunJobs.call(
      job_ids: import_result.job_ids,
      csv_import: csv_import
    )
  end

  def render_success_response(csv_import, validation_run)
    render json: build_response_payload(csv_import, validation_run), status: :created
  end

  def build_response_payload(csv_import, validation_run)
    {
      csv_import: build_csv_import_data(csv_import),
      validation_report: validation_run.summary
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
