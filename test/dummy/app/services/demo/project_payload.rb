# frozen_string_literal: true

module Demo
  class ProjectPayload
    def self.call(project)
      {
        "id" => project.id,
        "title" => project.title,
        "description" => project.description,
        "status" => project.status,
        "revision" => project.revision,
        "url" => "https://example.com/demos/#{project.id}"
      }
    end
  end
end
