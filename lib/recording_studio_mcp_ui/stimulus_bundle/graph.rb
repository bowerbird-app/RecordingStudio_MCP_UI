# frozen_string_literal: true

module RecordingStudio
  module McpUi
    module StimulusBundleGraph
      def missing_stimulus
        return "" if @configuration.stimulus_controllers.nil? && @catalog.controller_entries.empty?

        pin = StimulusBundle::STIMULUS
        "/* skipped #{pin}: import #{pin.inspect} is not in the import map */\n"
      end

      def selectable
        @catalog.controller_entries.select { |entry| wanted?(entry) && keep(entry) }
      end

      def wanted?(entry)
        choice = @configuration.stimulus_controllers
        return true if choice.nil?

        names = Array(choice)
        names.include?(entry.name) || names.include?(self.class.identifier_for(entry.name))
      end

      def keep(entry)
        return note_unusable(entry) unless entry.local?

        problem = rejection(entry, [])
        return true if problem.nil?

        @notes << "skipped #{entry.name}: #{problem}"
        false
      end

      def note_unusable(entry)
        @notes << "skipped #{entry.name}: #{reason_for(entry, entry.name)}"
        nil
      end

      def rejection(entry, stack)
        return if stack.include?(entry.id)

        stack += [entry.id]
        specifiers_for(entry).each do |specifier|
          child = resolve(specifier, entry)
          return reason_for(child, specifier) unless child.local?

          found = rejection(child, stack)
          return found if found
        end
        nil
      end

      def reason_for(entry, specifier)
        if entry&.remote
          "import #{specifier.inspect} is a remote URL, and the widget CSP does not allow network"
        else
          "import #{specifier.inspect} is not in the import map"
        end
      end

      def closure_for(stimulus, chosen)
        group = {}
        gather(stimulus, group, [])
        chosen.each { |entry| gather(entry, group, []) }
        order(group)
      end

      def gather(entry, group, stack)
        return group if group.key?(entry.id) || stack.include?(entry.id)
        return unless entry&.local?

        stack += [entry.id]
        return unless dependencies_of(entry).all? { |child| gather(child, group, stack) }

        group[entry.id] = entry
        group
      end

      def dependencies_of(entry)
        specifiers_for(entry).map { |specifier| resolve(specifier, entry) }
      end

      def specifiers_for(entry)
        @specifiers ||= {}
        @specifiers[entry.id] ||= ModuleInliner.convert(source_for(entry)).specifiers
      end

      def resolve(specifier, entry)
        return relative_entry(specifier, entry) if specifier.start_with?(".")

        @catalog.find(specifier) || ImportMapCatalog::Entry.new(name: specifier, path: nil, remote: false)
      end

      def relative_entry(specifier, entry)
        expanded = expanded_relative(specifier, entry)
        name = @catalog.id_for_path(expanded)
        return @catalog.find(name) if name

        ImportMapCatalog::Entry.new(name: expanded, path: expanded, remote: false)
      end

      def expanded_relative(specifier, entry)
        base = File.expand_path(specifier, File.dirname(entry.path.to_s))
        return base if File.file?(base)
        return "#{base}.js" if File.file?("#{base}.js")

        index = File.join(base, "index.js")
        File.file?(index) ? index : "#{base}.js"
      end

      def order(group)
        ordered = []
        seen = {}
        visit = lambda do |entry|
          return if seen[entry.id]

          seen[entry.id] = true
          dependencies_of(entry).each { |child| visit.call(child) if group.key?(child.id) }
          ordered << entry
        end
        group.each_value { |entry| visit.call(entry) }
        ordered
      end
    end
  end
end
