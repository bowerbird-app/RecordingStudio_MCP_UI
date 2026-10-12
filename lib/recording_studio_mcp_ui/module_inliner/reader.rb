# frozen_string_literal: true

module RecordingStudio
  module McpUi
    module ModuleInlinerReader
      def top_level?
        @brace.zero? && @paren.zero? && @bracket.zero?
      end

      def depths
        [@brace, @paren, @bracket]
      end

      def skip_trivia
        while more? && (trivia? || comment?)
          comment? ? walk_comment : advance
        end
      end

      def skip_semicolon
        skip_trivia
        advance if current == ";"
      end

      def trivia?
        current.match?(/\s/)
      end

      def comment?
        current == "/" && ["/", "*"].include?(peek(1))
      end

      def line_comment?
        peek(1) == "/"
      end

      def string?
        ["\"", "'"].include?(current)
      end

      def dynamic_import?
        saved = @index
        advance_keyword("import")
        skip_spaces
        dynamic = current == "("
        @index = saved
        dynamic
      end

      def skip_spaces
        advance while more? && current.match?(/\s/)
      end

      def keyword?(word)
        @source[@index, word.length] == word && !word_follower?(word.length)
      end

      def word_follower?(offset)
        follower = @source[@index + offset]
        follower&.match?(ModuleInliner::WORD)
      end

      def advance_keyword(word)
        raise Error, "Expected #{word} in widget module" unless keyword?(word)

        advance(word.length)
      end

      def consume_keyword(word)
        advance(word.length) if keyword?(word)
      end

      def read_identifier
        skip_trivia
        raise Error, "Expected identifier in widget module" unless current&.match?(ModuleInliner::WORD)

        start = @index
        advance while more? && current.match?(ModuleInliner::WORD)
        @source[start...@index]
      end

      def read_string
        quote = current
        raise Error, "Expected module specifier" unless ["\"", "'"].include?(quote)

        advance
        value = +""
        value << read_string_char until !more? || current == quote
        advance if current == quote
        mark_value
        value
      end

      def read_string_char
        if current == "\\"
          advance
          char = current
          advance
          return char.to_s
        end

        char = current
        advance
        char
      end

      def more?
        @index < @length
      end

      def current
        @source[@index]
      end

      def peek(offset)
        @source[@index + offset]
      end

      def advance(count = 1)
        @index += count
      end
    end
  end
end
