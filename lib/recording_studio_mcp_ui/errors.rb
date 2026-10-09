# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Error < StandardError; end
    class DuplicateWidgetError < Error; end
    class UnknownWidgetError < Error; end
    class InvalidWidgetError < Error; end
    class UnknownActionError < Error; end
  end
end
