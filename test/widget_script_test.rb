# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class WidgetScriptTest < Minitest::Test
  class BundleComponent < ViewComponent::Base
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
    RecordingStudio::MCP_UI.register("projects.preview", component: BundleComponent, description: "card")
    @configuration = RecordingStudio::MCP_UI.configuration
    @original_script = @configuration.widget_script_path
  end

  def teardown
    @configuration.widget_script_path = @original_script
    RecordingStudio::MCP_UI.reset_registry!
  end

  def test_nil_widget_script_path_adds_nothing
    @configuration.widget_script_path = nil
    html = package_html

    refute_includes html, "WIDGET_BUNDLE"
    assert_includes html, "data-controller~='mcp-editor'"
  end

  def test_missing_widget_script_is_skipped
    @configuration.widget_script_path = "/tmp/missing-mcp-ui-widgets.js"
    html = package_html

    refute_includes html, "WIDGET_BUNDLE"
  end

  def test_widget_script_is_copied_before_the_editor_runtime
    Dir.mktmpdir do |dir|
      script = File.join(dir, "mcp_ui_widgets.js")
      File.write(script, "window.WIDGET_BUNDLE = true;\n")
      @configuration.widget_script_path = script
      html = package_html

      bundle_at = html.index("window.WIDGET_BUNDLE = true;")
      runtime_at = html.index("data-controller~='mcp-editor'")
      refute_nil bundle_at
      refute_nil runtime_at
      assert_operator bundle_at, :<, runtime_at
    end
  end

  private

  def package_html
    RecordingStudio::MCP_UI.package("projects.preview", data: { "title" => "Beach House" }).html
  end
end
