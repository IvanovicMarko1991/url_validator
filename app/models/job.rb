class Job < ApplicationRecord
  belongs_to :company
  has_many :url_validation_runs, dependent: :destroy

  enum :last_validation_status, {
    unknown: 0,
    valid: 1,
    invalid_http: 2,
    redirected: 3,
    malformed_url: 4,
    timed_out: 5,
    network_error: 6
  }, prefix: :last

  validates :title, presence: true
  validates :external_url, presence: true
end
