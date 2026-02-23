module Api
  module V1
    class CsvImportsController < Api::BaseController
      def create
        file = csv_file_param

        csv_import = create_csv_import(file)
        import_result = import_jobs(file, csv_import)

        run = create_validation_run(csv_import, import_result)
        queue_prepare_run(run, import_result)

        render json: response_payload(csv_import, run), status: :accepted
      end

      private

      def csv_file_param
        params.require(:file)
      end

      def create_csv_import(file)
        CsvImport.create!(source_file: file.original_filename)
      end

      def import_jobs(file, csv_import)
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

      def queue_prepare_run(run, import_result)
        UrlValidationPrepareRunWorker.perform_async(run.id, import_result.job_ids)
      end

      def response_payload(csv_import, run)
        {
          csv_import: csv_import_data(csv_import),
          validation_run: run.summary,
          message: "Validation queued (fan-out mode)"
        }
      end

      def csv_import_data(csv_import)
        {
          id: csv_import.id,
          source_file: csv_import.source_file,
          total_rows: csv_import.total_rows,
          imported_rows: csv_import.imported_rows,
          failed_rows: csv_import.failed_rows
        }
      end
    end
  end
end
