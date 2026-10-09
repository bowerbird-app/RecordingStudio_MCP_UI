# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class McpUiDemoTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    sign_in @user
    @project = Project.find_or_create_by!(title: "Beach House") do |project|
      project.description = "A coastal recording project."
      project.status = "active"
    end
  end

  test "preview widget renders project fields" do
    get demo_path(@project)

    assert_response :success
    assert_includes response.body, "Beach House"
    assert_includes response.body, "A coastal recording project."
    assert_includes response.body, "active"
  end

  test "editor widget renders fields and packaged document includes runtime" do
    get edit_demo_path(@project)
    assert_response :success
    assert_includes response.body, 'data-controller="mcp-editor"'
    assert_includes response.body, "mcpUI"

    get document_demo_path(@project, widget: "projects.editor")
    assert_response :success
    assert_includes response.headers["Content-Type"], "text/html"
    assert_includes response.body, "mcp-ui-config"
    assert_includes response.body, "Content-Security-Policy"
    refute_includes response.body, "Password"
    refute_includes response.body, "secret"
  end

  test "save persists through the same domain operation as a conventional update" do
    post save_demo_path(@project), params: {
      title: "Updated House",
      description: @project.description,
      status: "draft",
      revision: @project.revision
    }, as: :json

    assert_response :success
    @project.reload
    assert_equal "Updated House", @project.title
    assert_equal "draft", @project.status
    assert_equal 2, @project.revision
  end

  test "validation error does not persist" do
    post save_demo_path(@project), params: {
      title: "",
      revision: @project.revision
    }, as: :json

    assert_response :unprocessable_entity
    assert_equal "Beach House", @project.reload.title
    assert_equal "validation_failed", response.parsed_body["error"]
  end

  test "unauthorized write is rejected" do
    post save_demo_path(@project), params: {
      title: "Nope",
      revision: @project.revision,
      access_grant: "denied"
    }, as: :json

    assert_response :forbidden
    assert_equal "Beach House", @project.reload.title
  end

  test "stale revision conflicts instead of overwriting" do
    post save_demo_path(@project), params: {
      title: "Stale",
      revision: @project.revision - 1
    }, as: :json

    assert_response :conflict
    assert_equal "Beach House", @project.reload.title
  end

  test "home page links to both demos" do
    get root_path
    assert_response :success
    assert_includes response.body, "MCP UI Demo"
    assert_includes response.body, demo_path(@project)
    assert_includes response.body, edit_demo_path(@project)
  end
end
