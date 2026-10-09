# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudio::MCP_UI::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(compiled_css_path: "/tmp/app.css")

    assert_equal "/tmp/app.css", @configuration.compiled_css_path
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", compiled_css_path: "/tmp/x.css")

    refute_respond_to @configuration, :unknown_key
    assert_equal "/tmp/x.css", @configuration.compiled_css_path
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h
    @configuration.merge!(nil)
    assert_nil @configuration.compiled_css_path
    assert_equal original[:compiled_css_path], @configuration.compiled_css_path if original[:compiled_css_path]
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
    refute result.key?(:action_executor)
    refute result.key?(:visibility_checker)
  end

  def test_configure_without_block_is_safe
    RecordingStudio::MCP_UI.configure

    assert_kind_of RecordingStudio::MCP_UI::Configuration, RecordingStudio::MCP_UI.configuration
  end
end
