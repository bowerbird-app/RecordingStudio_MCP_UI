# frozen_string_literal: true

module Demo
  class ProjectUpdate
    def self.call(attributes, actor:, recording:)
      new(attributes, actor: actor, recording: recording).call
    end

    def initialize(attributes, actor:, recording:)
      @attributes = attributes.to_h.stringify_keys
      @actor = actor
      @recording = recording
    end

    def call
      return failure("unauthorized", {}) unless ProjectAccess.writable?(actor: @actor, recording: @recording)

      project = Project.find(@attributes.fetch("id"))
      if @attributes["revision"].present? && project.revision.to_s != @attributes["revision"].to_s
        return failure("conflict", { revision: "This project changed since the widget opened." })
      end

      unless project.update(permitted)
        return failure("validation_failed", project.errors.to_hash)
      end

      project.update_column(:revision, project.revision + 1)
      project.reload
      success(project)
    end

    private

    def permitted
      @attributes.slice("title", "description", "status")
    end

    def success(project)
      {
        ok: true,
        data: Demo::ProjectPayload.call(project),
        contextUpdate: %(The user updated project #{project.id}. The title is now "#{project.title}".)
      }
    end

    def failure(error, errors)
      { ok: false, error: error, errors: errors }
    end
  end
end
