# frozen_string_literal: true

require "test_helper"

class PackagerTest < Minitest::Test
  class UnsafeComponent < ViewComponent::Base
    def initialize(data:)
      super()
      @data = data
    end

    def call
      %(<p>#{ERB::Util.html_escape(@data['title'])}</p>).html_safe
    end
  end

  def setup
    RecordingStudio::MCP_UI.reset_registry!
    RecordingStudio::MCP_UI.register("projects.preview", component: UnsafeComponent, description: "card")
  end

  def teardown
    RecordingStudio::MCP_UI.reset_registry!
  end

  def test_package_builds_mcp_apps_document
    document = RecordingStudio::MCP_UI.package(
      "projects.preview",
      data: { title: "<script>alert(1)</script>", token: "secret-token", api_key: "abc" }
    )

    assert_equal "ui://projects/preview", document.uri
    assert_equal "text/html;profile=mcp-app", document.mime_type
    assert_includes document.html, "mcp-ui-root"
    assert_includes document.html, "Content-Security-Policy"
    assert_includes document.html, "mcpUI"
    assert_includes document.html, "McpApps"
    refute_includes document.html, "secret-token"
    refute_includes document.html, "<script>alert(1)</script>"
    assert_includes document.html, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_equal "text/html;profile=mcp-app", document.to_mcp_resource[:mimeType]
  end

  def test_package_includes_alias_to_tool_name_map
    RecordingStudio::MCP_UI.register(
      "projects.editor",
      component: UnsafeComponent,
      mode: :edit,
      actions: { save: "projects.update" }
    )

    document = RecordingStudio::MCP_UI.package("projects.editor", data: { title: "Beach House" })
    config = JSON.parse(document.html[%r{id="mcp-ui-config">(?<json>.*?)</script>}m, :json])

    assert_equal "projects.update", config.fetch("actions").fetch("save")
    assert_equal "projects.editor", config.fetch("widgetId")
  end

  def test_missing_identifier_raises
    assert_raises(RecordingStudio::MCP_UI::UnknownWidgetError) do
      RecordingStudio::MCP_UI.package("missing.widget", data: {})
    end
  end

  def test_render_outputs_component_html
    html = RecordingStudio::MCP_UI.render("projects.preview", data: { title: "Beach House" })

    assert_includes html, "Beach House"
  end
end
