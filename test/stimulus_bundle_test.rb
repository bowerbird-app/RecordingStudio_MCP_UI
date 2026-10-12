# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "tmpdir"

class StimulusBundleTest < Minitest::Test
  FIXTURES = File.expand_path("fixtures/widget_modules", __dir__)

  def setup
    @configuration = RecordingStudio::MCP_UI::Configuration.new
    RecordingStudio::MCP_UI::StimulusBundle.reset_cache!
  end

  def teardown
    RecordingStudio::MCP_UI::StimulusBundle.reset_cache!
  end

  def test_opt_out_inlines_nothing
    @configuration.stimulus_controllers = false

    assert_equal "", bundle_for(@configuration, catalog)
  end

  def test_false_is_not_treated_as_an_empty_list
    @configuration.merge!(stimulus_controllers: false)

    assert_equal false, @configuration.stimulus_controllers
  end

  def test_string_choice_limits_controllers
    @configuration.stimulus_controllers = "demo--echo"
    source = bundle_for(@configuration, catalog)

    assert_includes source, 'application.register("demo--echo"'
    refute_includes source, 'application.register("demo--picker"'
    assert_javascript source
  end

  def test_bundle_registers_local_controllers_in_a_classic_script
    source = bundle_for(@configuration, catalog)
    registered = run_bundle(source)

    assert_includes registered.fetch("keys"), "demo--echo"
    assert_includes registered.fetch("keys"), "demo--picker"
    refute_includes registered.fetch("keys"), "demo--remote"
    assert_includes source, 'skipped controllers/demo/remote_controller: import "@tiptap/core" is a remote URL'
    assert_includes source,
                    "skipped controllers/demo/missing_controller: import \"demo/missing\" is not in the import map"
    assert_equal "Item Ada", registered.fetch("copy")
  end

  def test_reorder_of_static_imports_is_not_required_for_registration
    source = bundle_for(@configuration, catalog)

    assert source.index("__define(\"demo/copy\"") < source.index("__define(\"controllers/demo/picker_controller\"")
  end

  def test_missing_stimulus_with_no_controllers_stays_empty
    empty = RecordingStudio::MCP_UI::ImportMapCatalog.new([])

    assert_equal "", bundle_for(@configuration, empty)
    assert_predicate empty, :empty?
  end

  def test_missing_stimulus_is_reported_when_controllers_were_requested
    @configuration.stimulus_controllers = ["demo--echo"]
    source = bundle_for(@configuration, RecordingStudio::MCP_UI::ImportMapCatalog.new([]))

    assert_includes source, 'skipped @hotwired/stimulus: import "@hotwired/stimulus" is not in the import map'
  end

  def test_remote_controller_pin_is_skipped
    remote = RecordingStudio::MCP_UI::ImportMapCatalog::Entry.new(
      name: "controllers/demo/cdn_controller",
      path: "https://example.test/cdn.js",
      remote: true
    )
    source = bundle_for(@configuration, RecordingStudio::MCP_UI::ImportMapCatalog.new([
                                                                                        entry("@hotwired/stimulus",
                                                                                              "stimulus.js"),
                                                                                        remote
                                                                                      ]))

    assert_includes source, "skipped controllers/demo/cdn_controller:"
    assert_includes source, "remote URL"
    refute_includes source, 'application.register("demo--cdn"'
  end

  def test_relative_imports_resolve_extensions_index_files_and_pins
    Dir.mktmpdir do |dir|
      helper = write_relative_modules(dir)
      built = relative_catalog(dir, helper)
      source = bundle_for(@configuration, built)

      assert_relative_bundle(source, built, helper)
    end
  end

  def test_from_rails_resolves_logical_assets_and_relative_directories
    Dir.mktmpdir { |dir| assert_host_import_map(dir) }
  end

  def test_directories_override_packages_and_name_modules_like_importmap
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "tabs_controller.js"), File.read(File.join(FIXTURES, "echo_controller.js")))
      File.write(File.join(dir, "index.js"), "export const marker = true\n")
      mapping = Struct.new(:dir, :under, :path).new(dir, "controllers/flat_pack", "ignored")
      packages = {
        "@hotwired/stimulus" => Struct.new(:path).new(File.join(FIXTURES, "stimulus.js")),
        "controllers/flat_pack/tabs_controller" => Struct.new(:path).new(File.join(FIXTURES, "remote_controller.js"))
      }
      map = Struct.new(:packages, :directories).new(packages, { dir => mapping })
      app = Struct.new(:importmap, :assets).new(map, Struct.new(:load_path).new(asset_load_path))
      built = RecordingStudio::MCP_UI::ImportMapCatalog.from_app(app)

      tabs = built.find("controllers/flat_pack/tabs_controller")
      assert_equal File.join(dir, "tabs_controller.js"), tabs.path
      assert_equal "controllers/flat_pack", built.find("controllers/flat_pack").name
      source = bundle_for(@configuration, built)
      assert_includes source, 'application.register("flat-pack--tabs"'
      refute_includes source, "remote URL"
    end
  end

  class BundleComponent < ViewComponent::Base
    def initialize(data:)
      super()
      @data = data
    end

    def call
      %(<p>#{ERB::Util.html_escape(@data['title'])}</p>).html_safe
    end
  end

  def test_package_inlines_the_bundle_before_boot
    configuration = RecordingStudio::MCP_UI.configuration
    original_controllers = configuration.stimulus_controllers
    RecordingStudio::MCP_UI.reset_registry!
    RecordingStudio::MCP_UI.register("projects.preview", component: BundleComponent, description: "card")
    configuration.stimulus_controllers = ["demo--echo"]
    RecordingStudio::MCP_UI::StimulusBundle.reset_cache!

    document = RecordingStudio::MCP_UI::ImportMapCatalog.stub(:from_rails, catalog) do
      RecordingStudio::MCP_UI.package("projects.preview", data: { title: "Beach House" })
    end

    html = document.html
    bundle_at = html.index('application.register("demo--echo"')
    boot_at = html.index("data-controller~='mcp-editor'")
    refute_nil bundle_at
    refute_nil boot_at
    assert bundle_at < boot_at
  ensure
    configuration.stimulus_controllers = original_controllers if configuration
    RecordingStudio::MCP_UI::StimulusBundle.reset_cache!
    RecordingStudio::MCP_UI.reset_registry!
  end

  private

  def catalog
    RecordingStudio::MCP_UI::ImportMapCatalog.new([
                                                    entry("@hotwired/stimulus", "stimulus.js"),
                                                    entry("demo/copy", "copy.js"),
                                                    entry("controllers/demo/echo_controller", "echo_controller.js"),
                                                    entry("controllers/demo/picker_controller", "picker_controller.js"),
                                                    entry("controllers/demo/remote_controller", "remote_controller.js"),
                                                    entry("controllers/demo/missing_controller",
                                                          "missing_controller.js"),
                                                    RecordingStudio::MCP_UI::ImportMapCatalog::Entry.new(
                                                      name: "@tiptap/core",
                                                      path: "https://example.test/tiptap.js",
                                                      remote: true
                                                    )
                                                  ])
  end

  def entry(name, file)
    file_entry(name, File.join(FIXTURES, file))
  end

  def file_entry(name, path)
    RecordingStudio::MCP_UI::ImportMapCatalog::Entry.new(name: name, path: path, remote: false)
  end

  def write_relative_modules(dir)
    helper = File.join(dir, "helper.js")
    File.write(helper, "export function helper(name) { return \"Hi \" + name }\n")
    FileUtils.mkdir_p(File.join(dir, "kit"))
    File.write(File.join(dir, "kit/index.js"), "export const marker = \"kit\"\n")
    write_controller(dir, "rel_controller.js", 'import { helper } from "./helper"', "return helper(\"Ada\")")
    write_controller(dir, "index_controller.js", 'import { marker } from "./kit"', "return marker")
    write_controller(dir, "exact_controller.js", 'import { helper } from "./helper.js"', "")
    write_controller(dir, "gone_controller.js", 'import { gone } from "./missing"', "")
    helper
  end

  def write_controller(dir, file, import_line, body)
    File.write(File.join(dir, file), <<~JS)
      import { Controller } from "@hotwired/stimulus"
      #{import_line}
      export default class extends Controller { greet() { #{body} } }
    JS
  end

  def relative_catalog(dir, helper)
    names = %w[rel index exact gone]
    entries = names.map do |name|
      file_entry("controllers/demo/#{name}_controller", File.join(dir, "#{name}_controller.js"))
    end
    RecordingStudio::MCP_UI::ImportMapCatalog.new([
                                                    entry("@hotwired/stimulus", "stimulus.js"),
                                                    file_entry("demo/helper", helper),
                                                    *entries
                                                  ])
  end

  def assert_relative_bundle(source, built, helper)
    assert_includes source, '__define("demo/helper"'
    assert_includes source, 'application.register("demo--rel"'
    assert_includes source, 'application.register("demo--index"'
    assert_includes source, 'application.register("demo--exact"'
    refute_includes source, 'application.register("demo--gone"'
    assert_includes source, 'import "./missing" is not in the import map'
    assert_equal "demo/helper", built.id_for_path(helper)
  end

  def assert_host_import_map(dir)
    stimulus, widgets, load_path = write_import_map_files(dir)
    map = import_map_for(widgets)
    app = Struct.new(:importmap, :assets, :root).new(map, Struct.new(:load_path).new(load_path), Pathname.new(dir))
    bare = bare_import_app
    application = install_import_map(map, load_path)
    Rails.stub(:root, nil) { assert_resolved_import_map(stimulus, widgets, app, bare) }
  ensure
    remove_import_map(application)
  end

  def write_import_map_files(dir)
    stimulus = File.join(dir, "stimulus.min.js")
    File.write(stimulus, File.read(File.join(FIXTURES, "stimulus.js")))
    widgets = File.join(dir, "widgets")
    FileUtils.mkdir_p(widgets)
    File.write(File.join(widgets, "index.js"), "export const marker = true\n")
    File.write(File.join(widgets, "tabs_controller.js"), File.read(File.join(FIXTURES, "echo_controller.js")))
    [stimulus, widgets, asset_finder(dir, stimulus)]
  end

  def asset_finder(dir, stimulus)
    finder = Object.new
    finder.define_singleton_method(:find) do |logical|
      next Pathname.new(stimulus) if logical == "stimulus.min.js"
      next File.join(dir, "missing.js") if logical == "missing.js"

      nil
    end
    finder
  end

  def import_map_for(widgets)
    packages = {
      "@hotwired/stimulus" => Struct.new(:path).new("stimulus.min.js"),
      "demo/missing" => Struct.new(:path).new("missing.js"),
      "demo/bare" => Struct.new(:path).new("bare.js")
    }
    Struct.new(:packages, :directories).new(packages, { widgets => { dir: "widgets", under: "controllers/widgets" } })
  end

  def bare_import_app
    packages = { "demo/bare" => Struct.new(:path).new("bare.js") }
    Struct.new(:importmap).new(Struct.new(:packages, :directories).new(packages, {}))
  end

  def install_import_map(map, load_path)
    application = Rails.application
    application.define_singleton_method(:importmap) { map }
    application.define_singleton_method(:assets) { Struct.new(:load_path).new(load_path) }
    application
  end

  def remove_import_map(application)
    return unless application

    application.singleton_class.undef_method(:importmap)
    application.singleton_class.undef_method(:assets)
  end

  def assert_resolved_import_map(stimulus, widgets, app, bare)
    via_rails = RecordingStudio::MCP_UI::ImportMapCatalog.from_rails
    built = RecordingStudio::MCP_UI::ImportMapCatalog.from_app(app)

    assert_equal stimulus, via_rails.find("@hotwired/stimulus").path
    assert_equal stimulus, built.find("@hotwired/stimulus").path
    assert_nil built.find("demo/missing").path
    assert_equal File.join(widgets, "tabs_controller.js"), built.find("controllers/widgets/tabs_controller").path
    assert_equal "controllers/widgets", built.find("controllers/widgets").name
    assert_nil RecordingStudio::MCP_UI::ImportMapCatalog.from_app(bare).find("demo/bare").path
  end

  def bundle_for(configuration, import_map)
    RecordingStudio::MCP_UI::StimulusBundle.javascript(configuration, catalog: import_map)
  end

  def asset_load_path
    Object.new
  end

  def assert_javascript(source)
    Tempfile.create(["widget", ".js"]) do |file|
      file.write(source)
      file.flush
      output, status = Open3.capture2e("node", "--check", file.path)
      assert status.success?, output
    end
  end

  def run_bundle(source)
    script = <<~JS
      const fs = require("fs");
      const vm = require("vm");
      const code = fs.readFileSync(process.argv[2], "utf8");
      const context = {
        window: {},
        console,
        JSON,
        Object,
        Array,
        String,
        Error
      };
      context.window.window = context.window;
      context.window.document = { documentElement: { id: "root" } };
      context.globalThis = context.window;
      vm.createContext(context);
      vm.runInContext(code, context, { filename: "widget.js" });
      const registered = context.window.Stimulus.registered;
      const picker = registered["demo--picker"];
      const controller = new picker();
      process.stdout.write(JSON.stringify({
        keys: Object.keys(registered),
        copy: controller.label("Ada")
      }));
    JS
    Dir.mktmpdir do |dir|
      bundle = File.join(dir, "bundle.js")
      harness = File.join(dir, "harness.js")
      File.write(bundle, source)
      File.write(harness, script)
      output, status = Open3.capture2e("node", harness, bundle)
      assert status.success?, output
      JSON.parse(output)
    end
  end
end
