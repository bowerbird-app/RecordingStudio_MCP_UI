# frozen_string_literal: true

RecordingStudio.configure do |config|
  # Registered delegated_type recordables (strings or classes)
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "AdminRoot",
    "RecordingStudioSiteSettings::SiteSetting",
    "RecordingStudioAttachable::Attachment",
    "RecordingStudioUser::People",
    "RecordingStudioUser::Profile"
  ]

  # Require each configured ActiveRecord type to call recording_studio_recordable.
  config.require_recordable_declarations = true

  # Shown in the shared default layout title fallback.
  config.app_name = "MCP UI Dummy" if config.respond_to?(:app_name=)

  # Actor resolver for events when no actor is explicitly supplied
  config.actor = -> { Current.actor }

  # Core 6.5 writes fail closed. Accessible :edit on the target, except while
  # Accessible is writing the first grant (AccessCreationContext).
  config.authorize_write = lambda do |actor:, recording:, parent_recording:, root_recording:, **|
    next false if actor.blank?
    next true if RecordingStudioAccessible::AccessCreationContext.allowed?

    target = recording || parent_recording || root_recording
    next false if target.blank?

    RecordingStudioAccessible.authorized?(actor: actor, recording: target, role: :edit)
  end

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup
end
