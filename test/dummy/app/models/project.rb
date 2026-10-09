class Project < ApplicationRecord
  STATUSES = %w[draft active archived].freeze

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
end
