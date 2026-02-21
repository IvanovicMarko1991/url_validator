class UrlValidationRun < ApplicationRecord
  belongs_to :csv_import, optional: true
  has_many :url_validation_results, dependent: :destroy

  enum :status, {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3
  }

  def summary
    total_count = total_count.to_i
    processed_count = processed_count.to_i

    {
      id: id,
      status: status,
      total_count: total_count,
      processed_count: processed_count,
      pending_count: [ total_count - processed_count, 0 ].max,
      valid_count: valid_count,
      invalid_count: invalid_count,
      progress_pct: total_count.zero? ? 0 : ((processed_count.to_f / total_count) * 100).round(1),
      started_at: started_at,
      finished_at: finished_at,
      error_message: error_message
    }
  end
end
