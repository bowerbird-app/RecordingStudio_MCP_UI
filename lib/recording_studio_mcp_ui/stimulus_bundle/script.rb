# frozen_string_literal: true

module RecordingStudio
  module McpUi
    module StimulusBundleScript
      TEMPLATE = <<~JS
        (function (root) {
          "use strict";
          var __modules = Object.create(null);
          function __require(id) {
            var module = __modules[id];
            if (!module) throw new Error("Missing widget module: " + id);
            return module;
          }
          function __define(id, factory) {
            var exports = {};
            __modules[id] = exports;
            factory(__require, exports);
          }
          __NOTES__
          __BODY__
          var application = __require(__STIMULUS__).Application.start(root.document && root.document.documentElement);
          __REGISTERS__
          root.Stimulus = application;
        })(window);
      JS

      def wrap(modules)
        # Block form: a replacement string treats \+ and \1 as match tokens.
        TEMPLATE
          .sub("__NOTES__") { notes_js }
          .sub("__BODY__") { modules.map { |entry| define_module(entry) }.join }
          .sub("__STIMULUS__") { JSON.generate(StimulusBundle::STIMULUS) }
          .sub("__REGISTERS__") { modules.filter_map { |entry| register_line(entry) }.join }
      end

      def define_module(entry)
        converted = ModuleInliner.convert(source_for(entry), ids: id_map(entry))
        "__define(#{JSON.generate(entry.id)}, function (__require, exports) {\n#{converted.code}\n});\n"
      end

      def id_map(entry)
        specifiers_for(entry).to_h { |specifier| [specifier, resolve(specifier, entry).id] }
      end

      def register_line(entry)
        return unless entry.name.to_s.match?(%r{\Acontrollers/.+_controller\z})

        identifier = self.class.identifier_for(entry.name)
        "application.register(#{JSON.generate(identifier)}, __require(#{JSON.generate(entry.id)}).default);\n"
      end

      def notes_js
        @notes.uniq.map { |note| "/* #{note} */" }.join("\n")
      end

      def source_for(entry)
        File.read(entry.path.to_s)
      end

      def escape_script(source)
        source.gsub(StimulusBundle::SCRIPT_CLOSE, "<\\/script")
      end
    end
  end
end
