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

  # Hosts must set authorize_write before Recording Studio core 6.5.0.
  # Writes fail closed. Access grant/bootstrap writes go through Accessible's
  # AccessCreationContext (same path as grant_access / bootstrap_owner_access!),
  # not any-write-during-grant-context. Other writes need Accessible :edit on
  # the root.
  config.authorize_write = lambda { |actor:, root_recording:, recordable:, **|
    next false if actor.blank?
    next false unless root_recording

    if defined?(RecordingStudio::Access) && recordable.is_a?(RecordingStudio::Access)
      next true if RecordingStudioAccessible::AccessCreationContext.allowed?

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: root_recording,
        role: :admin
      )
    else
      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: root_recording,
        role: :edit
      )
    end
  }

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup
end
