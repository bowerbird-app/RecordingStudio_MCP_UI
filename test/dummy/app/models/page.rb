class Page < ApplicationRecord
  SORTS = %w[label url].freeze
  DIRECTIONS = %w[asc desc].freeze

  recording_studio_recordable label: "Page", root: false, allowed_parent_types: [ "Workspace", "Folder" ]

  validates :title, presence: true
  validates :sort, inclusion: { in: SORTS }
  validates :direction, inclusion: { in: DIRECTIONS }
end
