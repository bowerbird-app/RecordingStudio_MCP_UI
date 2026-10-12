# frozen_string_literal: true

module RecordingStudio
  module McpUi
    module ModuleInlinerExports
      def write_export
        advance_keyword("export")
        skip_trivia
        return write_default_export if keyword?("default")
        return write_named_declaration if declaration_export?
        return write_binding_export if binding_export?
        return write_name_export if current == "{"

        raise Error, "Unsupported export in widget module"
      end

      def write_default_export
        advance_keyword("default")
        skip_trivia
        @out << "exports.default = "
      end

      def declaration_export?
        keyword?("async") || keyword?("function") || keyword?("class")
      end

      def binding_export?
        keyword?("const") || keyword?("let") || keyword?("var")
      end

      def write_named_declaration
        start = @index
        consume_keyword("async") if keyword?("async")
        skip_trivia
        kind = declaration_kind
        advance_keyword(kind)
        skip_trivia
        name = read_identifier
        finish_declaration(kind)
        @out << @source[start...@index]
        @out << "\nexports.#{name} = #{name};\n"
      end

      def declaration_kind
        return "function" if keyword?("function")
        return "class" if keyword?("class")

        raise Error, "Unsupported export declaration in widget module"
      end

      def finish_declaration(kind)
        skip_trivia
        walk_group("(") if kind == "function" && current == "("
        skip_until("{") if kind == "class"
        skip_trivia
        walk_group("{") if current == "{"
      end

      def write_binding_export
        start = @index
        names = read_binding_names
        @out << @source[start...@index]
        names.each { |name| @out << "\nexports.#{name} = #{name};" }
        @out << "\n"
      end

      def read_binding_names
        advance_keyword(binding_keyword)
        names = []
        names << one_binding while names.empty? || current == ","
        skip_semicolon
        names
      end

      def one_binding
        advance if current == ","
        skip_trivia
        name = read_identifier
        skip_trivia
        consume_initializer if current == "="
        skip_trivia
        name
      end

      def binding_keyword
        return "const" if keyword?("const")
        return "let" if keyword?("let")

        "var"
      end

      def write_name_export
        pairs = read_export_pairs
        from = export_from
        pairs.each { |local, exported| @out << export_pair(local, exported, from) }
      end

      def export_pair(local, exported, from)
        return "exports.#{exported} = __require(#{json(module_id(from))}).#{local};\n" if from

        "exports.#{exported} = #{local};\n"
      end

      def export_from
        skip_trivia
        return unless keyword?("from")

        advance_keyword("from")
        skip_trivia
        specifier = read_string
        @specifiers << specifier
        skip_semicolon
        specifier
      end

      def read_export_pairs
        read_pairs do
          local = read_identifier
          [local, read_alias(local)]
        end
      end
    end
  end
end
