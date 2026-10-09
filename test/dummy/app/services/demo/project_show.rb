# frozen_string_literal: true

module Demo
  class ProjectShow
    def self.call(context)
      project = Project.find(ProjectArguments.fetch(context, "id"))
      { json: ProjectPayload.call(project) }
    end
  end
end
