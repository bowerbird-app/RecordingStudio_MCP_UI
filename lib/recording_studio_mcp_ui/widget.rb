# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Widget
      MODES = %i[read edit].freeze
      IDENTIFIER = /\A[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+\z/
      ACTION_ALIAS = /\A[a-z][a-z0-9_]*\z/
      API_ACTION = /\A[a-z][a-z0-9_.]*\z/
      MIME_TYPE = "text/html;profile=mcp-app"

      attr_reader :id, :component, :description, :mode, :version, :actions, :available_if

      def initialize(**attributes)
        @id = attributes.fetch(:id).to_s
        @component = attributes.fetch(:component)
        @description = attributes[:description]
        @mode = (attributes[:mode] || :read).to_sym
        @version = (attributes[:version] || "1.0.0").to_s
        @actions = normalize_actions(attributes[:actions])
        @available_if = attributes[:available_if]
        validate!
      end

      def resource_uri
        "ui://#{id.tr('.', '/')}"
      end

      def action_for(alias_name)
        actions.fetch(alias_name.to_s)
      rescue KeyError
        raise UnknownActionError, "Widget #{id.inspect} has no action #{alias_name.inspect}"
      end

      def permits_action?(alias_name)
        actions.key?(alias_name.to_s)
      end

      def metadata
        {
          id: id,
          uri: resource_uri,
          description: description,
          mode: mode,
          version: version,
          actions: actions.dup,
          mime_type: MIME_TYPE
        }
      end

      def same_contract?(other)
        other.id == id &&
          other.description == description &&
          other.mode == mode &&
          other.version == version &&
          other.actions == actions &&
          other.component_name == component_name
      end

      def component_name
        component.respond_to?(:name) ? component.name.to_s : component.to_s
      end

      private

      def normalize_actions(value)
        Hash(value).each_with_object({}) do |(alias_name, api_action), memo|
          memo[alias_name.to_s] = api_action.to_s
        end
      end

      def validate!
        validate_identity!
        validate_available_if!
        validate_actions!
      end

      def validate_identity!
        raise InvalidWidgetError, "Widget id is invalid: #{id.inspect}" unless id.match?(IDENTIFIER)
        raise InvalidWidgetError, "Widget #{id} requires a component class" if component.nil?
        raise InvalidWidgetError, "Widget mode must be :read or :edit" unless MODES.include?(mode)
        raise InvalidWidgetError, "Widget version is required" if version.blank?
      end

      def validate_available_if!
        return if available_if.nil? || available_if.respond_to?(:call)

        raise InvalidWidgetError, "available_if must be callable"
      end

      def validate_actions!
        actions.each do |alias_name, api_action|
          raise InvalidWidgetError, "Invalid action alias: #{alias_name.inspect}" unless alias_name.match?(ACTION_ALIAS)
          raise InvalidWidgetError, "Invalid API action: #{api_action.inspect}" unless api_action.match?(API_ACTION)
        end
      end
    end
  end
end
