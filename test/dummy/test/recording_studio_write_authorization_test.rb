# frozen_string_literal: true

require "test_helper"

class RecordingStudioWriteAuthorizationTest < ActiveSupport::TestCase
  setup do
    @authorizer = RecordingStudio.configuration.authorize_write
    @admin = create_user
    @root_recording, = create_access_recording_for(user: @admin, role: :admin)
    @editor = create_user
    grant_or_bootstrap_access!(
      recording: @root_recording,
      actor: @editor,
      role: :edit,
      manager_actor: @admin
    )
    @stranger = create_user
  end

  teardown do
    Current.actor = nil
  end

  test "non-access writes require Accessible edit on the root" do
    page = Page.new(title: "Write Gate")

    assert @authorizer.call(actor: @editor, root_recording: @root_recording, recordable: page)
    refute @authorizer.call(actor: @stranger, root_recording: @root_recording, recordable: page)
    refute @authorizer.call(actor: @editor, root_recording: nil, recordable: page)
    refute @authorizer.call(actor: nil, root_recording: @root_recording, recordable: page)
  end

  test "access writes are not any-write during grant context" do
    page = Page.new(title: "During Grant")
    access = RecordingStudio::Access.new(role: "view")

    RecordingStudioAccessible::AccessCreationContext.allow do
      refute @authorizer.call(actor: @stranger, root_recording: @root_recording, recordable: page)
      assert @authorizer.call(actor: @stranger, root_recording: @root_recording, recordable: access)
    end
  end

  test "access writes outside grant context require Accessible admin on the root" do
    access = RecordingStudio::Access.new(role: "view")

    assert @authorizer.call(actor: @admin, root_recording: @root_recording, recordable: access)
    refute @authorizer.call(actor: @editor, root_recording: @root_recording, recordable: access)
    refute @authorizer.call(actor: @stranger, root_recording: @root_recording, recordable: access)
  end
end
