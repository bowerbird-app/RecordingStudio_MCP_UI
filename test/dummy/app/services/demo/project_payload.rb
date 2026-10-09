# frozen_string_literal: true

module Demo
  class ProjectPayload
    def self.call(project)
      {
        "id" => project.id,
        "title" => project.title,
        "description" => project.description,
        "status" => project.status,
        "revision" => project.revision
      }
    end
  end
end
