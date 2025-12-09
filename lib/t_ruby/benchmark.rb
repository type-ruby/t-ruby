# frozen_string_literal: true

require "benchmark"
require "json"
require "fileutils"

module TRuby
  # Benchmark suite for T-Ruby performance measurement
  class BenchmarkSuite
    attr_reader :results, :config

    BENCHMARK_CATEGORIES = %i[
      parsing
      type_checking
      compilation
      incremental
      parallel
      memory
    ].freeze

    def initialize(config = nil)
      @config = config || Config.new
      @results = {}
      @compiler = nil
      @type_checker = nil
    end

    # Run all benchmarks
    def run_all(iterations: 5, warmup: 2)
      puts "T-Ruby Benchmark Suite"
      puts "=" * 60
      puts "Iterations: #{iterations}, Warmup: #{warmup}"
      puts

      BENCHMARK_CATEGORIES.each do |category|
        run_category(category, iterations: iterations, warmup: warmup)
      end

      print_summary
      @results
    end

    # Run specific category
    def run_category(category, iterations: 5, warmup: 2)
      puts "Running #{category} benchmarks..."
      puts "-" * 40

      @results[category] = case category
                           when :parsing then benchmark_parsing(iterations, warmup)
                           when :type_checking then benchmark_type_checking(iterations, warmup)
                           when :compilation then benchmark_compilation(iterations, warmup)
                           when :incremental then benchmark_incremental(iterations, warmup)
                           when :parallel then benchmark_parallel(iterations, warmup)
                           when :memory then benchmark_memory
                           end

      puts
    end

    # Export results to JSON
    def export_json(path = "benchmark_results.json")
      File.write(path, JSON.pretty_generate({
        timestamp: Time.now.iso8601,
        ruby_version: RUBY_VERSION,
        platform: RUBY_PLATFORM,
        results: @results
      }))
    end

    # Export results to Markdown
    def export_markdown(path = "benchmark_results.md")
      md = []
      md << "# T-Ruby Benchmark Results"
      md << ""
      md << "**Generated:** #{Time.now}"
      md << "**Ruby Version:** #{RUBY_VERSION}"
      md << "**Platform:** #{RUBY_PLATFORM}"
      md << ""

      @results.each do |category, benchmarks|
        md << "## #{category.to_s.capitalize}"
        md << ""
        md << "| Benchmark | Time (ms) | Memory (KB) | Iterations/sec |"
        md << "|-----------|-----------|-------------|----------------|"

        benchmarks.each do |name, data|
          time_ms = (data[:avg_time] * 1000).round(2)
          memory_kb = (data[:memory] || 0).round(2)
          ips = data[:avg_time] > 0 ? (1.0 / data[:avg_time]).round(2) : 0
          md << "| #{name} | #{time_ms} | #{memory_kb} | #{ips} |"
        end
        md << ""
      end

      File.write(path, md.join("\n"))
    end

    # Compare with previous results
    def compare(previous_path)
      return nil unless File.exist?(previous_path)

      previous = JSON.parse(File.read(previous_path), symbolize_names: true)
      comparison = {}

      @results.each do |category, benchmarks|
        prev_cat = previous[:results][category]
        next unless prev_cat

        comparison[category] = {}
        benchmarks.each do |name, data|
          prev_data = prev_cat[name]
          next unless prev_data

          diff = ((data[:avg_time] - prev_data[:avg_time]) / prev_data[:avg_time] * 100).round(2)
          comparison[category][name] = {
            current: data[:avg_time],
            previous: prev_data[:avg_time],
            diff_percent: diff,
            improved: diff < 0
          }
        end
      end

      comparison
    end

    private

    def compiler
      @compiler ||= Compiler.new(@config)
    end

    def type_checker
      @type_checker ||= TypeChecker.new
    end

    # Parsing benchmarks
    def benchmark_parsing(iterations, warmup)
      test_files = generate_test_files(:parsing)
      results = {}

      test_files.each do |name, content|
        times = []

        # Warmup
        warmup.times { Parser.new(content).parse }

        # Actual benchmark
        iterations.times do
          time = Benchmark.realtime { Parser.new(content).parse }
          times << time
        end

        results[name] = calculate_stats(times)
        print_result(name, results[name])
      end

      results
    end

    # Type checking benchmarks
    def benchmark_type_checking(iterations, warmup)
      test_cases = generate_test_files(:type_checking)
      results = {}

      test_cases.each do |name, content|
        times = []
        ast = Parser.new(content).parse

        # Warmup
        warmup.times { TypeChecker.new.check(ast) }

        # Actual benchmark
        iterations.times do
          checker = TypeChecker.new
          time = Benchmark.realtime { checker.check(ast) }
          times << time
        end

        results[name] = calculate_stats(times)
        print_result(name, results[name])
      end

      results
    end

    # Compilation benchmarks
    def benchmark_compilation(iterations, warmup)
      test_cases = generate_test_files(:compilation)
      results = {}

      Dir.mktmpdir("trb_bench") do |tmpdir|
        test_cases.each do |name, content|
          input_path = File.join(tmpdir, "#{name}.trb")
          File.write(input_path, content)

          times = []

          # Warmup
          warmup.times { compiler.compile(input_path) }

          # Actual benchmark
          iterations.times do
            time = Benchmark.realtime { compiler.compile(input_path) }
            times << time
          end

          results[name] = calculate_stats(times)
          print_result(name, results[name])
        end
      end

      results
    end

    # Incremental compilation benchmarks
    def benchmark_incremental(iterations, warmup)
      results = {}

      Dir.mktmpdir("trb_incr_bench") do |tmpdir|
        # Create test files
        files = 10.times.map do |i|
          path = File.join(tmpdir, "file_#{i}.trb")
          File.write(path, generate_test_content(i))
          path
        end

        # Full compilation
        full_times = []
        warmup.times { IncrementalCompiler.new(compiler).compile_all(files) }
        iterations.times do
          ic = IncrementalCompiler.new(compiler)
          time = Benchmark.realtime { ic.compile_all(files) }
          full_times << time
        end
        results[:full_compile] = calculate_stats(full_times)
        print_result(:full_compile, results[:full_compile])

        # Incremental (single file change)
        incr_times = []
        ic = IncrementalCompiler.new(compiler)
        ic.compile_all(files)

        warmup.times do
          File.write(files[0], generate_test_content(0, modified: true))
          ic.compile_incremental([files[0]])
        end

        iterations.times do
          File.write(files[0], generate_test_content(0, modified: true))
          time = Benchmark.realtime { ic.compile_incremental([files[0]]) }
          incr_times << time
        end
        results[:incremental_single] = calculate_stats(incr_times)
        print_result(:incremental_single, results[:incremental_single])

        # Calculate speedup
        if results[:full_compile][:avg_time] > 0
          speedup = results[:full_compile][:avg_time] / results[:incremental_single][:avg_time]
          puts "  Incremental speedup: #{speedup.round(2)}x"
        end
      end

      results
    end

    # Parallel compilation benchmarks
    def benchmark_parallel(iterations, warmup)
      results = {}

      Dir.mktmpdir("trb_parallel_bench") do |tmpdir|
        # Create 20 test files
        files = 20.times.map do |i|
          path = File.join(tmpdir, "parallel_#{i}.trb")
          File.write(path, generate_test_content(i))
          path
        end

        # Sequential
        seq_times = []
        warmup.times do
          files.each { |f| compiler.compile(f) }
        end
        iterations.times do
          time = Benchmark.realtime do
            files.each { |f| compiler.compile(f) }
          end
          seq_times << time
        end
        results[:sequential] = calculate_stats(seq_times)
        print_result(:sequential, results[:sequential])

        # Parallel (2 workers)
        par2_times = []
        processor = ParallelProcessor.new(workers: 2)
        warmup.times { processor.process_files(files) { |f| compiler.compile(f) } }
        iterations.times do
          time = Benchmark.realtime do
            processor.process_files(files) { |f| compiler.compile(f) }
          end
          par2_times << time
        end
        results[:parallel_2] = calculate_stats(par2_times)
        print_result(:parallel_2, results[:parallel_2])

        # Parallel (4 workers)
        par4_times = []
        processor4 = ParallelProcessor.new(workers: 4)
        warmup.times { processor4.process_files(files) { |f| compiler.compile(f) } }
        iterations.times do
          time = Benchmark.realtime do
            processor4.process_files(files) { |f| compiler.compile(f) }
          end
          par4_times << time
        end
        results[:parallel_4] = calculate_stats(par4_times)
        print_result(:parallel_4, results[:parallel_4])

        # Print speedups
        if results[:sequential][:avg_time] > 0
          puts "  Parallel(2) speedup: #{(results[:sequential][:avg_time] / results[:parallel_2][:avg_time]).round(2)}x"
          puts "  Parallel(4) speedup: #{(results[:sequential][:avg_time] / results[:parallel_4][:avg_time]).round(2)}x"
        end
      end

      results
    end

    # Memory benchmarks
    def benchmark_memory
      results = {}

      # Baseline memory
      GC.start
      baseline = get_memory_usage

      # Parser memory
      content = generate_test_content(0)
      GC.start
      before = get_memory_usage
      10.times { Parser.new(content).parse }
      GC.start
      after = get_memory_usage
      results[:parsing] = { memory: (after - before) / 10.0, avg_time: 0, min_time: 0, max_time: 0, std_dev: 0 }
      print_result(:parsing, results[:parsing], unit: "KB")

      # Type checker memory
      ast = Parser.new(content).parse
      GC.start
      before = get_memory_usage
      10.times { TypeChecker.new.check(ast) }
      GC.start
      after = get_memory_usage
      results[:type_checking] = { memory: (after - before) / 10.0, avg_time: 0, min_time: 0, max_time: 0, std_dev: 0 }
      print_result(:type_checking, results[:type_checking], unit: "KB")

      # Cache memory
      GC.start
      before = get_memory_usage
      cache = CompilationCache.new
      1000.times { |i| cache.set("key_#{i}", "value_#{i}") }
      GC.start
      after = get_memory_usage
      results[:cache_1000] = { memory: after - before, avg_time: 0, min_time: 0, max_time: 0, std_dev: 0 }
      print_result(:cache_1000, results[:cache_1000], unit: "KB")

      results
    end

    def generate_test_files(category)
      case category
      when :parsing
        {
          small_file: generate_test_content(0, lines: 10),
          medium_file: generate_test_content(0, lines: 100),
          large_file: generate_test_content(0, lines: 500),
          complex_types: generate_complex_types_content
        }
      when :type_checking
        {
          simple_types: generate_simple_types_content,
          generic_types: generate_generic_types_content,
          union_types: generate_union_types_content,
          interface_types: generate_interface_types_content
        }
      when :compilation
        {
          minimal: "def hello: void; end",
          with_types: generate_test_content(0, lines: 50),
          with_interfaces: generate_interface_types_content
        }
      else
        {}
      end
    end

    def generate_test_content(seed, lines: 50, modified: false)
      content = []
      content << "# Test file #{seed}#{modified ? ' (modified)' : ''}"
      content << ""
      content << "type CustomType#{seed} = String | Integer | nil"
      content << ""
      content << "interface TestInterface#{seed}"
      content << "  value: CustomType#{seed}"
      content << "  process: Boolean"
      content << "end"
      content << ""

      (lines - 10).times do |i|
        content << "def method_#{seed}_#{i}(arg: String): Integer"
        content << "  arg.length"
        content << "end"
        content << ""
      end

      content.join("\n")
    end

    def generate_complex_types_content
      <<~TRB
        type DeepNested<T> = Hash<String, Array<Hash<Symbol, T>>>
        type UnionOfGenerics<A, B> = Array<A> | Hash<String, B> | nil
        type FunctionType = Proc<Integer> | Lambda<String>

        interface ComplexInterface<T, U>
          data: DeepNested<T>
          transform: UnionOfGenerics<T, U>
          callback: FunctionType
        end

        def complex_method<T>(
          input: DeepNested<T>,
          options: Hash<Symbol, String | Integer | Boolean>
        ): UnionOfGenerics<T, String>
          nil
        end
      TRB
    end

    def generate_simple_types_content
      <<~TRB
        def add(a: Integer, b: Integer): Integer
          a + b
        end

        def greet(name: String): String
          "Hello, \#{name}"
        end

        def valid?(value: Boolean): Boolean
          value
        end
      TRB
    end

    def generate_generic_types_content
      <<~TRB
        def first<T>(items: Array<T>): T | nil
          items.first
        end

        def map_values<K, V, R>(hash: Hash<K, V>, &block: Proc<R>): Hash<K, R>
          hash.transform_values(&block)
        end

        def wrap<T>(value: T): Array<T>
          [value]
        end
      TRB
    end

    def generate_union_types_content
      <<~TRB
        type StringOrNumber = String | Integer
        type NullableString = String | nil
        type Status = "pending" | "active" | "completed"

        def process(value: StringOrNumber): String
          value.to_s
        end

        def safe_call(input: NullableString): String
          input || "default"
        end
      TRB
    end

    def generate_interface_types_content
      <<~TRB
        interface Comparable<T>
          <=>: Integer
        end

        interface Enumerable<T>
          each: void
          map: Array<T>
          select: Array<T>
        end

        interface Repository<T>
          find: T | nil
          save: Boolean
          delete: Boolean
          all: Array<T>
        end

        def sort<T: Comparable<T>>(items: Array<T>): Array<T>
          items.sort
        end
      TRB
    end

    def calculate_stats(times)
      avg = times.sum / times.length.to_f
      min = times.min
      max = times.max
      variance = times.map { |t| (t - avg)**2 }.sum / times.length.to_f
      std_dev = Math.sqrt(variance)

      {
        avg_time: avg,
        min_time: min,
        max_time: max,
        std_dev: std_dev,
        iterations: times.length
      }
    end

    def print_result(name, stats, unit: "ms")
      if unit == "KB"
        puts "  #{name}: #{stats[:memory].round(2)} KB"
      else
        avg_ms = (stats[:avg_time] * 1000).round(3)
        std_ms = (stats[:std_dev] * 1000).round(3)
        puts "  #{name}: #{avg_ms}ms (±#{std_ms}ms)"
      end
    end

    def print_summary
      puts "=" * 60
      puts "SUMMARY"
      puts "=" * 60

      total_time = 0
      @results.each do |category, benchmarks|
        cat_time = benchmarks.values.sum { |b| b[:avg_time] || 0 }
        total_time += cat_time
        puts "#{category}: #{(cat_time * 1000).round(2)}ms total"
      end

      puts "-" * 40
      puts "Total benchmark time: #{(total_time * 1000).round(2)}ms"
    end

    def get_memory_usage
      # Returns memory in KB
      if RUBY_PLATFORM =~ /linux/
        File.read("/proc/#{Process.pid}/statm").split[1].to_i * 4 # pages * 4KB
      else
        # Fallback using GC stats
        GC.stat[:heap_live_slots] * 40 / 1024.0 # approximate
      end
    end
  end

  # Quick benchmark helper
  module QuickBenchmark
    def self.measure(name = "Operation", iterations: 100)
      times = []

      iterations.times do
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
        times << Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      end

      avg = times.sum / times.length
      puts "#{name}: #{(avg * 1000).round(3)}ms avg (#{iterations} iterations)"

      avg
    end

    def self.compare(name, &block)
      before = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = block.call
      after = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      puts "#{name}: #{((after - before) * 1000).round(3)}ms"
      result
    end
  end
end
