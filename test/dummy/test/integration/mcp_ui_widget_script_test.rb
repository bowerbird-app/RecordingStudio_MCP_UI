# frozen_string_literal: true

require "test_helper"
require "open3"

class McpUiWidgetScriptTest < ActiveSupport::TestCase
  CONTROLLERS = %w[
    flat-pack--collection-editor
    flat-pack--list-orderable
    flat-pack--table-sortable
    flat-pack--tabs
    flat-pack--chip
    flat-pack--accordion
    flat-pack--date-input
    flat-pack--combobox
    flat-pack--modal
    flat-pack--drawer
    flat-pack--picker
  ].freeze

  setup do
    @original_script = RecordingStudio::MCP_UI.configuration.widget_script_path
  end

  teardown do
    RecordingStudio::MCP_UI.configuration.widget_script_path = @original_script
  end

  test "packaged widget inlines the esbuild bundle before the editor runtime" do
    html = RecordingStudio::MCP_UI.package("projects.preview", data: {}).html
    script = widget_script(html)

    CONTROLLERS.each do |identifier|
      assert_includes script, identifier
    end
    refute_includes script, "@tiptap/core"
    refute_includes script, "apexcharts"
    bundle_at = html.index("flat-pack--tabs")
    runtime_at = html.index("data-controller~='mcp-editor'")
    assert_operator bundle_at, :<, runtime_at
    assert_javascript(script)
  end

  test "a blank widget script path leaves the editor runtime in place" do
    RecordingStudio::MCP_UI.configuration.widget_script_path = nil
    html = RecordingStudio::MCP_UI.package("projects.preview", data: {}).html

    refute_includes html, "flat-pack--tabs"
    assert_includes html, "data-controller~='mcp-editor'"
  end

  private

  def widget_script(html)
    html[/<script>(?<script>.*?)<\/script>\s*<\/body>/m, :script]
  end

  def assert_javascript(source)
    refute_nil source
    Tempfile.create(["widget", ".js"]) do |file|
      file.write(source)
      file.flush
      output, status = Open3.capture2e("node", "--check", file.path)
      assert status.success?, output
    end
  end
end
