# frozen_string_literal: true

require "test_helper"

class McpProjectWidgetsTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers

  setup do
    @user = create_user
    _root, @access_recording = create_access_recording_for(user: @user)
    @pkce = pkce_pair
    @oauth_client, = create_oauth_client(name: "MCP Project Widgets")
    @project = Project.create!(
      title: "Widget House",
      description: "A project the widget can edit.",
      status: "active"
    )
    @token = issue_delegated_token(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording,
      role: "edit",
      pkce: @pkce
    )
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "tools list advertises ui resourceUri for project tools" do
    post "/recording_studio_mcp",
         params: rpc("tools/list").to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    body = JSON.parse(response.body)
    tools = body.dig("result", "tools")
    assert tools, body.inspect
    show = tools.find { |tool| tool["name"] == "projects.show" }
    update = tools.find { |tool| tool["name"] == "projects.update" }
    assert show, tools.map { |tool| tool["name"] }.inspect
    assert update, tools.map { |tool| tool["name"] }.inspect

    assert_equal "ui://projects/preview", show.dig("_meta", "ui", "resourceUri")
    assert_equal "ui://projects/editor", update.dig("_meta", "ui", "resourceUri")
  end

  test "every registered widget packages with empty data" do
    widgets = RecordingStudio::MCP_UI.list
    refute_empty widgets

    widgets.each do |widget|
      document = RecordingStudio::MCP_UI.package(widget.id, data: {})
      assert document.html.present?, widget.id
      assert_includes document.html, "mcp-ui-config"
    end
  end

  test "resources read returns the packaged widget html" do
    post "/recording_studio_mcp",
         params: rpc("resources/read", uri: "ui://projects/preview").to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    preview = JSON.parse(response.body)
    refute preview["error"], preview.inspect
    preview_html = (preview.dig("result", "contents") || preview.dig("result", "content")).first.fetch("text")
    assert_includes preview_html, "mcp-ui-config"
    assert_includes preview_html, "data-mcp-text=\"title\""

    post "/recording_studio_mcp",
         params: rpc("resources/read", uri: "ui://projects/editor").to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    result = JSON.parse(response.body).fetch("result")
    contents = result["contents"] || result["content"]
    html = contents.first.fetch("text")

    assert_includes html, "mcp-ui-config"
    assert_includes html, "projects.update"
    assert_includes html, "McpApps"
  end

  test "projects show returns fields at the top of structuredContent" do
    post "/recording_studio_mcp",
         params: rpc("tools/call", name: "projects.show", arguments: { id: @project.id }).to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    payload = JSON.parse(response.body)
    refute payload.dig("result", "isError"), payload.inspect
    body = payload.dig("result", "structuredContent")
    assert body, payload.inspect
    refute body.key?("json"), body.inspect

    assert_equal @project.id, body["id"]
    assert_equal "Widget House", body["title"]
    assert_equal "A project the widget can edit.", body["description"]
    assert_equal "active", body["status"]
    assert_equal @project.revision, body["revision"]
  end

  test "calling the real update tool persists the project" do
    post "/recording_studio_mcp",
         params: rpc(
           "tools/call",
           name: "projects.update",
           arguments: {
             id: @project.id,
             title: "Updated House",
             description: @project.description,
             status: "draft",
             revision: @project.revision
           }
         ).to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    payload = JSON.parse(response.body)
    refute payload.dig("result", "isError")
    body = tool_payload(payload)
    data = body["data"] || body

    assert_equal "Updated House", data["title"]
    assert_equal "Updated House", @project.reload.title
    assert_equal "draft", @project.status
  end
end
