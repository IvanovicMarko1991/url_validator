module UrlValidation
  class InvalidsCsvExporter
    def self.call(run_id:)
      new(run_id).call
    end

    def initialize(run_id)
      @run_id = run_id
    end

    def call
      CSV.generate(headers: true) do |csv|
        csv << headers

        invalid_results.each do |result|
          csv << [
            result.job_id,
            result.job.title,
            result.job.company.name,
            result.job.external_url,
            result.processing_state,
            result.status,
            result.http_status,
            result.error_message,
            result.attempts_count
          ]
        end
      end
    end

    private

    attr_reader :run_id

    def run
      @run ||= UrlValidationRun.find(run_id)
    end

    def invalid_results
      run.url_validation_results.where.not(status: :valid)
    end

    def headers
      [
        "Job ID",
        "Job Title",
        "Company Name",
        "External URL",
        "Processing State",
        "Status",
        "HTTP Status",
        "Error Message",
        "Attempts Count"
      ]
    end
  end
end
