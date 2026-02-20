class UrlValidationRun < ApplicationRecord
  belongs_to :csv_import, optional: true
  has_many :url_validation_results, dependent: :destroy

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }

  def summary
    {
      id: id,
      status: status,
      total_count: total_count,
      valid_count: valid_count,
      invalid_count: invalid_count,
      started_at: started_at,
      finished_at: finished_at
    }
  end
end
