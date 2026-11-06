# frozen_string_literal: true

module Demo
  class ProjectShow
    def self.call(context)
      recording = ProjectAccess.recording_from_api_context(context)
      actor = ProjectAccess.actor_from_api_context(context)
      raise ActiveRecord::RecordNotFound unless ProjectAccess.visible?(actor: actor, recording: recording)

      project = Project.find(ProjectArguments.fetch(context, "id"))
      ProjectPayload.call(project)
    end
  end
end
