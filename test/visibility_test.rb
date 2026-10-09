# frozen_string_literal: true

require "test_helper"

class VisibilityTest < Minitest::Test
  class Card < ViewComponent::Base
    def call = "card"
  end

  def setup
    RecordingStudio::MCP_UI.reset_registry!
  end

  def teardown
    RecordingStudio::MCP_UI.reset_registry!
  end

  def test_available_if
    RecordingStudio::MCP_UI.register(
      "projects.preview",
      component: Card,
      available_if: ->(access_grant:, **) { access_grant == :allowed }
    )

    refute RecordingStudio::MCP_UI.available?("projects.preview", access_grant: :denied)
    assert RecordingStudio::MCP_UI.available?("projects.preview", access_grant: :allowed)
  end

  def test_registration_does_not_grant_operations
    widget = RecordingStudio::MCP_UI.register(
      "projects.editor",
      component: Card,
      mode: :edit,
      actions: { save: "projects.update" }
    )

    assert widget.permits_action?("save")
    refute_respond_to RecordingStudio::MCP_UI, :register_endpoint
  end
end
