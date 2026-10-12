# frozen_string_literal: true

require "json"
require "recording_studio_mcp_ui/module_inliner/exports"
require "recording_studio_mcp_ui/module_inliner/imports"
require "recording_studio_mcp_ui/module_inliner/literals"
require "recording_studio_mcp_ui/module_inliner/motion"
require "recording_studio_mcp_ui/module_inliner/pairs"
require "recording_studio_mcp_ui/module_inliner/reader"

module RecordingStudio
  module McpUi
    # Rewrites browser ES modules into a classic script body. Packaged widgets
    # cannot fetch modules: the sandbox CSP has no network and only inline scripts.
    class ModuleInliner
      include ModuleInlinerExports
      include ModuleInlinerImports
      include ModuleInlinerLiterals
      include ModuleInlinerMotion
      include ModuleInlinerPairs
      include ModuleInlinerReader

      Result = Struct.new(:code, :specifiers, keyword_init: true)
      REGEX_WORDS = %w[return typeof case delete void throw in of yield await else do].freeze
      REGEX_CHARS = "([,=:![&|?{};~^%<>+-*"
      WORD = /[A-Za-z0-9_$]/

      def self.convert(source, ids: {})
        new(source, ids).convert
      end

      def initialize(source, ids)
        @source = source.to_s
        reset_scan(ids)
      end

      def convert
        scan_module
        Result.new(code: @out, specifiers: @specifiers)
      end

      def module_id(specifier)
        @ids.fetch(specifier, specifier)
      end

      def json(value)
        JSON.generate(value)
      end

      private

      def reset_scan(ids)
        @ids = ids
        @index = 0
        @length = @source.length
        @brace = @paren = @bracket = 0
        @word = +""
        @prev_word = @prev_char = nil
        @out = +""
        @specifiers = []
      end

      def scan_module
        copy_one while more?
      end

      def copy_one
        return write_import if top_level? && keyword?("import") && !dynamic_import?
        return write_export if top_level? && keyword?("export")

        copy_span { walk_one }
      end
    end
  end
end
