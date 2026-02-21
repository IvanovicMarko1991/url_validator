class UrlValidationResult < ApplicationRecord
  belongs_to :url_validation_run
  belongs_to :job

  enum :processing_state, {
    pending: 0,
    running: 1,
    completed: 2
  }, prefix: :processing

  enum :status, {
    valid: 1,
    invalid_http: 2,
    redirected: 3,
    malformed_url: 4,
    timed_out: 5,
    network_error: 6,
    internal_error: 7
  }, prefix: :outcome

  validates :checked_at, presence: true, if: :processing_completed?
  validates :status, presence: true, if: :processing_completed?

  scope :unfinished, -> { where.not(processing_state: processing_states[:completed]) }
  scope :lease_expired, -> { where("lease_expires_at IS NOT NULL AND lease_expires_at < ?", Time.current) }
end
