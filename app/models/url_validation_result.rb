class UrlValidationResult < ApplicationRecord
  belongs_to :url_validation_run
  belongs_to :job

  enum :status, {
    valid: 1,
    invalid_http: 2,
    redirected: 3,
    malformed_url: 4,
    timed_out: 5,
    network_error: 6
  }, prefix: :status

  validates :checked_at, presence: true
end
