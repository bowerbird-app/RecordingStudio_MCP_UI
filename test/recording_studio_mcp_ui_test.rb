# frozen_string_literal: true

require "test_helper"

class RecordingStudioMcpUiTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.6.0", RecordingStudio::MCP_UI::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, RecordingStudio::MCP_UI::Engine
  end

  def test_gemspec_pins_recording_studio_6_5
    gemspec = File.read(File.expand_path("../recording_studio_mcp_ui.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", ">= 6.5.0"'
    assert_includes gemspec, 'spec.add_dependency "view_component"'
    refute_includes gemspec, 'spec.add_dependency "view_component", "4'
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_mcp_ui.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
  end

  def test_cursor_environment_is_repo_managed_without_snapshot
    path = File.expand_path("../.cursor/environment.json", __dir__)
    json = JSON.parse(File.read(path))

    assert_equal "recording-studio-mcp-ui", json["name"]
    assert_equal ".cursor/install.sh", json["install"]
    assert_equal ".cursor/start.sh", json["start"]
    refute json.key?("snapshot")
    refute json.key?("agentCanUpdateSnapshot")
  end

  def test_cursor_install_still_fetches_skills
    install_script = File.read(File.expand_path("../.cursor/install.sh", __dir__))

    assert_includes install_script, "fetch-skills.sh"
  end

  def test_dummy_gemfile_pins_verified_6x_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v6.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.2"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin", tag: "v2.9.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.22.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.11.7"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.341"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_api", tag: "v0.17.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_mcp", tag: "v0.24.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_Oauth", tag: "v0.21.3"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_users", tag: "v0.27.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.7.3"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.3"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_cache", tag: "v0.6.3"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.4"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_site_settings", tag: "v0.5.5"'
    refute_includes gemfile, "recording_studio_views"
    refute_includes gemfile, "recording_studio/v3.0.0"
  end

  def test_dummy_schema_includes_accessible_depends_on_recording_id
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    assert_includes schema, 't.uuid "depends_on_recording_id"'
    assert_includes schema, 'create_table "recording_studio_access_invitations"'
    assert_includes schema, 'create_table "recording_studio_access_constraints"'
    assert_includes schema, 'create_table "recording_studio_access_rules"'
    assert_includes schema, 'create_table "recording_studio_attachable_libraries"'
    assert_includes schema, 'create_table "recording_studio_attachable_placements"'
  end

  def test_template_does_not_ship_copied_core_hooks_or_base_service
    refute File.exist?(File.expand_path("../lib/recording_studio_mcp_ui/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_mcp_ui/services/base_service.rb", __dir__))
  end

  def test_example_capability_wraps_include_for_and_is_not_enabled_globally
    source = File.read(File.expand_path("../lib/recording_studio_mcp_ui/capabilities/example.rb", __dir__))

    assert_includes source, "def self.to(**)"
    assert_includes source, "RecordingStudio::Capabilities.include_for(:example, **)"
    refute_includes source, "enable_capability"
    refute RecordingStudio.capability_enabled?(:example, for: "Folder")
    refute RecordingStudio.capability_enabled?(:example, for: "Page")
  end

  def test_dummy_app_uses_recording_studio_default_layout
    controller_source = File.read(File.expand_path("dummy/app/controllers/application_controller.rb", __dir__))

    assert_includes controller_source, "recording_studio_layout"
    assert_includes controller_source, "RecordingStudio::MCP_UI.configuration.layout"
    refute_includes controller_source, "UsesDefaultLayout"
    refute_includes controller_source, "flat_pack_sidebar"
  end

  def test_engine_application_controller_uses_recording_studio_layout
    controller_source = File.read(
      File.expand_path("../app/controllers/recording_studio/mcp_ui/application_controller.rb", __dir__)
    )

    assert_includes controller_source, "recording_studio_layout { RecordingStudio::MCP_UI.configuration.layout }"
    refute_includes controller_source, 'layout "application"'
    refute_includes controller_source, "UsesDefaultLayout"
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/application"'
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/engines/flat_pack/app/components"
    refute_includes tailwind_source, "@theme"
  end

  def test_recording_studio_keeps_strict_recordable_declarations_enabled
    initializer_source = File.read(File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__))

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    assert_includes initializer_source, "config.authorize_write"
    assert_includes initializer_source, "recordable.is_a?(RecordingStudio::Access)"
    assert_includes initializer_source, "RecordingStudioAccessible::AccessCreationContext.allowed?"
    assert_includes initializer_source, "recording: root_recording"
    assert_includes initializer_source, "role: :edit"
    refute_includes(
      initializer_source,
      "next true if RecordingStudioAccessible::AccessCreationContext.allowed?\n\n    target"
    )
    assert_includes initializer_source, '"Workspace"'
    assert_includes initializer_source, '"AdminRoot"'
    assert_includes initializer_source, '"RecordingStudioUser::People"'
  end

  def test_product_readme_is_the_mcp_ui_guide
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "RecordingStudio::MCP_UI"
    assert_includes readme, "dummy GitHub tag `v6.5.0`"
    assert_includes readme, "dummy GitHub tag `v0.1.341`"
    refute_includes readme, "UPDATE_SUMMARY.md"
    refute_includes readme, "ExampleService"
    refute_includes readme, "RecordingStudio v3"
  end

  def test_template_shell_docs_are_gone
    root = File.expand_path("..", __dir__)

    refute File.exist?(File.join(root, "UPDATE_SUMMARY.md"))
    refute File.exist?(File.join(root, "MIGRATION_NOTES.md"))
    refute Dir.exist?(File.join(root, "docs/gem_template"))
  end

  def test_coverage_is_untracked
    root = File.expand_path("..", __dir__)

    assert_includes File.read(File.join(root, ".gitignore")), "coverage/"
    assert_equal "", `git -C #{root} ls-files -- coverage test/dummy/coverage`.strip
  end

  def test_dummy_home_page_uses_demo_title_only
    view_source = File.read(File.expand_path("dummy/app/views/home/index.html.erb", __dir__))

    assert_includes view_source, 'title: "MCP UI Demo"'
    assert_includes view_source, "FlatPack::Card::Component"
    refute_includes view_source, "FlatPack::Breadcrumb::Component"
  end

  def test_dummy_docs_pages_use_minimal_flatpack_documentation_components
    docs_view_paths = Dir[File.expand_path("dummy/app/views/docs/*.html.erb", __dir__)].reject do |view_path|
      File.basename(view_path).start_with?("_")
    end
    refute_empty docs_view_paths

    docs_view_paths.each do |view_path|
      view_source = File.read(view_path)

      assert_includes view_source, "dummy_page_nav"
      assert_includes view_source, "FlatPack::PageTitle::Component"
      refute_includes view_source, "FlatPack::Card::Component"
    end
  end

  def test_engine_does_not_ship_a_home_stub
    root = File.expand_path("..", __dir__)
    view_path = File.join(root, "app/views/recording_studio/mcp_ui/home/index.html.erb")
    controller_path = File.join(root, "app/controllers/recording_studio/mcp_ui/home_controller.rb")
    routes = File.read(File.join(root, "config/routes.rb"))
    dummy_routes = File.read(File.expand_path("dummy/config/routes.rb", __dir__))

    refute File.exist?(view_path)
    refute File.exist?(controller_path)
    refute_includes routes, "home#index"
    refute_includes dummy_routes, "RecordingStudio::MCP_UI::Engine"
  end
end
