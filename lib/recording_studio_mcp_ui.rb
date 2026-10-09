# frozen_string_literal: true

require "recording_studio"
require "view_component"
require "recording_studio_mcp_ui/version"
require "recording_studio_mcp_ui/errors"
require "recording_studio_mcp_ui/widget"
require "recording_studio_mcp_ui/registry"
require "recording_studio_mcp_ui/configuration"
require "recording_studio_mcp_ui/renderer"
require "recording_studio_mcp_ui/assets"
require "recording_studio_mcp_ui/document"
require "recording_studio_mcp_ui/packager"
require "recording_studio_mcp_ui/visibility"
require "recording_studio_mcp_ui/engine"
require "recording_studio_mcp_ui/capabilities/example"

module RecordingStudio
  module McpUi
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration) if block_given?
        configuration
      end

      def register(id, **attributes)
        configuration.registry.register(id, **attributes)
      end

      def find(id)
        configuration.registry.find(id)
      end

      def list(**filters)
        configuration.registry.list(**filters)
      end

      def render(id, data: {}, **component_options)
        Renderer.new(find(id)).render(data: data, **component_options)
      end

      def package(id, data: {}, **component_options)
        Packager.new(find(id)).package(data: data, **component_options)
      end

      def available?(id, access_grant: nil, api: :public, version: nil)
        Visibility.new(find(id)).available?(access_grant: access_grant, api: api, version: version)
      end

      def reset_registry!
        configuration.registry.reset!
      end
    end
  end

  MCP_UI = McpUi
end
