# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tempfile"

describe TRuby::BenchmarkSuite do
  let(:config) { instance_double(TRuby::Config) }
  let(:suite) { described_class.new(config) }

  describe "BENCHMARK_CATEGORIES" do
    it "contains expected categories" do
      expect(described_class::BENCHMARK_CATEGORIES).to eq(
        %i[parsing type_checking compilation incremental parallel memory]
      )
    end
  end

  describe "#initialize" do
    it "initializes with default config when none provided" do
      allow(TRuby::Config).to receive(:new).and_return(config)
      suite = described_class.new
      expect(suite.config).to eq(config)
    end

    it "initializes with provided config" do
      expect(suite.config).to eq(config)
    end

    it "initializes results as empty hash" do
      expect(suite.results).to eq({})
    end
  end

  describe "#run_all" do
    before do
      allow(suite).to receive(:run_category)
      allow(suite).to receive(:print_summary)
      allow(suite).to receive(:puts)
    end

    it "runs all benchmark categories" do
      suite.run_all(iterations: 1, warmup: 0)

      described_class::BENCHMARK_CATEGORIES.each do |category|
        expect(suite).to have_received(:run_category).with(category, iterations: 1, warmup: 0)
      end
    end

    it "prints summary after running" do
      suite.run_all(iterations: 1, warmup: 0)
      expect(suite).to have_received(:print_summary)
    end

    it "returns results hash" do
      result = suite.run_all(iterations: 1, warmup: 0)
      expect(result).to be_a(Hash)
    end
  end

  describe "#run_category" do
    before do
      allow(suite).to receive(:puts)
      allow(suite).to receive(:benchmark_parsing).and_return({ test: { avg_time: 0.001 } })
      allow(suite).to receive(:benchmark_type_checking).and_return({ test: { avg_time: 0.001 } })
      allow(suite).to receive(:benchmark_compilation).and_return({ test: { avg_time: 0.001 } })
      allow(suite).to receive(:benchmark_incremental).and_return({ test: { avg_time: 0.001 } })
      allow(suite).to receive(:benchmark_parallel).and_return({ test: { avg_time: 0.001 } })
      allow(suite).to receive(:benchmark_memory).and_return({ test: { memory: 100 } })
    end

    it "runs parsing benchmarks" do
      suite.run_category(:parsing, iterations: 1, warmup: 0)
      expect(suite).to have_received(:benchmark_parsing).with(1, 0)
      expect(suite.results[:parsing]).to eq({ test: { avg_time: 0.001 } })
    end

    it "runs type_checking benchmarks" do
      suite.run_category(:type_checking, iterations: 1, warmup: 0)
      expect(suite).to have_received(:benchmark_type_checking).with(1, 0)
    end

    it "runs compilation benchmarks" do
      suite.run_category(:compilation, iterations: 1, warmup: 0)
      expect(suite).to have_received(:benchmark_compilation).with(1, 0)
    end

    it "runs incremental benchmarks" do
      suite.run_category(:incremental, iterations: 1, warmup: 0)
      expect(suite).to have_received(:benchmark_incremental).with(1, 0)
    end

    it "runs parallel benchmarks" do
      suite.run_category(:parallel, iterations: 1, warmup: 0)
      expect(suite).to have_received(:benchmark_parallel).with(1, 0)
    end

    it "runs memory benchmarks" do
      suite.run_category(:memory)
      expect(suite).to have_received(:benchmark_memory)
    end
  end

  describe "#export_json" do
    let(:results) { { parsing: { small_file: { avg_time: 0.001, min_time: 0.0008, max_time: 0.0012 } } } }

    before do
      suite.instance_variable_set(:@results, results)
    end

    it "exports results to JSON file" do
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "results.json")
        suite.export_json(path)

        expect(File.exist?(path)).to be true
        json = JSON.parse(File.read(path))
        expect(json).to have_key("timestamp")
        expect(json).to have_key("ruby_version")
        expect(json).to have_key("platform")
        expect(json).to have_key("results")
      end
    end

    it "includes correct results structure" do
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "results.json")
        suite.export_json(path)

        json = JSON.parse(File.read(path), symbolize_names: true)
        expect(json[:results][:parsing][:small_file][:avg_time]).to eq(0.001)
      end
    end
  end

  describe "#export_markdown" do
    let(:results) do
      {
        parsing: {
          small_file: { avg_time: 0.001, memory: 100, min_time: 0.0008, max_time: 0.0012 },
        },
      }
    end

    before do
      suite.instance_variable_set(:@results, results)
    end

    it "exports results to Markdown file" do
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "results.md")
        suite.export_markdown(path)

        expect(File.exist?(path)).to be true
        content = File.read(path)
        expect(content).to include("# T-Ruby Benchmark Results")
        expect(content).to include("## Parsing")
        expect(content).to include("small_file")
      end
    end

    it "includes table headers" do
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "results.md")
        suite.export_markdown(path)

        content = File.read(path)
        expect(content).to include("| Benchmark | Time (ms) | Memory (KB) | Iterations/sec |")
      end
    end

    it "calculates iterations per second correctly" do
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "results.md")
        suite.export_markdown(path)

        content = File.read(path)
        # 0.001 seconds = 1000 iterations/sec
        expect(content).to include("1000.0")
      end
    end

    it "handles zero avg_time gracefully" do
      zero_results = {
        memory: {
          cache: { avg_time: 0, memory: 500 },
        },
      }
      suite.instance_variable_set(:@results, zero_results)

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "results.md")
        suite.export_markdown(path)

        content = File.read(path)
        expect(content).to include("| cache | 0 | 500 | 0 |")
      end
    end
  end

  describe "#compare" do
    let(:current_results) do
      {
        parsing: {
          small_file: { avg_time: 0.0009 },
        },
      }
    end

    let(:previous_results) do
      {
        timestamp: Time.now.iso8601,
        results: {
          parsing: {
            small_file: { avg_time: 0.001 },
          },
        },
      }
    end

    before do
      suite.instance_variable_set(:@results, current_results)
    end

    it "returns nil if previous file does not exist" do
      result = suite.compare("/nonexistent/path.json")
      expect(result).to be_nil
    end

    it "compares with previous results" do
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "previous.json")
        File.write(path, JSON.generate(previous_results))

        comparison = suite.compare(path)

        expect(comparison).to have_key(:parsing)
        expect(comparison[:parsing]).to have_key(:small_file)
        expect(comparison[:parsing][:small_file][:current]).to eq(0.0009)
        expect(comparison[:parsing][:small_file][:previous]).to eq(0.001)
      end
    end

    it "calculates percentage difference" do
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "previous.json")
        File.write(path, JSON.generate(previous_results))

        comparison = suite.compare(path)

        # 0.0009 is 10% faster than 0.001
        expect(comparison[:parsing][:small_file][:diff_percent]).to eq(-10.0)
        expect(comparison[:parsing][:small_file][:improved]).to be true
      end
    end

    it "handles missing categories gracefully" do
      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "previous.json")
        File.write(path, JSON.generate({ results: {} }))

        comparison = suite.compare(path)
        expect(comparison).to eq({})
      end
    end

    it "skips missing benchmarks in previous results" do
      suite.instance_variable_set(:@results, {
                                    parsing: {
                                      small_file: { avg_time: 0.001 },
                                      new_benchmark: { avg_time: 0.002 },
                                    },
                                  })

      Dir.mktmpdir do |tmpdir|
        path = File.join(tmpdir, "previous.json")
        File.write(path, JSON.generate({
                                         results: {
                                           parsing: {
                                             small_file: { avg_time: 0.001 },
                                           },
                                         },
                                       }))

        comparison = suite.compare(path)

        expect(comparison[:parsing]).to have_key(:small_file)
        expect(comparison[:parsing]).not_to have_key(:new_benchmark)
      end
    end
  end

  describe "private methods" do
    describe "#calculate_stats" do
      it "calculates statistics correctly" do
        times = [0.001, 0.002, 0.003]
        stats = suite.send(:calculate_stats, times)

        expect(stats[:avg_time]).to eq(0.002)
        expect(stats[:min_time]).to eq(0.001)
        expect(stats[:max_time]).to eq(0.003)
        expect(stats[:iterations]).to eq(3)
        expect(stats[:std_dev]).to be_a(Float)
      end
    end

    describe "#generate_test_files" do
      it "generates parsing test files" do
        files = suite.send(:generate_test_files, :parsing)
        expect(files).to have_key(:small_file)
        expect(files).to have_key(:medium_file)
        expect(files).to have_key(:large_file)
        expect(files).to have_key(:complex_types)
      end

      it "generates type_checking test files" do
        files = suite.send(:generate_test_files, :type_checking)
        expect(files).to have_key(:simple_types)
        expect(files).to have_key(:generic_types)
        expect(files).to have_key(:union_types)
        expect(files).to have_key(:interface_types)
      end

      it "generates compilation test files" do
        files = suite.send(:generate_test_files, :compilation)
        expect(files).to have_key(:minimal)
        expect(files).to have_key(:with_types)
        expect(files).to have_key(:with_interfaces)
      end

      it "returns empty hash for unknown category" do
        files = suite.send(:generate_test_files, :unknown)
        expect(files).to eq({})
      end
    end

    describe "#generate_test_content" do
      it "generates content with type definitions" do
        content = suite.send(:generate_test_content, 0)
        expect(content).to include("type CustomType0")
        expect(content).to include("interface TestInterface0")
      end

      it "generates specified number of lines" do
        content = suite.send(:generate_test_content, 0, lines: 20)
        lines = content.split("\n").length
        expect(lines).to be >= 15
      end

      it "marks modified content" do
        content = suite.send(:generate_test_content, 0, modified: true)
        expect(content).to include("(modified)")
      end
    end

    describe "#generate_complex_types_content" do
      it "generates complex type content" do
        content = suite.send(:generate_complex_types_content)
        expect(content).to include("DeepNested")
        expect(content).to include("UnionOfGenerics")
        expect(content).to include("ComplexInterface")
      end
    end

    describe "#generate_simple_types_content" do
      it "generates simple type content" do
        content = suite.send(:generate_simple_types_content)
        expect(content).to include("def add")
        expect(content).to include("def greet")
        expect(content).to include("def valid?")
      end
    end

    describe "#generate_generic_types_content" do
      it "generates generic type content" do
        content = suite.send(:generate_generic_types_content)
        expect(content).to include("def first<T>")
        expect(content).to include("def map_values<K, V, R>")
        expect(content).to include("def wrap<T>")
      end
    end

    describe "#generate_union_types_content" do
      it "generates union type content" do
        content = suite.send(:generate_union_types_content)
        expect(content).to include("StringOrNumber")
        expect(content).to include("NullableString")
        expect(content).to include("Status")
      end
    end

    describe "#generate_interface_types_content" do
      it "generates interface type content" do
        content = suite.send(:generate_interface_types_content)
        expect(content).to include("interface Comparable")
        expect(content).to include("interface Enumerable")
        expect(content).to include("interface Repository")
      end
    end

    describe "#get_memory_usage" do
      it "returns a numeric value" do
        memory = suite.send(:get_memory_usage)
        expect(memory).to be_a(Numeric)
        expect(memory).to be >= 0
      end
    end
  end
