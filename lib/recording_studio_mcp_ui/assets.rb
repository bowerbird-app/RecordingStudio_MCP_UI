# frozen_string_literal: true

require "pathname"

module RecordingStudio
  module McpUi
    class Assets
      SDK_JS = "vendor/ext-apps.iife.js"
      RUNTIME_JS = %w[
        runtime.js
        controllers/editor_controller.js
        boot.js
      ].freeze

      def self.javascript
        escape_script([read_engine_js(SDK_JS), widget_script, runtime].join("\n"))
      end

      def self.runtime
        RUNTIME_JS.map { |relative| read_engine_js(relative) }.join("\n")
      end

      def self.widget_script
        read_host_script(RecordingStudio::MCP_UI.configuration.widget_script_path)
      end

      def self.read_host_script(path)
        return "" if path.blank?

        file = Pathname.new(path)
        file.file? ? file.read : ""
      end

      def self.escape_script(source)
        source.gsub(%r{</script}i, "<\\/script")
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
        Array(RecordingStudio::MCP_UI.configuration.compiled_css_path).filter_map do |path|
          next if path.blank?

          file = Pathname.new(path)
          next unless file.file?

          file.read
        end.join("\n").presence
      end
    end
  end
end
