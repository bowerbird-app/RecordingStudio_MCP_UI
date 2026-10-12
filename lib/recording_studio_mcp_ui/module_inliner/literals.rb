# frozen_string_literal: true

module RecordingStudio
  module McpUi
    module ModuleInlinerLiterals
      def walk_comment
        return unless comment?

        line_comment? ? walk_line_comment : walk_block_comment
        :walked
      end

      def walk_line_comment
        advance until !more? || current == "\n"
        advance if current == "\n"
      end

      def walk_block_comment
        advance(2)
        advance until !more? || (current == "*" && peek(1) == "/")
        advance(2) if current == "*"
      end

      def walk_string
        return unless string?

        quote = current
        advance
        until !more? || current == quote
          advance(2) if current == "\\"
          advance
        end
        advance if current == quote
        mark_value
        :walked
      end

      def walk_template
        return unless current == "`"

        advance
        walk_template_piece until !more? || current == "`"
        advance if current == "`"
        mark_value
        :walked
      end

      def walk_template_piece
        if current == "\\"
          advance(2)
        elsif current == "$" && peek(1) == "{"
          walk_template_expression
        else
          advance
        end
      end

      def walk_template_expression
        advance(2)
        @brace += 1
        floor = @brace - 1
        walk_one until @brace == floor || !more?
      end

      def walk_regex
        return unless regex?

        advance
        walk_regex_piece until !more? || current == "/"
        advance if current == "/"
        advance while more? && current.match?(/[a-z]/)
        mark_value
        :walked
      end

      def walk_regex_piece
        if current == "\\"
          advance(2)
        elsif current == "["
          walk_regex_class
        else
          advance
        end
      end

      def walk_regex_class
        advance
        until !more? || current == "]"
          advance(2) if current == "\\"
          advance
        end
        advance if current == "]"
      end
    end
  end
end
