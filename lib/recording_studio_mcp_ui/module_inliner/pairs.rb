# frozen_string_literal: true

module RecordingStudio
  module McpUi
    module ModuleInlinerPairs
      def read_pairs(&)
        advance
        pairs = []
        pairs << next_pair(&) while pair_pending?
        advance if current == "}"
        pairs
      end

      def pair_pending?
        skip_trivia
        current != "}"
      end

      def next_pair
        pair = yield
        skip_trivia
        advance if current == ","
        pair
      end
    end
  end
end
