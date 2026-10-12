# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

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
    @original_compiled_css_path = RecordingStudio::MCP_UI.configuration.compiled_css_path
  end

  def teardown
    RecordingStudio::MCP_UI.configuration.compiled_css_path = @original_compiled_css_path
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

  def test_package_defaults_to_transparent_widget_background
    RecordingStudio::MCP_UI.configuration.compiled_css_path = nil

    document = RecordingStudio::MCP_UI.package("projects.preview", data: { title: "Beach House" })

    assert_includes document.html, "--mcp-ui-background: transparent"
    assert_includes document.html, "--mcp-ui-surface: #fff"
    assert_includes document.html, "--mcp-ui-surface-color: #1f1f1f"
    assert_includes document.html, "color-scheme: light dark"
    refute_includes document.html, "CanvasText"
    refute_includes document.html, "background: var(--surface-color, #f8f8f5)"
  end

  def test_package_host_css_can_override_card_surface
    Dir.mktmpdir do |dir|
      host_css = File.join(dir, "mcp_ui_widget.css")
      File.write(host_css, ":root { --mcp-ui-surface: #c5e0ff; --mcp-ui-surface-color: #0b1f33; }")
      RecordingStudio::MCP_UI.configuration.compiled_css_path = host_css

      document = RecordingStudio::MCP_UI.package("projects.preview", data: { title: "Beach House" })
      gem_index = document.html.index("--mcp-ui-surface: #fff")
      host_index = document.html.index("--mcp-ui-surface: #c5e0ff")

      refute_nil gem_index
      refute_nil host_index
      assert gem_index < host_index
    end
  end

  def test_package_inlines_host_css_after_gem_widget_css
    Dir.mktmpdir do |dir|
      host_css = File.join(dir, "mcp_ui_widget.css")
      File.write(host_css, ".mcp-ui-body { background: rgb(12, 34, 56); }")
      RecordingStudio::MCP_UI.configuration.compiled_css_path = host_css

      document = RecordingStudio::MCP_UI.package("projects.preview", data: { title: "Beach House" })
      gem_index = document.html.index("--mcp-ui-background: transparent")
      host_index = document.html.index(".mcp-ui-body { background: rgb(12, 34, 56); }")

      refute_nil gem_index
      refute_nil host_index
      assert gem_index < host_index, "host CSS must follow gem widget.css"
    end
  end

  def test_package_inlines_host_css_paths_in_order
    Dir.mktmpdir do |dir|
      first = File.join(dir, "first.css")
      second = File.join(dir, "second.css")
      File.write(first, ".mcp-ui-host-first { color: red; }")
      File.write(second, ".mcp-ui-host-second { color: blue; }")
      RecordingStudio::MCP_UI.configuration.compiled_css_path = [first, second]

      document = RecordingStudio::MCP_UI.package("projects.preview", data: { title: "Beach House" })
      first_index = document.html.index(".mcp-ui-host-first { color: red; }")
      second_index = document.html.index(".mcp-ui-host-second { color: blue; }")

      refute_nil first_index
      refute_nil second_index
      assert first_index < second_index
    end
  end

  def test_package_skips_missing_and_blank_host_css_paths
    RecordingStudio::MCP_UI.configuration.compiled_css_path = [
      nil,
      "",
      "/tmp/recording-studio-mcp-ui-missing-#{Process.pid}.css"
    ]

    document = RecordingStudio::MCP_UI.package("projects.preview", data: { title: "Beach House" })

    assert_includes document.html, "mcp-ui-body"
    assert_includes document.html, "--mcp-ui-background: transparent"
    refute_includes document.html, "recording-studio-mcp-ui-missing"
  end
end
