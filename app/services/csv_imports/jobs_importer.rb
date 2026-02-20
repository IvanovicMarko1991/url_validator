require "csv"
require "set"

module CsvImports
  class JobsImporter
    Result = Struct.new(:job_ids, :total_rows, :imported_rows, :failed_rows, keyword_init: true)

    EXPECTED_HEADERS = %w[company_name title external_url external_id].freeze

    class << self
      def call(file:, csv_import:)
        new(file:, csv_import:).call
      end
    end

    def initialize(file:, csv_import:)
      @file = file
      @csv_import = csv_import
    end

    def call
      start_import
      job_ids, total_rows, imported_rows, failed_rows = process_csv
      finish_import(total_rows, imported_rows, failed_rows)

      Result.new(
        job_ids: job_ids.to_a,
        total_rows: total_rows,
        imported_rows: imported_rows,
        failed_rows: failed_rows
      )
    rescue StandardError => e
      handle_import_failure(e)
      raise
    end

    private

    attr_reader :file, :csv_import

    def start_import
      csv_import.update!(status: :running, started_at: Time.current)
    end

    def process_csv
      job_ids = Set.new
      total_rows = 0
      imported_rows = 0
      failed_rows = 0

      CSV.foreach(file.path, headers: true, encoding: "bom|utf-8") do |row|
        total_rows += 1
        process_row(row, job_ids, imported_rows, failed_rows)
      end

      [ job_ids, total_rows, imported_rows, failed_rows ]
    end

    def process_row(row, job_ids, imported_rows, failed_rows)
      company_name = extract_field(row, "company_name")
      title = extract_field(row, "title")
      external_url = extract_field(row, "external_url")
      external_id = row["external_id"]&.strip.presence

      validate_required_fields(company_name, title, external_url)

      company = find_or_create_company(company_name)
      job = find_or_initialize_job(company, external_url, external_id)

      update_job_attributes(job, title, external_url, external_id)
      job.save!

      job_ids << job.id
      imported_rows += 1
    rescue StandardError => e
      failed_rows += 1
      log_row_error(e)
    end

    def extract_field(row, field_name)
      row[field_name]&.strip
    end

    def validate_required_fields(company_name, title, external_url)
      raise ArgumentError, "company_name missing" if company_name.blank?
      raise ArgumentError, "title missing" if title.blank?
      raise ArgumentError, "external_url missing" if external_url.blank?
    end

    def find_or_create_company(company_name)
      Company.find_or_create_by!(name: company_name)
    end

    def find_or_initialize_job(company, external_url, external_id)
      if external_id.present?
        Job.find_or_initialize_by(company: company, external_id: external_id)
      else
        Job.find_or_initialize_by(company: company, external_url: external_url)
      end
    end

    def update_job_attributes(job, title, external_url, external_id)
      job.title = title
      job.external_url = external_url
      job.external_id = external_id if external_id.present?
    end

    def log_row_error(error)
      Rails.logger.warn("CSV row processing failed: #{error.message}")
    end

    def finish_import(total_rows, imported_rows, failed_rows)
      csv_import.update!(
        status: :completed,
        total_rows: total_rows,
        imported_rows: imported_rows,
        failed_rows: failed_rows,
        finished_at: Time.current
      )
    end

    def handle_import_failure(error)
      csv_import.update!(
        status: :failed,
        error_message: error.message,
        finished_at: Time.current
      )
    end
  end
end