end

describe TRuby::QuickBenchmark do
  describe ".measure" do
    it "measures block execution time" do
      allow(described_class).to receive(:puts)

      result = described_class.measure("Test", iterations: 5) { 1 + 1 }

      expect(result).to be_a(Float)
      expect(result).to be >= 0
    end

    it "prints result with name" do
      expect { described_class.measure("Test", iterations: 5) { 1 + 1 } }
        .to output(/Test:.*ms avg/).to_stdout
    end
  end

  describe ".compare" do
    it "measures single execution and returns result" do
      allow(described_class).to receive(:puts)

      result = described_class.compare("Test") { 42 }

      expect(result).to eq(42)
    end

    it "prints timing information" do
      expect { described_class.compare("Test") { 1 + 1 } }
        .to output(/Test:.*ms/).to_stdout
    end
  end
end

describe "BenchmarkSuite actual benchmark methods" do
  let(:config) { TRuby::Config.new }
  let(:suite) { TRuby::BenchmarkSuite.new(config) }

  def suppress_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end

  describe "#benchmark_parsing" do
    it "runs parsing benchmarks" do
      results = nil
      suppress_output { results = suite.send(:benchmark_parsing, 1, 0) }

      expect(results).to have_key(:small_file)
      expect(results).to have_key(:medium_file)
      expect(results[:small_file]).to have_key(:avg_time)
    end
  end

  describe "#print_result" do
    it "prints time results" do
      stats = { avg_time: 0.001, std_dev: 0.0001, memory: 100 }
      original_stdout = $stdout
      $stdout = StringIO.new
      suite.send(:print_result, :test, stats)
      output = $stdout.string
      $stdout = original_stdout

      expect(output).to include("test:")
      expect(output).to include("ms")
    end

    it "prints memory results with KB unit" do
      stats = { memory: 150.5, avg_time: 0, std_dev: 0 }
      original_stdout = $stdout
      $stdout = StringIO.new
      suite.send(:print_result, :test, stats, unit: "KB")
      output = $stdout.string
      $stdout = original_stdout

      expect(output).to include("150.5 KB")
    end
  end

  describe "#print_summary" do
    before do
      suite.instance_variable_set(:@results, {
                                    parsing: { small: { avg_time: 0.001 }, medium: { avg_time: 0.002 } },
                                    compilation: { test: { avg_time: 0.003 } },
                                  })
    end

    it "prints summary with totals" do
      original_stdout = $stdout
      $stdout = StringIO.new
      suite.send(:print_summary)
      output = $stdout.string
      $stdout = original_stdout

      expect(output).to include("SUMMARY")
    end
  end

  describe "#compiler" do
    it "returns compiler instance" do
      compiler = suite.send(:compiler)
      expect(compiler).to be_a(TRuby::Compiler)
    end

    it "memoizes compiler" do
      compiler1 = suite.send(:compiler)
      compiler2 = suite.send(:compiler)
      expect(compiler1).to eq(compiler2)
    end
  end

  describe "#type_checker" do
    it "returns type checker instance" do
      checker = suite.send(:type_checker)
      expect(checker).to be_a(TRuby::TypeChecker)
    end
  end

  describe "#get_memory_usage on linux vs non-linux" do
    it "returns memory value" do
      memory = suite.send(:get_memory_usage)
      expect(memory).to be_a(Numeric)
    end
  end

  describe "#benchmark_type_checking" do
    it "generates type checking test cases" do
      test_cases = suite.send(:generate_test_files, :type_checking)
      expect(test_cases).to have_key(:simple_types)
      expect(test_cases).to have_key(:generic_types)
      expect(test_cases).to have_key(:union_types)
      expect(test_cases).to have_key(:interface_types)
    end

    it "parses type checking content" do
      content = suite.send(:generate_simple_types_content)
      ast = TRuby::Parser.new(content).parse
      expect(ast).not_to be_nil
    end
  end

  describe "#benchmark_compilation" do
    it "generates compilation test cases" do
      test_cases = suite.send(:generate_test_files, :compilation)
      expect(test_cases).to have_key(:minimal)
      expect(test_cases).to have_key(:with_types)
      expect(test_cases).to have_key(:with_interfaces)
    end

    it "compiles valid code" do
      Dir.mktmpdir("trb_bench") do |tmpdir|
        content = "def add(a: Integer, b: Integer): Integer\n  a + b\nend"
        input_path = File.join(tmpdir, "test.trb")
        File.write(input_path, content)

        compiler = suite.send(:compiler)
        result = compiler.compile(input_path)
        expect(result).not_to be_nil
      end
    end
  end

  describe "#benchmark_incremental" do
    it "generates test content for incremental benchmarks" do
      10.times do |i|
        content = suite.send(:generate_test_content, i)
        expect(content).to include("CustomType#{i}")
      end
    end

    it "generates modified content" do
      content = suite.send(:generate_test_content, 0, modified: true)
      expect(content).to include("(modified)")
    end
  end

  describe "#benchmark_parallel" do
    it "generates parallel test files" do
      20.times do |i|
        content = suite.send(:generate_test_content, i)
        expect(content).to include("TestInterface#{i}")
      end
    end

    it "creates compiler instance" do
      compiler = suite.send(:compiler)
      expect(compiler).to be_a(TRuby::Compiler)
    end
  end

  describe "#benchmark_memory" do
    it "measures memory usage" do
      memory = suite.send(:get_memory_usage)
      expect(memory).to be >= 0
    end

    it "creates cache entries" do
      cache = TRuby::MemoryCache.new
      100.times { |i| cache.set("key_#{i}", "value_#{i}") }
      expect(cache.get("key_50")).to eq("value_50")
    end
  end
end
