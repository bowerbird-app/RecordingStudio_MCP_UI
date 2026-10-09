# frozen_string_literal: true

require "test_helper"

class ActionBridgeTest < Minitest::Test
  class EditorComponent < ViewComponent::Base
    def call = "editor"
  end

  def setup
    RecordingStudio::MCP_UI.reset_registry!
    RecordingStudio::MCP_UI.register(
      "projects.editor",
      component: EditorComponent,
      mode: :edit,
      actions: { save: "projects.update" }
    )
  end

  def teardown
    RecordingStudio::MCP_UI.reset_registry!
    RecordingStudio::MCP_UI.configuration.action_executor = nil
  end

  def test_unknown_action_alias
    assert_raises(RecordingStudio::MCP_UI::UnknownActionError) do
      RecordingStudio::MCP_UI.execute("projects.editor", "destroy", arguments: {})
    end
  end

  def test_successful_save
    RecordingStudio::MCP_UI.configuration.action_executor = lambda { |request|
      assert_equal "save", request.alias_name
      assert_equal "projects.update", request.api_action
      RecordingStudio::MCP_UI::ActionResult.success(data: { "title" => "Updated" }, context_update: "saved")
    }

    result = RecordingStudio::MCP_UI.execute("projects.editor", "save", arguments: { "title" => "Updated" })
    assert result.ok
    assert_equal "Updated", result.data["title"]
  end

  def test_validation_and_unauthorized_and_conflict
    RecordingStudio::MCP_UI.configuration.action_executor = lambda { |request|
      case request.access_grant
      when :denied
        { ok: false, error: "unauthorized" }
      when :stale
        { ok: false, error: "conflict", errors: { "revision" => "changed" } }
      else
        { ok: false, error: "validation_failed", errors: { "title" => "can't be blank" } }
      end
    }

    denied = RecordingStudio::MCP_UI.execute("projects.editor", "save", access_grant: :denied)
    refute denied.ok
    assert_equal "unauthorized", denied.error

    stale = RecordingStudio::MCP_UI.execute("projects.editor", "save", access_grant: :stale, revision: 1)
    refute stale.ok
    assert_equal "conflict", stale.error

    invalid = RecordingStudio::MCP_UI.execute("projects.editor", "save", arguments: { "title" => "" })
    refute invalid.ok
    assert_equal "can't be blank", invalid.errors["title"]
  end
end
