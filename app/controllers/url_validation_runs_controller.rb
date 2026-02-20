class UrlValidationRunsController < ApplicationController
  INVALID_JOBS_LIMIT = 50
  private_constant :INVALID_JOBS_LIMIT

  def show
    run = find_validation_run
    invalid_jobs = fetch_invalid_jobs(run)

    render_validation_report(run, invalid_jobs)
  end

  private

  def find_validation_run
    UrlValidationRun.find(params[:id])
  end

  def fetch_invalid_jobs(run)
    run.url_validation_results
       .where.not(status: UrlValidationResult.statuses[:valid])
       .includes(:job)
       .limit(INVALID_JOBS_LIMIT)
  end

  def render_validation_report(run, invalid_jobs)
    render json: build_report_payload(run, invalid_jobs)
  end

  def build_report_payload(run, invalid_jobs)
    {
      report: run.summary,
      invalid_jobs: format_invalid_jobs(invalid_jobs)
    }
  end

  def format_invalid_jobs(invalid_jobs)
    invalid_jobs.map { |result| format_invalid_job(result) }
  end

  def format_invalid_job(result)
    {
      job_id: result.job_id,
      job_title: result.job.title,
      company_name: result.job.company.name,
      external_url: result.job.external_url,
      status: result.status,
      http_status: result.http_status,
      error_message: result.error_message
    }
  end
end
