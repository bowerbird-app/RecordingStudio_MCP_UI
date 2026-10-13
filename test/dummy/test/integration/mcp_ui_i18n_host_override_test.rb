# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "json"

class McpUiI18nHostOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_TOOL_CALL_FAILED = "HOST Tool call failed"
  HOST_SAVED = "HOST Saved"
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_mcp_ui_host.en.yml")
  FRESH_HOST_LOCALE = Rails.root.join("test/locales/mcp_ui_host_override.en.yml")
  TOOL_CALL_FAILED_KEY = "recording_studio.mcp_ui.runtime.tool_call_failed"
  SAVED_KEY = "recording_studio.mcp_ui.editor.saved"

  setup do
    @original_load_path = I18n.load_path.dup
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

  teardown do
    I18n.load_path = @original_load_path
    I18n.reload!
    assert_equal @original_load_path, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  # Real-boot-order guard: host file under config/locales must win without any
  # test-time load_path mutation. Render assertion uses the packaged i18n blob.
  test "host locale override for recording_studio.mcp_ui wins on boot order" do
    assert File.exist?(BOOT_HOST_LOCALE)
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_TOOL_CALL_FAILED
    assert_equal HOST_TOOL_CALL_FAILED, I18n.t(TOOL_CALL_FAILED_KEY)
    assert_equal @original_load_path, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    get document_demo_path(@project, widget: "projects.editor")
    assert_response :success

    config = packaged_config(response.body)
    assert_equal HOST_TOOL_CALL_FAILED, config.dig("i18n", "runtime", "tool_call_failed")
    assert_equal "Saving…", config.dig("i18n", "editor", "saving")
    assert_equal "Saved", config.dig("i18n", "editor", "saved")
  end

  test "test-only host fixture overrides gem english on packaged editor i18n" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_SAVED

    begin
      I18n.load_path << FRESH_HOST_LOCALE.to_s
      I18n.reload!

      assert_equal HOST_SAVED, I18n.t(SAVED_KEY)
      assert_equal HOST_TOOL_CALL_FAILED, I18n.t(TOOL_CALL_FAILED_KEY)

      get document_demo_path(@project, widget: "projects.editor")
      assert_response :success

      config = packaged_config(response.body)
      assert_equal HOST_SAVED, config.dig("i18n", "editor", "saved")
      assert_equal "Saving…", config.dig("i18n", "editor", "saving")
      assert_equal HOST_TOOL_CALL_FAILED, config.dig("i18n", "runtime", "tool_call_failed")
    ensure
      I18n.load_path = @original_load_path.dup
      I18n.reload!
      assert_equal @original_load_path, I18n.load_path
    end
  end

  test "without the test-only override the gem english saved string still packages" do
    get document_demo_path(@project, widget: "projects.editor")
    assert_response :success

    config = packaged_config(response.body)
    assert_equal "Saved", config.dig("i18n", "editor", "saved")
    refute_equal HOST_SAVED, config.dig("i18n", "editor", "saved")
    assert_equal @original_load_path, I18n.load_path
  end

  private

  def packaged_config(html)
    json = html[%r{id="mcp-ui-config">(?<json>.*?)</script>}m, :json]
    refute_nil json
    JSON.parse(json)
  end
end
