# frozen_string_literal: true

require "test_helper"
require "open3"

class McpUiStimulusBundleTest < ActiveSupport::TestCase
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
    flat-pack--chart
  ].freeze

  teardown do
    RecordingStudio::MCP_UI.configuration.stimulus_controllers = nil
  end

  test "packaged widget inlines host flatpack stimulus controllers" do
    html = RecordingStudio::MCP_UI.package("projects.preview", data: {}).html

    CONTROLLERS.each do |identifier|
      assert_includes html, %{application.register("#{identifier}",}
    end
    refute_includes html, 'application.register("flat-pack--tiptap"'
    assert_includes html,
                    'skipped controllers/flat_pack/tiptap_controller: import "@tiptap/core" is a remote URL'
    assert_includes html, 'import("apexcharts")'
    bundle_at = html.index('application.register("flat-pack--tabs"')
    boot_at = html.index("data-controller~='mcp-editor'")
    assert bundle_at < boot_at
    assert_javascript(widget_script(html))
  end

  test "stimulus_controllers false omits the bundle" do
    RecordingStudio::MCP_UI.configuration.stimulus_controllers = false
    html = RecordingStudio::MCP_UI.package("projects.preview", data: {}).html

    refute_includes html, 'application.register("flat-pack--tabs"'
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
