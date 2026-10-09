# frozen_string_literal: true

require "yaml"
require_relative "simplecov_helper"
require "minitest/autorun"

class RenameVerificationTest < Minitest::Test
  def setup
    @root = File.expand_path("..", __dir__)
    @gem_name = "recording_studio_mcp_ui"
  end

  def test_gemspec_and_lib_exist
    assert File.exist?(File.join(@root, "#{@gem_name}.gemspec"))
    assert File.exist?(File.join(@root, "lib", "#{@gem_name}.rb"))
    assert Dir.exist?(File.join(@root, "lib", @gem_name))
    assert File.exist?(File.join(@root, "lib", @gem_name, "version.rb"))
    assert File.exist?(File.join(@root, "lib", @gem_name, "engine.rb"))
  end

  def test_public_namespace_is_recording_studio_mcp_ui
    version = File.read(File.join(@root, "lib", @gem_name, "version.rb"))
    engine = File.read(File.join(@root, "lib", @gem_name, "engine.rb"))
    routes = File.read(File.join(@root, "config", "routes.rb"))

    assert_includes version, "module McpUi"
    assert_includes version, 'VERSION = "0.1.0"'
    assert_includes File.read(File.join(@root, "lib", "#{@gem_name}.rb")), "MCP_UI = McpUi"
    assert_includes engine, "isolate_namespace RecordingStudio::McpUi"
    assert_includes routes, "RecordingStudio::McpUi::Engine.routes.draw"
  end

  def test_controllers_use_nested_namespace
    application = File.join(@root, "app/controllers/recording_studio/mcp_ui/application_controller.rb")
    home = File.join(@root, "app/controllers/recording_studio/mcp_ui/home_controller.rb")

    assert File.exist?(application)
    assert File.exist?(home)
    assert_includes File.read(application), "module McpUi"
  end

  def test_no_old_gem_template_directories
    refute Dir.exist?(File.join(@root, "lib", "gem_template"))
    refute Dir.exist?(File.join(@root, "app", "controllers", "gem_template"))
    refute File.exist?(File.join(@root, "gem_template.gemspec"))
    refute File.exist?(File.join(@root, "lib", "gem_template.rb"))
  end

  def test_readme_and_changelog_use_new_identity
    readme = File.read(File.join(@root, "README.md"))
    changelog = File.read(File.join(@root, "CHANGELOG.md"))

    assert_includes readme, "RecordingStudio::MCP_UI"
    refute_includes readme, "https://github.com/bowerbird-app/RecordingStudio_gem_template"
    assert_includes changelog, "0.1.0"
    refute_includes changelog, "RecordingStudio_gem_template"
  end

  def test_version_file_is_loadable
    $LOAD_PATH.unshift(File.join(@root, "lib")) unless $LOAD_PATH.include?(File.join(@root, "lib"))
    require "recording_studio_mcp_ui/version"
    assert_equal "0.1.0", RecordingStudio::MCP_UI::VERSION
  end
end
