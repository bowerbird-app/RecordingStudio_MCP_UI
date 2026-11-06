# frozen_string_literal: true

require "test_helper"

class DemoProjectAccessTest < ActiveSupport::TestCase
  setup do
    @user = create_user
    @root_recording, = create_access_recording_for(user: @user, role: :admin)
    @project = Project.create!(title: "Access House", description: "Scoped", status: "active")
  end

  teardown do
    Current.actor = nil
  end

  test "writable uses Accessible edit on the current root" do
    assert Demo::ProjectAccess.writable?(actor: @user, recording: @root_recording)
    refute Demo::ProjectAccess.writable?(actor: @user, recording: nil)
    refute Demo::ProjectAccess.visible?(actor: nil, recording: @root_recording)
  end

  test "update persists when Accessible grants edit" do
    result = Demo::ProjectUpdate.call(
      { "id" => @project.id, "title" => "Granted House", "revision" => @project.revision },
      actor: @user,
      recording: @root_recording
    )

    assert result[:ok]
    assert_equal "Granted House", @project.reload.title
  end

  test "update is unauthorized without Accessible edit" do
    stranger = create_user
    result = Demo::ProjectUpdate.call(
      { "id" => @project.id, "title" => "Stolen House", "revision" => @project.revision },
      actor: stranger,
      recording: @root_recording
    )

    refute result[:ok]
    assert_equal "unauthorized", result[:error]
    assert_equal "Access House", @project.reload.title
  end
end
