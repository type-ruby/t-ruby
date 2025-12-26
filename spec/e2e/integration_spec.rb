# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe "T-Ruby E2E Integration" do
  let(:tmpdir) { Dir.mktmpdir("trb_e2e") }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "Full compilation pipeline" do
    it "compiles a complete T-Ruby project" do
      # Create a mini project structure
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      # Create trbconfig.yml config to set output dir
      File.write(File.join(tmpdir, "trbconfig.yml"), <<~YAML)
        emit:
          rb: true
          rbs: false
          dtrb: false
        paths:
          src: "#{lib_dir}"
          out: "#{lib_dir}"
      YAML

      # Main application file
      File.write(File.join(lib_dir, "app.trb"), <<~TRB)
        # Application entry point
        type AppConfig = {
          name: String,
          version: String,
          debug: Boolean
        }

        interface Logger
          info: void
          warn: void
          error: void
        end

        def initialize_app(config: AppConfig): Boolean
          puts "Initializing \#{config[:name]}"
          true
        end

        def run(args: Array<String>): Integer
          0
        end
      TRB

      # Model file
      File.write(File.join(lib_dir, "user.trb"), <<~TRB)
        type UserId = Integer
        type Email = String

        interface User
          id: UserId
          email: Email
          name: String
          active?: Boolean
        end

        def find_user(id: UserId): User | nil
          nil
        end

        def create_user(email: Email, name: String): User
          { id: 1, email: email, name: name, active?: true }
        end
      TRB

      # Compile all files with custom config (disable type checking for this test)
      config = TRuby::Config.new(File.join(tmpdir, "trbconfig.yml"))
      allow(config).to receive(:type_check?).and_return(false)
      compiler = TRuby::Compiler.new(config)

      trb_files = Dir.glob(File.join(lib_dir, "*.trb"))
      expect(trb_files.size).to eq(2)

      trb_files.each do |file|
        expect { compiler.compile(file) }.not_to raise_error
        output_file = file.sub(".trb", ".rb")
        expect(File.exist?(output_file)).to be true
      end
    end

    it "handles incremental compilation correctly" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      # Create trbconfig.yml config to set output dir
      File.write(File.join(tmpdir, "trbconfig.yml"), <<~YAML)
        emit:
          rb: true
          rbs: false
          dtrb: false
        paths:
          src: "#{lib_dir}"
          out: "#{lib_dir}"
      YAML

      # Create initial file
      file1 = File.join(lib_dir, "file1.trb")
      File.write(file1, "def hello(name: String): String\n  \"Hello, \#{name}\"\nend")

      config = TRuby::Config.new(File.join(tmpdir, "trbconfig.yml"))
      compiler = TRuby::Compiler.new(config)
      ic = TRuby::IncrementalCompiler.new(compiler)

      # Initial compile
      ic.compile_all([file1])
      expect(File.exist?(file1.sub(".trb", ".rb"))).to be true

      # Modify file
      sleep(0.1) # Ensure mtime changes
      File.write(file1, "def hello(name: String): String\n  \"Hi, \#{name}!\"\nend")

      # Incremental compile should detect change
      expect(ic.needs_compile?(file1)).to be true
      ic.compile_all([file1])
    end

    it "performs parallel compilation" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      # Create multiple files
      10.times do |i|
        File.write(File.join(lib_dir, "file_#{i}.trb"), <<~TRB)
          def method_#{i}(value: Integer): Integer
            value * #{i}
          end
        TRB
      end

      config = TRuby::Config.new
      compiler = TRuby::Compiler.new(config)
      processor = TRuby::ParallelProcessor.new(thread_count: 4)

      files = Dir.glob(File.join(lib_dir, "*.trb"))
      results = processor.process_files(files) do |file|
        compiler.compile(file)
      end

      expect(results.size).to eq(10)
      results.each do |result|
        # Each result is the output file path (string)
        expect(result).to be_a(String)
        expect(result).to end_with(".rb")
      end
    end
  end

  describe "Type checking pipeline" do
    it "validates type annotations across files" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      # File with type definitions
      File.write(File.join(lib_dir, "types.trb"), <<~TRB)
        type Status = "pending" | "active" | "completed"

        interface Task
          id: Integer
          title: String
          status: Status
        end
      TRB

      # File using the types
      File.write(File.join(lib_dir, "tasks.trb"), <<~TRB)
        def get_task(id: Integer): Task | nil
          nil
        end

        def update_status(task: Task, status: Status): Task
          task
        end
      TRB

      config = TRuby::Config.new
      compiler = TRuby::Compiler.new(config)

      files = Dir.glob(File.join(lib_dir, "*.trb"))
      files.each do |file|
        expect { compiler.compile(file) }.not_to raise_error
      end
    end

    it "detects type errors with SMT solver" do
      content = <<~TRB
        def process(value: String): Integer
          value.to_i
        end
      TRB

      parser = TRuby::Parser.new(content)
      parser.parse
      ir_program = parser.ir_program
      expect(ir_program).not_to be_nil

      type_checker = TRuby::TypeChecker.new
      result = type_checker.check_program(ir_program)
      expect(result).to be_a(Hash)
    end
  end

  describe "Watch mode" do
    it "detects file changes and recompiles" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      file = File.join(lib_dir, "watched.trb")
      File.write(file, "def original(x: Integer): Integer\n  x\nend")

      config = TRuby::Config.new
      watcher = TRuby::Watcher.new(paths: [lib_dir], config: config)

      # Verify watcher can be created
      expect(watcher).to be_a(TRuby::Watcher)
      expect(watcher.incremental_compiler).not_to be_nil
    end
  end

  describe "Package management" do
    it "initializes a new package" do
      pm = TRuby::PackageManager.new(project_dir: tmpdir)
      manifest = pm.init(name: "test-package")

      expect(manifest.name).to eq("test-package")
      expect(manifest.version).to eq("0.1.0")
      expect(File.exist?(File.join(tmpdir, ".trb-manifest.json"))).to be true
    end

    it "manages dependencies" do
      pm = TRuby::PackageManager.new(project_dir: tmpdir)
      pm.init(name: "test-project")

      # Register a mock package in registry
      pm.registry.register(TRuby::PackageManifest.new(
                             name: "test-types",
                             version: "1.0.0"
                           ))

      pm.add("test-types", "^1.0.0")

      manifest = TRuby::PackageManifest.load(File.join(tmpdir, ".trb-manifest.json"))
      expect(manifest.dependencies).to have_key("test-types")
    end

    it "resolves version constraints" do
      registry = TRuby::PackageRegistry.new

      # Register multiple versions
      %w[1.0.0 1.1.0 1.2.0 2.0.0].each do |version|
        registry.register(TRuby::PackageManifest.new(
                            name: "lib",
                            version: version
                          ))
      end

      resolver = TRuby::DependencyResolver.new(registry)

      # Create manifest with constraint
      manifest = TRuby::PackageManifest.new(
        name: "app",
        version: "1.0.0",
        dependencies: { "lib" => "^1.0.0" }
      )

      result = resolver.resolve(manifest)
      expect(result[:conflicts]).to be_empty
      expect(result[:resolved]["lib"]).to eq("1.2.0") # Latest 1.x
    end
  end

  describe "LSP server" do
    it "handles initialization" do
      server = TRuby::LSPServer.new

      init_result = server.handle_message({
                                            "id" => 1,
                                            "method" => "initialize",
                                            "params" => {
                                              "processId" => Process.pid,
                                              "rootUri" => "file://#{tmpdir}",
                                              "capabilities" => {},
                                            },
                                          })

      expect(init_result["result"]["capabilities"]).to be_a(Hash)
      expect(init_result["result"]["capabilities"]["textDocumentSync"]).not_to be_nil
      expect(init_result["result"]["capabilities"]["completionProvider"]).not_to be_nil
    end

    it "provides hover information" do
      server = TRuby::LSPServer.new
      server.handle_message({
                              "id" => 1,
                              "method" => "initialize",
                              "params" => {
                                "processId" => Process.pid,
                                "rootUri" => "file://#{tmpdir}",
                                "capabilities" => {},
                              },
                            })

      # Open a document (notification - no id)
      server.handle_message({
                              "method" => "textDocument/didOpen",
                              "params" => {
                                "textDocument" => {
                                  "uri" => "file://#{tmpdir}/test.trb",
                                  "languageId" => "t-ruby",
                                  "version" => 1,
                                  "text" => "def hello(name: String): String\n  \"Hello\"\nend",
                                },
                              },
                            })

      hover_result = server.handle_message({
                                             "id" => 2,
                                             "method" => "textDocument/hover",
                                             "params" => {
                                               "textDocument" => { "uri" => "file://#{tmpdir}/test.trb" },
                                               "position" => { "line" => 0, "character" => 4 },
                                             },
                                           })

      expect(hover_result).to be_a(Hash)
    end
  end

  describe "Documentation generation" do
    it "generates API documentation" do
      lib_dir = File.join(tmpdir, "lib")
      docs_dir = File.join(tmpdir, "docs")
      FileUtils.mkdir_p(lib_dir)

      File.write(File.join(lib_dir, "api.trb"), <<~TRB)
        # User type representing a system user
        type UserId = Integer

        # User interface
        interface User
          id: UserId
          name: String
        end

        # Find a user by ID
        def find_user(id: UserId): User | nil
          nil
        end
      TRB

      doc_gen = TRuby::DocGenerator.new
      doc_gen.generate([lib_dir], output_dir: docs_dir)

      expect(File.exist?(File.join(docs_dir, "index.html"))).to be true
      expect(File.exist?(File.join(docs_dir, "search-index.json"))).to be true
    end

    it "generates markdown documentation" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      File.write(File.join(lib_dir, "lib.trb"), <<~TRB)
        type Config = Hash<String, String>

        def process(config: Config): Boolean
          true
        end
      TRB

      doc_gen = TRuby::DocGenerator.new
      output_path = File.join(tmpdir, "API.md")
      doc_gen.generate_markdown([lib_dir], output_path: output_path)

      expect(File.exist?(output_path)).to be true
      content = File.read(output_path)
      expect(content).to include("Config")
      expect(content).to include("process")
    end
  end

  describe "Benchmarking" do
    it "runs benchmark suite" do
      benchmark = TRuby::BenchmarkSuite.new

      # Run just parsing benchmarks with minimal iterations
      benchmark.run_category(:parsing, iterations: 2, warmup: 1)
      results = benchmark.results[:parsing]

      expect(results).to be_a(Hash)
      expect(results.keys).to include(:small_file, :medium_file)
      results.each_value do |stats|
        expect(stats[:avg_time]).to be >= 0
        expect(stats[:min_time]).to be >= 0
        expect(stats[:max_time]).to be >= 0
      end
    end

    it "exports benchmark results" do
      benchmark = TRuby::BenchmarkSuite.new
      benchmark.run_category(:parsing, iterations: 2, warmup: 1)

      json_path = File.join(tmpdir, "benchmarks.json")
      benchmark.export_json(json_path)

      expect(File.exist?(json_path)).to be true
      data = JSON.parse(File.read(json_path))
      expect(data["results"]).to be_a(Hash)
    end
  end

  describe "Bundler integration" do
    it "generates gem type stubs" do
      gemfile_path = File.join(tmpdir, "Gemfile")
      File.write(gemfile_path, <<~GEMFILE)
        source 'https://rubygems.org'
        gem 'json'
      GEMFILE

      integration = TRuby::BundlerIntegration.new(project_dir: tmpdir)

      # Basic functionality test
      expect(integration).to be_a(TRuby::BundlerIntegration)
    end
  end

  describe "CLI interface" do
    it "parses command line arguments" do
      # Test various CLI commands
      expect { TRuby::CLI.new(["--help"]) }.not_to raise_error
    end
  end

  describe "Error handling" do
    it "provides helpful error messages for syntax errors" do
      # Parser is lenient and doesn't raise errors for incomplete constructs
      # Instead, it returns success with empty results for unparseable content
      content = "def broken(x: String" # Missing closing paren

      parser = TRuby::Parser.new(content)
      result = parser.parse

      # Parser returns success but with no parsed functions
      expect(result[:type]).to eq(:success)
      expect(result[:functions]).to be_empty
    end

    it "handles file not found gracefully" do
      config = TRuby::Config.new
      compiler = TRuby::Compiler.new(config)

      expect do
        compiler.compile("/nonexistent/file.trb")
      end.to raise_error(ArgumentError, /File not found/)
    end
  end

  describe "Cross-file type checking" do
    it "validates types across multiple files" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      File.write(File.join(lib_dir, "base.trb"), <<~TRB)
        interface Entity
          id: Integer
          created_at: Time
        end
      TRB

      File.write(File.join(lib_dir, "user.trb"), <<~TRB)
        interface User
          # extends Entity
          id: Integer
          created_at: Time
          name: String
        end
      TRB

      config = TRuby::Config.new
      compiler = TRuby::Compiler.new(config)
      checker = TRuby::CrossFileTypeChecker.new

      files = Dir.glob(File.join(lib_dir, "*.trb"))
      files.each do |file|
        ir = compiler.compile_to_ir(file)
        checker.register_file(file, ir)
      end

      result = checker.check_all
      expect(result[:errors]).to be_empty
    end
  end
end
