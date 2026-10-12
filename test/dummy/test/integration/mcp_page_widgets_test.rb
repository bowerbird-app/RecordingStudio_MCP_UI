# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class McpPageWidgetsTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    @root, @access_recording = create_access_recording_for(user: @user)
    @pkce = pkce_pair
    @oauth_client, = create_oauth_client(name: "MCP Page Widgets")
    @recording = create_page_recording
    @page = @recording.recordable
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

  test "tools list advertises ui resourceUri for page tools" do
    post "/recording_studio_mcp",
         params: rpc("tools/list").to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    tools = JSON.parse(response.body).dig("result", "tools")
    show = tools.find { |tool| tool["name"] == "pages.show" }
    update = tools.find { |tool| tool["name"] == "pages.update" }
    assert show, tools.map { |tool| tool["name"] }.inspect
    assert update, tools.map { |tool| tool["name"] }.inspect

    assert_equal "ui://pages/tabs", show.dig("_meta", "ui", "resourceUri").to_s.split("?", 2).first
    assert_equal "ui://pages/sections", update.dig("_meta", "ui", "resourceUri").to_s.split("?", 2).first
    %w[links topics notes].each do |name|
      tool = tools.find { |candidate| candidate["name"] == "pages.#{name}" }
      assert tool, tools.map { |candidate| candidate["name"] }.inspect
      assert_equal "ui://pages/#{name}", tool.dig("_meta", "ui", "resourceUri").to_s.split("?", 2).first
    end
  end

  test "resources read renders each page widget" do
    expectations = {
      "ui://pages/sections" => [ "flat-pack-collection-editor", "Add section", "pages.update" ],
      "ui://pages/links" => [ "Label", "Link" ],
      "ui://pages/tabs" => [ "Story", "Outline", "flat-pack--tabs", 'data-mcp-list="sections"' ],
      "ui://pages/topics" => [ "No topics yet.", 'data-mcp-list="topics"', "data-mcp-list-item" ],
      "ui://pages/notes" => [ "flat-pack--accordion", "Nothing here yet" ]
    }

    expectations.each do |uri, markers|
      post "/recording_studio_mcp",
           params: rpc("resources/read", uri: uri).to_json,
           headers: json_headers("Authorization" => "Bearer #{@token}")

      assert_response :success, response.body
      body = JSON.parse(response.body)
      refute body["error"], body.inspect
      html = (body.dig("result", "contents") || body.dig("result", "content")).first.fetch("text")
      assert_includes html, "mcp-ui-config"
      assert_includes html, "card-background-color"
      markers.each { |marker| assert_includes html, marker, uri }
    end
  end

  test "packaged documents render the page inside each widget" do
    data = Demo::PagePayload.call(@recording)

    sections = RecordingStudio::MCP_UI.package("pages.sections", data: data).html
    assert_includes sections, "flat-pack-collection-editor--orderable"
    assert_includes sections, "Open"
    assert_includes sections, "Say hello."
    assert_match(/data-controller="mcp-editor"[^>]*data-mcp-restore-order/, sections)
    section_rows = sections.scan(/<li\b[^>]*flat-pack-collection-editor-row[^>]*>/)
    assert_equal 3, section_rows.size
    section_rows.each { |row| assert_includes row, "data-mcp-row" }
    assert_includes sections, 'data-mcp-save="save"'
    assert_includes sections, 'data-mcp-error="title"'
    assert_includes sections, 'role="alert"'
    assert_includes sections, "data-mcp-status"
    assert_includes sections, "pages.update"
    %w[
      flat-pack--collection-editor
      flat-pack--list-orderable
      flat-pack--table-sortable
      flat-pack--tabs
      flat-pack--chip
      flat-pack--accordion
    ].each do |identifier|
      assert_includes sections, "application.register(\"#{identifier}\","
    end
    refute_includes sections, "orderable-url"
    %w[id heading body _destroy].each do |key|
      assert_includes sections, %(name="sections[][#{key}]")
    end
    assert_equal 3, sections.scan('name="sections[][id]"').size
    refute_includes sections, 'name="sections[open][id]"'
    template = sections[/<template[^>]*>(?<inner>.*?)<\/template>/m, :inner]
    assert template
    %w[id heading body _destroy].each do |key|
      assert_includes template, %(name="sections[][#{key}]"), key
      assert_includes template, "data-mcp-field"
    end
    assert_includes template, "data-mcp-row"
    refute_includes sections, "sections[open][heading]"
    handles = sections.scan(%r{<button[^>]*flat-pack-collection-editor-handle[^>]*>.*?</button>}m)
    assert_equal 3, handles.size
    handles.each { |handle| assert_equal 1, handle.scan("<svg").size }
    refute_includes sections, "⋮"
    %w[heading body].each do |key|
      control = sections[/<(?:input|textarea)\b[^>]*name="sections\[\]\[#{key}\]"[^>]*>/]
      assert control, key
      assert_includes control, "border-0"
      assert_includes control, "bg-transparent"
      assert_includes control, "rounded-none"
      refute_includes control, "rounded-[var(--radius-md)]"
    end

    links = RecordingStudio::MCP_UI.package("pages.links", data: data).html
    assert_includes links, "Site"
    assert_includes links, "https://example.com/press"
    assert_includes links, "sort=label"
    assert_includes links, 'name="links[][label]"'
    assert_includes links, 'name="links[][url]"'
    assert_includes links, 'name="links[][id]"'
    assert_includes links, "data-mcp-field"
    assert_includes links, "flat-pack--table-sortable"
    refute_match(/data-controller="mcp-editor"[^>]*data-mcp-restore-order/, links)
    body = links[/<tbody\b[^>]*>.*?<\/tbody>/m]
    assert body
    body_rows = body.scan(/<tr\b[^>]*>/)
    assert_equal 2, body_rows.size
    body_rows.each { |row| assert_includes row, "data-mcp-row" }
    header = links[/<thead\b[^>]*>.*?<\/thead>/m]
    refute_includes header, "data-mcp-row"
    assert_includes links, 'data-mcp-save="save"'
    grips = links.scan(%r{<span[^>]*cursor-grab[^>]*>⋮</span>})
    assert_equal 2, grips.size
    refute_includes links, "⋮⋮"
    assert_includes links, "cursor-grab"
    assert_includes links, "flat-pack-link"
    assert_includes links, "fp-content"
    assert_includes links, 'role="alert"'
    assert_includes links, "data-mcp-status"
    refute_includes links, ">Label</label>"
    refute_includes links, ">Link</label>"
    refute_includes links, "reorder-url"

    tabs = RecordingStudio::MCP_UI.package("pages.tabs", data: data).html
    assert_includes tabs, "A short page."
    assert_includes tabs, "Open"
    assert_includes tabs, 'role="tab"'
    assert_includes tabs, 'data-mcp-text="summary"'
    assert_includes tabs, 'data-mcp-list="sections"'
    assert_includes tabs, 'data-mcp-text="heading"'
    assert_includes tabs, "data-mcp-list-empty"
    assert_includes tabs, "Nothing here yet. Add a section to get going."
    assert_includes tabs, "flat-pack-list"
    outline = tabs[/<template\b[^>]*data-mcp-list-item[^>]*>.*?<\/template>/m]
    assert_includes outline, 'data-mcp-text="heading"'
    refute_includes outline, "Open"

    topics = RecordingStudio::MCP_UI.package("pages.topics", data: data).html
    assert_includes topics, 'data-mcp-list="topics"'
    assert_includes topics, "data-mcp-list-item"
    assert_includes topics, "data-mcp-list-empty"
    assert_includes topics, "Launch"
    assert_includes topics, "Story"
    assert_includes topics, "flat-pack--chip"
    topic_template = topics[/<template\b[^>]*data-mcp-list-item[^>]*>.*?<\/template>/m]
    assert_includes topic_template, "data-mcp-text"
    assert_includes topic_template, "rounded-[var(--chip-border-radius)]"
    refute_includes topic_template, "Launch"
    refute_includes topic_template, "No topics yet."
    assert_equal 1, topics.scan(/<template\b[^>]*data-mcp-list-item/).size
    topic_config = JSON.parse(topics[%r{id="mcp-ui-config">(?<json>.*?)</script>}m, :json])
    assert_equal data["topics"], topic_config.dig("data", "topics")
    empty_topics = RecordingStudio::MCP_UI.package("pages.topics", data: {}).html
    assert_includes empty_topics, "No topics yet."
    assert_includes empty_topics, "fp-empty-state"

    notes = RecordingStudio::MCP_UI.package("pages.notes", data: data).html
    assert_includes notes, "Say hello."
    assert_includes notes, "Do the thing."
    assert_includes notes, "flat-pack--accordion"
    assert_includes notes, "fp-content"
  end

  test "pages show returns fields at the top of structuredContent" do
    post "/recording_studio_mcp",
         params: rpc("tools/call", name: "pages.show", arguments: { id: @recording.id }).to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    payload = JSON.parse(response.body)
    refute payload.dig("result", "isError"), payload.inspect
    body = payload.dig("result", "structuredContent")
    assert_equal @recording.id, body["id"]
    assert_equal "Launch notes", body["title"]
    assert_equal "A short page.", body["summary"]
    assert_equal %w[open next], body["sections"].map { |section| section["id"] }
    assert_equal %w[site press], body["links"].map { |link| link["id"] }
    assert_equal [ "Launch", "Story" ], body["topics"]
    assert_equal @page.revision, body["revision"]
  end

  test "calling the real update tool reorders sections and revises the page" do
    reordered = [
      { "id" => "next", "heading" => "Next", "body" => "Do the thing." },
      { "id" => "open", "heading" => "Open", "body" => "Hello again." }
    ]
    events_before = RecordingStudio::Event.where(recording_id: @recording.id).count

    post "/recording_studio_mcp",
         params: rpc(
           "tools/call",
           name: "pages.update",
           arguments: {
             id: @recording.id,
             sections: reordered,
             revision: @page.revision
           }
         ).to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    payload = JSON.parse(response.body)
    refute payload.dig("result", "isError"), payload.inspect
    body = tool_payload(payload)
    data = body["data"] || body

    @recording.reload
    revised = @recording.recordable
    assert_equal %w[next open], data["sections"].map { |section| section["id"] }
    assert_equal "Hello again.", data["sections"].last["body"]
    assert_equal @recording.id, data["id"]
    assert_equal revised.revision, data["revision"]
    assert_equal @page.revision + 1, revised.revision
    refute_equal @page.id, revised.id
    assert_equal %w[next open], Demo::PageContent.sections(revised.sections).map { |section| section["id"] }
    assert_equal %w[open next], Demo::PageContent.sections(Page.find(@page.id).sections).map { |section| section["id"] }
    assert_equal "Say hello.", Page.find(@page.id).sections.first["body"]
    assert_equal events_before + 1, RecordingStudio::Event.where(recording_id: @recording.id).count
    assert body["contextUpdate"].to_s.include?("Launch notes")
  end

  test "calling the real update tool drops a destroyed section and reorders links" do
    post "/recording_studio_mcp",
         params: rpc(
           "tools/call",
           name: "pages.update",
           arguments: {
             id: @recording.id,
             sections: [
               { "id" => "next", "heading" => "Next", "body" => "Do the thing.", "_destroy" => "0" },
               { "id" => "open", "heading" => "", "body" => "Gone", "_destroy" => "1" }
             ],
             links: [
               { "id" => "press", "label" => "Press", "url" => "https://example.com/press" },
               { "id" => "site", "label" => "Site", "url" => "https://example.com" }
             ],
             revision: @page.revision
           }
         ).to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    payload = JSON.parse(response.body)
    refute payload.dig("result", "isError"), payload.inspect
    data = tool_payload(payload)
    data = data["data"] || data
    assert_equal %w[next], data["sections"].map { |section| section["id"] }
    assert_equal %w[press site], data["links"].map { |link| link["id"] }

    @recording.reload
    revised = @recording.recordable
    assert_equal %w[next], Demo::PageContent.sections(revised.sections).map { |section| section["id"] }
    assert_equal %w[press site], Demo::PageContent.links(revised.links).map { |link| link["id"] }
    assert_equal %w[open next], Demo::PageContent.sections(Page.find(@page.id).sections).map { |section| section["id"] }
  end

  test "demo save reorders sections through the same update" do
    sign_in @user
    reordered = [
      { "id" => "next", "heading" => "Next", "body" => "Do the thing." },
      { "id" => "open", "heading" => "Open", "body" => "Say hello." }
    ]

    post "/page_demos/#{@recording.id}/save", params: {
      sections: reordered,
      revision: @page.revision
    }, as: :json

    assert_response :success, response.body
    @recording.reload
    assert_equal %w[next open], Demo::PageContent.sections(@recording.recordable.sections).map { |section| section["id"] }
    assert_equal %w[open next], Demo::PageContent.sections(Page.find(@page.id).sections).map { |section| section["id"] }
  end

  test "stale revision on the update tool returns a conflict" do
    post "/recording_studio_mcp",
         params: rpc(
           "tools/call",
           name: "pages.update",
           arguments: {
             id: @recording.id,
             title: "Stale notes",
             revision: @page.revision - 1
           }
         ).to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    body = tool_payload(JSON.parse(response.body))
    assert_equal false, body["ok"]
    assert_equal "conflict", body["error"]
    assert_equal "Launch notes", @recording.reload.recordable.title
    assert_equal @page.id, @recording.recordable_id
  end

  test "a view grant cannot update the page" do
    view_client, = create_oauth_client(name: "MCP Page View")
    view_token = issue_delegated_token(
      oauth_client: view_client,
      user: @user,
      access_recording: @access_recording,
      role: "view",
      pkce: pkce_pair
    )

    post "/recording_studio_mcp",
         params: rpc(
           "tools/call",
           name: "pages.update",
           arguments: {
             id: @recording.id,
             title: "Nope",
             revision: @page.revision
           }
         ).to_json,
         headers: json_headers("Authorization" => "Bearer #{view_token}")

    assert_response :success, response.body
    body = tool_payload(JSON.parse(response.body))
    assert_equal false, body["ok"]
    assert_equal "unauthorized", body["error"]
    assert_equal "Launch notes", @recording.reload.recordable.title
  end

  test "a section without a heading does not revise the page" do
    post "/recording_studio_mcp",
         params: rpc(
           "tools/call",
           name: "pages.update",
           arguments: {
             id: @recording.id,
             sections: [ { "id" => "open", "heading" => "", "body" => "Missing" } ],
             revision: @page.revision
           }
         ).to_json,
         headers: json_headers("Authorization" => "Bearer #{@token}")

    assert_response :success, response.body
    body = tool_payload(JSON.parse(response.body))
    assert_equal false, body["ok"]
    assert_equal "validation_failed", body["error"]
    assert_equal @page.id, @recording.reload.recordable_id
  end

  test "links document shows each label on the same row as its field" do
    get "/page_demos/#{@recording.id}/document", params: { widget: "pages.links" }

    assert_response :success
    rows = response.body.scan(%r{<tr\b[^>]*data-mcp-row[^>]*>.*?</tr>}m)
    labels = rows.map { |row| row[/name="links\[\]\[label\]"[^>]*value="([^"]+)"/, 1] }
    visible = rows.map { |row| row[/class="[^"]*fp-content[^"]*"[^>]*>\s*([^<]+)/, 1]&.strip }
    assert_equal [ "Press", "Site" ], labels
    assert_equal labels, visible
  end

  test "document route serves the packaged sections widget" do
    get "/page_demos/#{@recording.id}/document", params: { widget: "pages.sections" }

    assert_response :success
    assert_includes response.body, "Open"
    assert_includes response.body, "flat-pack-collection-editor"
    assert_includes response.body, "card-background-color"
    assert_includes response.headers["Content-Type"], "text/html"
  end

  private

  def create_page_recording
    Current.actor = @user
    page = Page.create!(
      title: "Launch notes",
      summary: "A short page.",
      sections: [
        { "id" => "open", "heading" => "Open", "body" => "Say hello." },
        { "id" => "next", "heading" => "Next", "body" => "Do the thing." }
      ],
      links: [
        { "id" => "site", "label" => "Site", "url" => "https://example.com" },
        { "id" => "press", "label" => "Press", "url" => "https://example.com/press" }
      ],
      topics: [ "Launch", "Story" ]
    )
    RecordingStudio.record!(
      action: "created",
      recordable: page,
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    ).recording
  end
end
