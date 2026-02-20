class CsvImport < ApplicationRecord
  has_many :url_validation_runs, dependent: :nullify

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }

  validates :source_file, presence: true
end
