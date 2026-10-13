# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "nokogiri"
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

  def test_package_includes_english_i18n_blob_for_js_runtime
    RecordingStudio::MCP_UI.register(
      "projects.editor",
      component: UnsafeComponent,
      mode: :edit,
      actions: { save: "projects.update" }
    )

    document = RecordingStudio::MCP_UI.package("projects.editor", data: { title: "Beach House" })
    config = JSON.parse(document.html[%r{id="mcp-ui-config">(?<json>.*?)</script>}m, :json])
    i18n = config.fetch("i18n")

    assert_equal "Saving…", i18n.dig("editor", "saving")
    assert_equal "Saved", i18n.dig("editor", "saved")
    assert_equal "Save failed", i18n.dig("editor", "save_failed")
    assert_equal "Tool call failed", i18n.dig("runtime", "tool_call_failed")
    assert_equal "Unknown action alias: %{alias}", i18n.dig("runtime", "unknown_action_alias")
    assert_equal "No action transport", i18n.dig("runtime", "no_action_transport")
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
    assert_includes document.html, "--mcp-ui-surface-scheme: light"
    assert_includes document.html, "color-scheme: var(--mcp-ui-surface-scheme)"
    assert_includes document.html, "color-scheme: light dark"
    refute_includes document.html, "CanvasText"
    refute_includes document.html, "background: var(--surface-color, #f8f8f5)"
  end

  def test_package_paints_flatpack_card_tokens_without_host_css
    RecordingStudio::MCP_UI.configuration.compiled_css_path = nil

    document = RecordingStudio::MCP_UI.package("projects.preview", data: { title: "Beach House" })
    css = packaged_css(document.html)

    assert_includes css, "background-color: var(--card-background-color)"
    assert_includes css, "background-color: var(--card-background-muted-color)"
  end

  def test_package_keeps_mixed_content_beside_a_component_card
    card = %(<div class="bg-[var(--card-background-color)]"><div class="mcp-ui-card">Inside</div></div>)

    only_child = RecordingStudio::MCP_UI.package("projects.preview", data: {}, body_html: card)
    only_root = packaged_root(only_child.html)
    assert_equal 1, only_root.element_children.size
    assert_includes only_root.element_children.first["class"], "card-background-color"

    mixed = RecordingStudio::MCP_UI.package(
      "projects.preview",
      data: {},
      body_html: %(<p class="outside">Header</p>#{card})
    )
    mixed_root = packaged_root(mixed.html)
    assert_equal 2, mixed_root.element_children.size
    assert_equal "outside", mixed_root.element_children.first["class"]
    assert_includes mixed.html, "--mcp-ui-surface: #fff"
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

  private

  def packaged_css(html)
    html[%r{<style>(.*?)</style>}m, 1]
  end

  def packaged_root(html)
    Nokogiri::HTML(html).at_css("#mcp-ui-root")
  end
end
