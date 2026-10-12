# frozen_string_literal: true

module RecordingStudio
  module McpUi
    module ModuleInlinerImports
      def write_import
        advance_keyword("import")
        skip_trivia
        clause = read_import_clause
        @specifiers << clause.fetch(:from)
        @out << import_bindings(clause)
        skip_semicolon
      end

      def read_import_clause
        clause = { default: nil, namespace: nil, named: [], from: nil }
        read_import_bindings(clause)
        clause[:from] = clause[:from] || read_from_specifier
        skip_trivia
        clause
      end

      def read_import_bindings(clause)
        return read_grouped_import(clause) if grouped_import?

        clause[:default] = read_identifier
        read_import_tail(clause)
      end

      def grouped_import?
        ["{", "*", "\"", "'"].include?(current)
      end

      def read_grouped_import(clause)
        case current
        when "{" then clause[:named] = read_name_pairs
        when "*" then clause[:namespace] = read_namespace
        else clause[:from] = read_string
        end
      end

      def read_import_tail(clause)
        skip_trivia
        return unless current == ","

        advance
        skip_trivia
        current == "*" ? clause[:namespace] = read_namespace : clause[:named] = read_name_pairs
      end

      def read_from_specifier
        skip_trivia
        advance_keyword("from")
        skip_trivia
        read_string
      end

      def read_namespace
        advance while current != "*" && more?
        advance
        skip_trivia
        advance_keyword("as")
        skip_trivia
        read_identifier
      end

      def read_name_pairs
        read_pairs { read_alias_pair }
      end

      def read_alias_pair
        imported = read_identifier
        skip_trivia
        return [imported, read_alias(imported)] if keyword?("as")

        [imported, imported]
      end

      def read_alias(fallback)
        skip_trivia
        return fallback unless keyword?("as")

        advance_keyword("as")
        skip_trivia
        read_identifier
      end

      def import_bindings(clause)
        id = json(module_id(clause.fetch(:from)))
        lines = binding_lines(clause, id)
        lines = ["__require(#{id});"] if lines.empty?
        "#{lines.join("\n")}\n"
      end

      def binding_lines(clause, id)
        lines = []
        lines << default_import(clause[:default], id) if clause[:default]
        lines << "const #{clause[:namespace]} = __require(#{id});" if clause[:namespace]
        lines << named_import(clause[:named], id) if clause[:named].any?
        lines
      end

      def default_import(name, id)
        "const #{name} = __require(#{id}).default;"
      end

      def named_import(pairs, id)
        bindings = pairs.map { |imported, local| imported == local ? imported : "#{imported}: #{local}" }
        "const { #{bindings.join(', ')} } = __require(#{id});"
      end
    end
  end
end
