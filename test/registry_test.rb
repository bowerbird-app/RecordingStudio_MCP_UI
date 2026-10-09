# frozen_string_literal: true

require "test_helper"

class RegistryTest < Minitest::Test
  class PreviewComponent < ViewComponent::Base
    def call = "preview"
  end

  class OtherComponent < ViewComponent::Base
    def call = "other"
  end

  def setup
    RecordingStudio::MCP_UI.reset_registry!
  end

  def teardown
    RecordingStudio::MCP_UI.reset_registry!
  end

  def test_register_find_and_list
    widget = RecordingStudio::MCP_UI.register(
      "projects.preview",
      component: PreviewComponent,
      description: "Displays a project",
      mode: :read,
      version: "1.0.0"
    )

    assert_equal widget, RecordingStudio::MCP_UI.find("projects.preview")
    assert_equal [widget], RecordingStudio::MCP_UI.list
    assert_equal [widget], RecordingStudio::MCP_UI.list(mode: :read, prefix: "projects.")
    assert_empty RecordingStudio::MCP_UI.list(mode: :edit)
    assert_empty RecordingStudio::MCP_UI.list(version: "2.0.0")
  end

  def test_lookup_does_not_instantiate_component
    instantiated = false
    component = Class.new(ViewComponent::Base) do
      define_method(:initialize) do |**|
        instantiated = true
        super()
      end
    end
    RecordingStudio::MCP_UI.register("projects.card", component: component)

    RecordingStudio::MCP_UI.find("projects.card")
    refute instantiated
  end

  def test_duplicate_registration_fails_when_contract_changes
    RecordingStudio::MCP_UI.register("projects.preview", component: PreviewComponent)
    error = assert_raises(RecordingStudio::MCP_UI::DuplicateWidgetError) do
      RecordingStudio::MCP_UI.register("projects.preview", component: OtherComponent, description: "changed")
    end
    assert_match(/already registered/, error.message)
  end

  def test_identical_reregistration_is_reload_safe
    first = RecordingStudio::MCP_UI.register("projects.preview", component: PreviewComponent, version: "1.0.0")
    second = RecordingStudio::MCP_UI.register("projects.preview", component: PreviewComponent, version: "1.0.0")

    assert_equal first.id, second.id
    assert_equal 1, RecordingStudio::MCP_UI.list.size
  end

  def test_invalid_identifier_and_mode
    assert_raises(RecordingStudio::MCP_UI::InvalidWidgetError) do
      RecordingStudio::MCP_UI.register("Preview", component: PreviewComponent)
    end
    assert_raises(RecordingStudio::MCP_UI::InvalidWidgetError) do
      RecordingStudio::MCP_UI.register("projects.preview", component: PreviewComponent, mode: :wizard)
    end
  end

  def test_unknown_widget
    assert_raises(RecordingStudio::MCP_UI::UnknownWidgetError) do
      RecordingStudio::MCP_UI.find("missing.widget")
    end
  end

  def test_resource_uri_and_metadata_omit_record_data
    widget = RecordingStudio::MCP_UI.register(
      "projects.editor",
      component: PreviewComponent,
      description: "Edit a project",
      mode: :edit,
      actions: { save: "projects.update" }
    )

    assert_equal "ui://projects/editor", widget.resource_uri
    refute_includes widget.metadata.inspect, "secret"
    assert_equal({ "save" => "projects.update" }, widget.metadata[:actions])
  end
end
