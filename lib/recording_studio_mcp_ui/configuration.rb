# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Configuration
      attr_accessor :action_executor, :visibility_checker, :compiled_css_path
      attr_reader :hooks, :registry

      def initialize
        @hooks = RecordingStudio::Hooks.new
        @registry = Registry.new
        @action_executor = nil
        @visibility_checker = nil
        @compiled_css_path = nil
      end

      def to_h
        {
          action_executor: !action_executor.nil?,
          visibility_checker: !visibility_checker.nil?,
          compiled_css_path: compiled_css_path,
          hooks_registered: hooks.registered_counts
        }
      end

      def merge!(hash)
        return unless hash.respond_to?(:each)

        hash.each do |key, value|
          setter = "#{key}="
          public_send(setter, value) if respond_to?(setter)
        end
      end
    end
  end
end
