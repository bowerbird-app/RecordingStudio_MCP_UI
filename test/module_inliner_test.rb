# frozen_string_literal: true

require "test_helper"

class ModuleInlinerTest < Minitest::Test
  def test_rewrites_imports_exports_comments_and_literals
    result = RecordingStudio::MCP_UI::ModuleInliner.convert(widget_module, ids: { "./parts" => "parts-id" })

    assert_includes result.code, 'const DefaultName = __require("parts-id").default;'
    assert_includes result.code, 'const { one: uno, two } = __require("parts-id");'
    assert_includes result.code, 'const ns = __require("./ns");'
    assert_includes result.code, '__require("./side");'
    assert_includes result.code, 'const { only } = __require("only");'
    assert_includes result.code, "exports.default = "
    assert_includes result.code, "exports.plain = plain;"
    assert_includes result.code, "exports.later = later;"
    assert_includes result.code, "exports.Box = Box;"
    assert_includes result.code, "exports.answer = answer;"
    assert_includes result.code, "exports.extra = extra;"
    assert_includes result.code, "exports.mutable = mutable;"
    assert_includes result.code, "exports.legacy = legacy;"
    assert_includes result.code, "exports.renamed = plain;"
    assert_includes result.code, 'exports.first = __require("parts-id").one;'
    assert_includes result.code, 'import("./later")'
    assert_includes result.code, "1 / 2"
    assert_equal ["./parts", "./ns", "./side", "only", "./parts"], result.specifiers
  end

  def test_reads_an_escaped_module_specifier
    result = RecordingStudio::MCP_UI::ModuleInliner.convert("import foo from \"a\\nb\";\n")

    assert_equal ["anb"], result.specifiers
    assert_includes result.code, '__require("anb").default;'
  end

  def test_rejects_unsupported_exports_and_specifiers
    type_export = assert_raises(RecordingStudio::MCP_UI::Error) do
      RecordingStudio::MCP_UI::ModuleInliner.convert("export type Foo {}\n")
    end
    assert_includes type_export.message, "Unsupported export"

    async_value = assert_raises(RecordingStudio::MCP_UI::Error) do
      RecordingStudio::MCP_UI::ModuleInliner.convert("export async thing() {}\n")
    end
    assert_includes async_value.message, "Unsupported export declaration"

    specifier = assert_raises(RecordingStudio::MCP_UI::Error) do
      RecordingStudio::MCP_UI::ModuleInliner.convert("import foo from 1;\n")
    end
    assert_includes specifier.message, "Expected module specifier"

    identifier = assert_raises(RecordingStudio::MCP_UI::Error) do
      RecordingStudio::MCP_UI::ModuleInliner.convert("import { ;\n")
    end
    assert_includes identifier.message, "Expected identifier"
  end

  private

  def widget_module
    <<~'JS'
      import DefaultName, { one as uno, two } from "./parts";
      import * as ns from "./ns";
      import "./side";
      import { only } from 'only';
      // keep this line
      /* block
         comment */
      export default class Widget extends DefaultName {
        label(name) { return `pre\${name}`; }
      }
      export function plain() { return /[a-z]+/g; }
      export async function later() { return 2; }
      export class Box {}
      export const answer = 1, extra = {
        a: 1
      };
      export let mutable = 2;
      export var legacy = 3;
      export { plain as renamed, Box };
      export { one as first } from "./parts";
      const divided = 1 / 2;
      function dynamic() { return import("./later"); }
    JS
  end
end
