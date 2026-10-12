# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class McpPageTopicsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    sign_in @user
  end

  test "packaged topics html includes one chip template and the empty state" do
    html = RecordingStudio::MCP_UI.package("pages.topics", data: {}).html
    template = html[/<template\b[^>]*data-mcp-list-item[^>]*>.*?<\/template>/m]

    assert template, html
    assert_includes html, 'data-mcp-list="topics"'
    assert_includes html, "data-mcp-list-empty"
    assert_includes html, "No topics yet."
    assert_includes template, "data-mcp-text"
    assert_includes template, "rounded-[var(--chip-border-radius)]"
    refute_includes template, "No topics yet."
    assert_equal 1, html.scan(/<template\b[^>]*data-mcp-list-item/).size

    filled = RecordingStudio::MCP_UI.package(
      "pages.topics",
      data: { "topics" => [ "Launch", "Story", "Press" ] }
    ).html
    config = JSON.parse(filled[%r{id="mcp-ui-config">(?<json>.*?)</script>}m, :json])

    assert_equal [ "Launch", "Story", "Press" ], config.dig("data", "topics")
    assert_equal 1, filled.scan(/<template\b[^>]*data-mcp-list-item/).size
    refute_includes filled[/<template\b[^>]*data-mcp-list-item[^>]*>.*?<\/template>/m], "Launch"
  end

  test "packaged tabs html includes an outline item template" do
    html = RecordingStudio::MCP_UI.package("pages.tabs", data: {}).html
    template = html[/<template\b[^>]*data-mcp-list-item[^>]*>.*?<\/template>/m]

    assert template, html
    assert_includes html, 'data-mcp-list="sections"'
    assert_includes html, 'data-mcp-text="summary"'
    assert_includes html, "data-mcp-list-empty"
    assert_includes html, "Nothing here yet. Add a section to get going."
    assert_includes template, 'data-mcp-text="heading"'
    assert_includes html, 'role="tab"'
  end

  test "topics document is the packaged widget and the host page can send a tool result" do
    get topics_widget_document_path

    assert_response :success
    assert_includes response.headers["Content-Type"], "text/html"
    assert_includes response.body, "data-mcp-list-item"
    assert_includes response.body, "No topics yet."
    refute_includes response.body, ">Launch<"

    get topics_widget_path

    assert_response :success
    assert_includes response.body, topics_widget_document_path
    assert_includes response.body, "mcp-ui-frame"
    assert_includes response.body, "ui/notifications/tool-result"
    assert_includes response.body, 'id="topics-show"'
    assert_includes response.body, 'id="topics-clear"'
  end
end
