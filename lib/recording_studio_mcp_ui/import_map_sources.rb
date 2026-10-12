# frozen_string_literal: true

require "pathname"

module RecordingStudio
  module McpUi
    # Reads package pins and directory pins from a host import map.
    class ImportMapSources
      def self.entries(app)
        new(app).entries
      end

      def initialize(app)
        @app = app
        @map = app.importmap
      end

      def entries
        found = {}
        each_package { |name, logical| found[name] = entry_for(name, logical) }
        each_directory { |name, file| found[name] = local_entry(name, file) }
        found.values
      end

      private

      def each_package
        return unless @map.respond_to?(:packages)

        @map.packages.each do |name, mapped|
          logical = mapped.respond_to?(:path) ? mapped.path : mapped
          yield name.to_s, logical.to_s
        end
      end

      def each_directory
        return unless @map.respond_to?(:directories)

        @map.directories.each_value do |mapping|
          root = directory_root(mapping)
          next unless root&.directory?

          javascript_files(root).each do |file|
            yield module_name(file.relative_path_from(root), directory_under(mapping)), file.to_s
          end
        end
      end

      def entry_for(name, logical)
        return ImportMapCatalog::Entry.new(name: name, path: logical, remote: true) if remote_url?(logical)

        local_entry(name, resolve_logical(logical))
      end

      def local_entry(name, path)
        ImportMapCatalog::Entry.new(name: name, path: path, remote: false)
      end

      def remote_url?(logical)
        logical.to_s.match?(%r{\Ahttps?://}i)
      end

      def resolve_logical(logical)
        path = Pathname.new(logical.to_s)
        return path.to_s if path.absolute? && path.file?

        asset_file(logical.to_s)
      end

      def asset_file(logical)
        return unless @app.respond_to?(:assets) && @app.assets.respond_to?(:load_path)

        found = @app.assets.load_path.find(logical)
        file = found.respond_to?(:path) ? found.path : found
        file.to_s if file && File.file?(file.to_s)
      end

      def directory_root(mapping)
        dir = mapping.respond_to?(:dir) ? mapping.dir : mapping[:dir]
        path = Pathname.new(dir.to_s)
        return path if path.absolute?

        app_root&.join(path)
      end

      def directory_under(mapping)
        mapping.respond_to?(:under) ? mapping.under : mapping[:under]
      end

      def app_root
        return Rails.root if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        return @app.root if @app.respond_to?(:root)

        nil
      end

      def javascript_files(root)
        Dir[root.join("**/*.{js,jsm}")].map { |file| Pathname.new(file) }.select(&:file?)
      end

      def module_name(relative, under)
        stem = relative.to_s.sub(/\.(?:js|jsm)\z/, "").sub(%r{(?:/|\A)index\z}, "")
        stem = nil if stem.empty?
        [under, stem].compact.reject(&:empty?).join("/")
      end
    end
  end
end
