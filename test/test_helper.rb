# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
begin
  require "minitest/mock"
rescue LoadError
  # Minitest 6 extracts Object#stub into the minitest-mock gem.
end
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "active_support/time"
Time.zone ||= "UTC"

unless defined?(RecordingStudioMcpUiTestApp)
  class RecordingStudioMcpUiTestApp < Rails::Application
    config.eager_load = false
    config.secret_key_base = "test"
    config.hosts.clear
    config.logger = Logger.new(File::NULL)
  end
  RecordingStudioMcpUiTestApp.initialize! unless Rails.application
end

require "recording_studio_mcp_ui"
