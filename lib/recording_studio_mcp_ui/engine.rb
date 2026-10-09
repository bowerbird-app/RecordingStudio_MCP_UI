# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Engine < ::Rails::Engine
      isolate_namespace RecordingStudio::McpUi

      class << self
        def apply_model_extensions(target)
          apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
        end

        def apply_controller_extensions(target)
          apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
        end

        def load_host_config(app)
          merge_yaml_config(app)
          merge_x_config(app)
        end

        private

        def extensions_for(kind, names)
          hooks = RecordingStudio::MCP_UI.configuration.hooks
          Array(names).flat_map do |name|
            if kind == :model
              hooks.model_extensions_for(name)
            else
              hooks.controller_extensions_for(name)
            end
          end
        end

        def apply_extensions(target, extensions)
          return unless target

          applied = target.instance_variable_get(:@mcp_ui_applied_extensions) || identity_hash

          extensions.flatten.compact.each do |extension|
            next if applied[extension]

            target.class_eval(&extension)
            applied[extension] = true
          end

          target.instance_variable_set(:@mcp_ui_applied_extensions, applied)
        end

        def extension_keys_for(target)
          names = [target.name, target.name&.demodulize].compact.uniq
          names.map(&:to_sym)
        end

        def identity_hash
          {}.compare_by_identity
        end

        def merge_yaml_config(app)
          return unless app.respond_to?(:config_for)

          yaml = app.config_for(:recording_studio_mcp_ui)
          RecordingStudio::MCP_UI.configuration.merge!(yaml) if yaml.respond_to?(:each)
        rescue StandardError
          nil
        end

        def merge_x_config(app)
          xcfg = x_config_for(app)
          return unless xcfg

          RecordingStudio::MCP_UI.configuration.merge!(x_config_hash(xcfg))
        rescue StandardError
          nil
        end

        def x_config_for(app)
          return unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_mcp_ui)

          app.config.x.recording_studio_mcp_ui
        end

        def x_config_hash(xcfg)
          return xcfg.to_h if xcfg.respond_to?(:to_h)

          hash = {}
          xcfg.each_pair { |key, value| hash[key] = value } if xcfg.respond_to?(:each_pair)
          hash
        end
      end

      initializer "recording_studio_mcp_ui.before_initialize", before: "recording_studio_mcp_ui.load_config" do |_app|
        RecordingStudio::MCP_UI.configuration.hooks.run(:before_initialize, self)
      end

      initializer "recording_studio_mcp_ui.load_config" do |app|
        Engine.load_host_config(app)
        RecordingStudio::MCP_UI.configuration.hooks.run(:on_configuration, RecordingStudio::MCP_UI.configuration)
      end

      initializer "recording_studio_mcp_ui.after_initialize", after: "recording_studio_mcp_ui.load_config" do |_app|
        RecordingStudio::MCP_UI.configuration.hooks.run(:after_initialize, self)
      end

      initializer "recording_studio_mcp_ui.apply_model_extensions" do
        config.to_prepare do
          next unless defined?(ActiveRecord::Base)

          ActiveRecord::Base.descendants.each do |model|
            next if model.abstract_class?

            RecordingStudio::MCP_UI::Engine.apply_model_extensions(model)
          end
        end
      end

      initializer "recording_studio_mcp_ui.apply_controller_extensions" do
        config.to_prepare do
          next unless defined?(ActionController::Base)

          ActionController::Base.descendants.each do |controller|
            RecordingStudio::MCP_UI::Engine.apply_controller_extensions(controller)
          end
        end
      end
    end
  end
end
