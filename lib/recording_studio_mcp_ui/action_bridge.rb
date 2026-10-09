# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class ActionRequest
      attr_reader :widget, :alias_name, :api_action, :arguments, :access_grant, :revision

      def initialize(**attributes)
        @widget = attributes.fetch(:widget)
        @alias_name = attributes.fetch(:alias_name)
        @api_action = attributes.fetch(:api_action)
        @arguments = attributes.fetch(:arguments)
        @access_grant = attributes[:access_grant]
        @revision = attributes[:revision]
      end
    end

    class ActionResult
      attr_reader :ok, :data, :errors, :context_update, :error

      def initialize(**attributes)
        @ok = attributes.fetch(:ok)
        @data = attributes[:data]
        @errors = attributes[:errors] || {}
        @context_update = attributes[:context_update]
        @error = attributes[:error]
      end

      def self.success(data:, context_update: nil)
        new(ok: true, data: data, context_update: context_update)
      end

      def self.failure(error:, errors: {}, data: nil)
        new(ok: false, error: error, errors: errors, data: data)
      end

      def to_h
        {
          ok: ok,
          data: data,
          errors: errors,
          contextUpdate: context_update,
          error: error
        }.compact
      end
    end

    class ActionBridge
      def initialize(widget)
        @widget = widget
      end

      def execute(alias_name, arguments: {}, access_grant: nil, revision: nil)
        request = request_for(alias_name, arguments, access_grant, revision)
        executor = RecordingStudio::MCP_UI.configuration.action_executor
        raise UnauthorizedActionError, "No action executor is configured" unless executor

        normalize(executor.call(request))
      end

      private

      def request_for(alias_name, arguments, access_grant, revision)
        ActionRequest.new(
          widget: @widget,
          alias_name: alias_name.to_s,
          api_action: @widget.action_for(alias_name),
          arguments: arguments,
          access_grant: access_grant,
          revision: revision
        )
      end

      def normalize(result)
        return result if result.is_a?(ActionResult)
        return from_hash(result.to_h) if result.respond_to?(:to_h)

        ActionResult.success(data: result)
      end

      def from_hash(hash)
        return success_from(hash) if hash[:ok] == true || hash["ok"] == true

        failure_from(hash)
      end

      def success_from(hash)
        ActionResult.success(
          data: hash[:data] || hash["data"],
          context_update: hash[:context_update] || hash["contextUpdate"]
        )
      end

      def failure_from(hash)
        ActionResult.failure(
          error: hash[:error] || hash["error"] || "Action failed",
          errors: hash[:errors] || hash["errors"] || {},
          data: hash[:data] || hash["data"]
        )
      end
    end
  end
end
