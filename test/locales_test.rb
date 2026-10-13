# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  # I18n template tokens use %{name}; RuboCop prefers %<name>s for Kernel#sprintf.
  # rubocop:disable Style/FormatStringToken
  EXPECTED_KEYS = {
    "editor.saving" => "Saving…",
    "editor.saved" => "Saved",
    "editor.save_failed" => "Save failed",
    "runtime.tool_call_failed" => "Tool call failed",
    "runtime.unknown_action_alias" => "Unknown action alias: %{alias}",
    "runtime.no_action_transport" => "No action transport"
  }.freeze
  # rubocop:enable Style/FormatStringToken

  RESERVED_YAML_TOKENS = %w[yes no on off true false null].freeze

  def setup
    @locale_path = File.expand_path("../config/locales/en.yml", __dir__)
    @original_load_path = I18n.load_path.dup
    @previous_locale = I18n.locale
    ensure_gem_locale_loaded!
    I18n.locale = :en
  end

  def teardown
    I18n.locale = @previous_locale
    I18n.load_path = @original_load_path
    I18n.reload!
  end

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_engine_exposes_english_locale_paths
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    existent = RecordingStudio::McpUi::Engine.paths["config/locales"].existent.map do |path|
      File.expand_path(path)
    end

    assert_includes existent, locale_path
  end

  def test_lib_sources_do_not_append_i18n_load_path
    lib_root = File.expand_path("../lib", __dir__)
    ruby_files = Dir[File.join(lib_root, "**", "*.rb")]

    refute_empty ruby_files, "expected lib/**/*.rb files to scan"

    ruby_files.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not touch i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not touch I18n.load_path"
    end
  end

  def test_english_mcp_ui_keys_resolve_without_missing_translations
    I18n.with_locale(:en) do
      EXPECTED_KEYS.each do |key, english|
        full_key = "recording_studio.mcp_ui.#{key}"
        translation = I18n.t(full_key, default: nil)

        assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
        assert_equal english, I18n.t(full_key, raise: true)
      end

      assert_equal(
        "Unknown action alias: destroy",
        I18n.t("recording_studio.mcp_ui.runtime.unknown_action_alias", alias: "destroy")
      )
    end
  end

  def test_en_yml_nests_keys_under_recording_studio_mcp_ui
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("mcp_ui")

    assert tree.key?("editor")
    assert tree.key?("runtime")
  end

  def test_gem_does_not_ship_a_legacy_recording_studio_mcp_ui_locale_namespace
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")

    refute tree.key?("recording_studio_mcp_ui")
  end

  def test_reserved_yaml_tokens_are_quoted_and_resolve_without_default
    raw = File.read(File.join(engine_locales_dir, "en.yml"))
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("mcp_ui")
    relative_keys = flatten_keys(tree)

    RESERVED_YAML_TOKENS.each do |token|
      bare_key = raw.match(/^\s*#{Regexp.escape(token)}\s*:/)
      assert_nil bare_key, "en.yml must quote reserved YAML key #{token.inspect}"
    end

    reserved_present = relative_keys.select { |key| RESERVED_YAML_TOKENS.include?(key.split(".").last) }
    reserved_present.each do |relative|
      full_key = "recording_studio.mcp_ui.#{relative}"
      assert_equal I18n.t(full_key, raise: true), I18n.t(full_key),
                   "#{full_key} must resolve without default:"
    end
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_mcp_ui.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
  end

  def test_dummy_gemfile_does_not_depend_on_internationalization
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    refute_includes gemfile, "recording_studio_internationalization"
    refute_includes gemfile, "RecordingStudio_Internationalization"
  end

  private

  def ensure_gem_locale_loaded!
    expanded = File.expand_path(@locale_path)
    loaded = I18n.load_path.map { |path| File.expand_path(path) }
    I18n.load_path << @locale_path unless loaded.include?(expanded)
    I18n.reload!
  end

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end
end
