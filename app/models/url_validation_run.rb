class UrlValidationRun < ApplicationRecord
  belongs_to :csv_import, optional: true
  has_many :url_validation_results, dependent: :destroy

  enum :status, {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3,
    paused: 4,
    canceled: 5
  }

  def summary
    total = total_count.to_i
    processed = processed_count.to_i
    {
      id: id,
      status: status,
      total_count: total,
      processed_count: processed,
      valid_count: valid_count,
      invalid_count: invalid_count,
      canceled_count: canceled_count,
      progress_pct: total.zero? ? 0 : ((processed.to_f / total) * 100).round(1),
      started_at: started_at,
      finished_at: finished_at,
      paused_at: paused_at,
      canceled_at: canceled_at,
      cancel_reason: cancel_reason,
      error_message: error_message
    }
  end
end
