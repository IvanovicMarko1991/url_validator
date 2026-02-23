module Api
  module V1
    class UrlValidationRunsController < Api::BaseController
      SAMPLE_LIMIT = 25
      private_constant :SAMPLE_LIMIT

      def show
        run = find_run

        render json: build_payload(run)
      end

      def invalids_csv
        run = find_run
        csv_data = UrlValidation::InvalidsCsvExporter.call(run_id: run.id)

        send_data(
          csv_data,
          filename: "url_validation_run_#{run.id}_invalids.csv",
          type: "text/csv"
        )
      end

      private

      def find_run
        UrlValidationRun.find(params[:id])
      end

      def build_payload(run)
        {
          report: run.summary,
          breakdown: build_breakdown(run),
          samples: {
            invalid_jobs: fetch_invalid_samples(run)
          }
        }
      end

      def build_breakdown(run)
        run.url_validation_results.group(:status).count.transform_keys do |k|
          k.nil? ? "pending" : UrlValidationResult.statuses.key(k) || k
        end
      end

      def fetch_invalid_samples(run)
        run.url_validation_results
          .where.not(status: UrlValidationResult.statuses[:valid])
          .where.not(status: nil)
          .includes(job: :company)
          .limit(SAMPLE_LIMIT)
          .map { |r| format_invalid_sample(r) }
      end

      def format_invalid_sample(result)
        {
          job_id: result.job_id,
          job_title: result.job.title,
          company_name: result.job.company.name,
          external_url: result.job.external_url,
          processing_state: result.processing_state,
          status: result.status,
          http_status: result.http_status,
          error_message: result.error_message,
          attempts_count: result.attempts_count
        }
      end

      def invalids_csv
        run = UrlValidationRun.find(params[:id])
        csv_data = UrlValidation::InvalidsCsvExporter.call(run:)

        send_data(
          csv_data,
          filename: "url_validation_run_#{run.id}_invalids.csv",
          type: "text/csv"
        )
      end
    end
  end
end
