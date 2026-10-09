# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Error < StandardError; end
    class DuplicateWidgetError < Error; end
    class UnknownWidgetError < Error; end
    class InvalidWidgetError < Error; end
    class UnauthorizedActionError < Error; end
    class UnknownActionError < Error; end
    class ConflictError < Error; end

    class ValidationError < Error
      attr_reader :errors

      def initialize(message = "Validation failed", errors: {})
        @errors = errors
        super(message)
      end
    end
  end
end
