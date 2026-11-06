# frozen_string_literal: true

module Demo
  module ProjectAccess
    module_function

    def visible?(actor:, recording:)
      authorized?(actor: actor, recording: recording, role: :view)
    end

    def writable?(actor:, recording:)
      authorized?(actor: actor, recording: recording, role: :edit)
    end

    def authorized?(actor:, recording:, role:)
      return false if actor.blank? || recording.blank?

      RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)
    end

    def recording_from_api_context(context)
      grant = context.access_grant
      grant&.scope_recording || grant&.root_recording || context.root_recording
    end

    def actor_from_api_context(context)
      context.access_grant&.actor
    end
  end
end
