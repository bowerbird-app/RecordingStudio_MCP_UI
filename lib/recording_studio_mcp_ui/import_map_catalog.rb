# frozen_string_literal: true

require "pathname"
require "recording_studio_mcp_ui/import_map_sources"

module RecordingStudio
  module McpUi
    # Local files and remote URLs pinned by the host import map.
    class ImportMapCatalog
      Entry = Struct.new(:name, :path, :remote, keyword_init: true) do
        def id
          name.presence || path.to_s
        end

        def local?
          !remote && path.present? && File.file?(path.to_s)
        end
      end

      def self.from_rails
        app = defined?(Rails) ? Rails.application : nil
        return new([]) unless import_map?(app)

        from_app(app)
      end

      def self.from_app(app)
        new(ImportMapSources.entries(app))
      end

      def self.import_map?(app)
        app.respond_to?(:importmap) && app.importmap
      end

      def initialize(entries)
        @entries = Array(entries)
        @by_name = @entries.to_h { |entry| [entry.name, entry] }
      end

      def find(name)
        @by_name[name]
      end

      def id_for_path(path)
        expanded = File.expand_path(path.to_s)
        match = @entries.find { |entry| entry.local? && File.expand_path(entry.path.to_s) == expanded }
        match&.name
      end

      def controller_entries
        @entries.select { |entry| entry.name.to_s.match?(%r{\Acontrollers/.+_controller\z}) }
      end

      def empty?
        @entries.empty?
      end

      def fingerprint
        @entries.map { |entry| fingerprint_for(entry) }
      end

      def fingerprint_for(entry)
        [entry.name, entry.path.to_s, entry.remote, file_stamp(entry)]
      end

      def file_stamp(entry)
        return unless entry.local?

        stat = File.stat(entry.path.to_s)
        [stat.mtime.to_i, stat.size]
      end
    end
  end
end
