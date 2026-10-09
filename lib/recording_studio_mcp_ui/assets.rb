# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Assets
      ENGINE_JS = %w[
        host_bridge.js
        runtime.js
        controllers/editor_controller.js
        boot.js
      ].freeze

      def self.javascript
        ENGINE_JS.map { |relative| read_engine_js(relative) }.join("\n")
      end

      def self.css
        [widget_css, flatpack_css, compiled_host_css].compact.reject(&:blank?).join("\n")
      end

      def self.read_engine_js(relative)
        path = Engine.root.join("app/javascript/recording_studio_mcp_ui", relative)
        raise Error, "Missing JS asset: #{relative}" unless File.exist?(path)

        File.read(path)
      end

      def self.widget_css
        path = Engine.root.join("app/assets/stylesheets/recording_studio_mcp_ui/widget.css")
        File.exist?(path) ? File.read(path) : ""
      end

      def self.flatpack_css
        return unless defined?(FlatPack::Engine)

        %w[flat_pack/variables.css flat_pack/application.css].filter_map do |relative|
          path = FlatPack::Engine.root.join("app/assets/stylesheets", relative)
          File.read(path) if File.exist?(path)
        end.join("\n")
      end

      def self.compiled_host_css
        path = RecordingStudio::MCP_UI.configuration.compiled_css_path
        return if path.blank? || !File.exist?(path)

        File.read(path)
      end
    end
  end
end
