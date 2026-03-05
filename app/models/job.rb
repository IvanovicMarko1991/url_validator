class Job < ApplicationRecord
  belongs_to :company
  has_many :url_validation_results, dependent: :destroy

  enum :last_validation_status, {
    unknown: 0,
    valid: 1,
    invalid_http: 2,
    redirected: 3,
    malformed_url: 4,
    timed_out: 5,
    network_error: 6,
    internal_error: 7
  }, prefix: :last

  before_validation :normalize_external_url_fields

  validates :title, presence: true
  validates :external_url, presence: true
  validates :normalized_external_url, presence: true

  validates :external_id, uniqueness: { scope: :company_id, allow_nil: true }

  validates :normalized_external_url,
            uniqueness: { scope: :company_id },
            if: -> { external_id.blank? }

  private

  def normalize_external_url_fields
    return if external_url.blank?

    normalized = UrlValidation::UrlNormalizer.normalize(external_url)
    self.normalized_external_url = normalized
    self.external_host = UrlValidation::UrlNormalizer.host(normalized)
  rescue ArgumentError => e
    errors.add(:external_url, e.message)
  end
end
