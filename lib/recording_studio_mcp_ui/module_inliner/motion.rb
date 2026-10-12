# frozen_string_literal: true

module RecordingStudio
  module McpUi
    module ModuleInlinerMotion
      def consume_initializer
        advance
        start = depths
        saw_value = false
        while more? && !initializer_boundary?(start, saw_value)
          saw_value ||= value_token?
          walk_one
        end
      end

      def initializer_boundary?(start, saw_value)
        return false unless depths == start
        return true if [",", ";"].include?(current)

        saw_value && current == "\n"
      end

      def value_token?
        !trivia? && !comment?
      end

      def skip_until(char)
        walk_one until current == char || !more?
      end

      def walk_group(open)
        return unless current == open

        walk_char
        close = { "(" => ")", "{" => "}", "[" => "]" }.fetch(open)
        target = depth_for(open) - 1
        walk_one until depth_for(open) == target || !more?
        walk_char if current == close
      end

      def depth_for(open)
        return @paren if open == "("
        return @bracket if open == "["

        @brace
      end

      def walk_one
        return if walk_comment || walk_string || walk_template || walk_regex

        walk_char
      end

      def copy_span
        start = @index
        yield
        @out << @source[start...@index]
      end

      def walk_char
        note(current)
        track_depth(current)
        advance
      end

      def track_depth(char)
        @brace += 1 if char == "{"
        @brace -= 1 if char == "}"
        @paren += 1 if char == "("
        @paren -= 1 if char == ")"
        @bracket += 1 if char == "["
        @bracket -= 1 if char == "]"
      end

      def regex?
        current == "/" && peek(1) != "/" && peek(1) != "*" && regex_position?
      end

      def regex_position?
        return false unless @word.empty?
        return true if ModuleInliner::REGEX_WORDS.include?(@prev_word.to_s)
        return false if @prev_word

        @prev_char.nil? || ModuleInliner::REGEX_CHARS.include?(@prev_char)
      end

      def note(char)
        return flush_word if char.match?(/\s/)
        return @word << char if char.match?(ModuleInliner::WORD)

        flush_word
        @prev_word = nil if ModuleInliner::REGEX_CHARS.include?(char)
        @prev_char = char
      end

      def flush_word
        return if @word.empty?

        @prev_word = @word.dup
        @word = +""
      end

      def mark_value
        flush_word
        @prev_word = nil
        @prev_char = ")"
      end
    end
  end
end
