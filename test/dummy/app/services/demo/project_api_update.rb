# frozen_string_literal: true

module Demo
  class ProjectApiUpdate
    def self.call(context)
      attributes = ProjectArguments.slice(context, :id, :title, :description, :status, :revision)
      ProjectUpdate.call(
        attributes,
        actor: ProjectAccess.actor_from_api_context(context),
        recording: ProjectAccess.recording_from_api_context(context)
      )
    end
  end
end
