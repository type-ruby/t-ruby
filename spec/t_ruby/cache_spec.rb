# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::MemoryCache do
  let(:cache) { TRuby::MemoryCache.new(max_size: 3) }

  describe "#get and #set" do
    it "stores and retrieves values" do
      cache.set("key1", "value1")
      expect(cache.get("key1")).to eq("value1")
    end

    it "returns nil for missing keys" do
      expect(cache.get("nonexistent")).to be_nil
    end

    it "tracks hits and misses" do
      cache.set("key1", "value1")
      cache.get("key1")
      cache.get("nonexistent")

      expect(cache.hits).to eq(1)
      expect(cache.misses).to eq(1)
    end
  end

  describe "LRU eviction" do
    it "evicts least recently used when full" do
      cache.set("a", 1)
      cache.set("b", 2)
      cache.set("c", 3)

      # Access 'a' to make it recently used
      cache.get("a")

      # Add new item, should evict 'b' (least recently used)
      cache.set("d", 4)

      expect(cache.get("a")).to eq(1)
      expect(cache.get("b")).to be_nil # Evicted
      expect(cache.get("c")).to eq(3)
      expect(cache.get("d")).to eq(4)
    end
  end

  describe "#delete" do
    it "removes items" do
      cache.set("key", "value")
      cache.delete("key")
      expect(cache.get("key")).to be_nil
    end
  end

  describe "#clear" do
    it "removes all items" do
      cache.set("a", 1)
      cache.set("b", 2)
      cache.clear
      expect(cache.size).to eq(0)
    end
  end

  describe "#hit_rate" do
    it "calculates hit rate" do
      cache.set("key", "value")
      cache.get("key")
      cache.get("key")
      cache.get("missing")

      expect(cache.hit_rate).to eq(2.0 / 3)
    end

    it "returns 0 when no accesses" do
      expect(cache.hit_rate).to eq(0.0)
    end
  end

  describe "#stats" do
    it "returns cache statistics" do
      cache.set("key", "value")
      cache.get("key")

      stats = cache.stats
      expect(stats[:size]).to eq(1)
      expect(stats[:max_size]).to eq(3)
      expect(stats[:hits]).to eq(1)
    end
  end
end

RSpec.describe TRuby::FileCache do
  let(:cache_dir) { "/tmp/t-ruby-test-cache-#{Process.pid}" }
  let(:cache) { TRuby::FileCache.new(cache_dir: cache_dir, max_age: 60) }

  after do
    FileUtils.rm_rf(cache_dir)
  end

  describe "#get and #set" do
    it "stores and retrieves values" do
      cache.set("key1", { data: "value1" })
      expect(cache.get("key1")).to eq({ data: "value1" })
    end

    it "returns nil for missing keys" do
      expect(cache.get("nonexistent")).to be_nil
    end
  end

  describe "#delete" do
    it "removes cached items" do
      cache.set("key", { value: 1 })
      cache.delete("key")
      expect(cache.get("key")).to be_nil
    end
  end

  describe "#clear" do
    it "removes all cached items" do
      cache.set("a", { x: 1 })
      cache.set("b", { x: 2 })
      cache.clear

      expect(cache.get("a")).to be_nil
      expect(cache.get("b")).to be_nil
    end
  end
end

RSpec.describe TRuby::ParseCache do
  let(:cache) { TRuby::ParseCache.new }

  describe "#get and #set" do
    it "caches parse results" do
      source = "def hello(name: String): String\n  name\nend"
      result = { functions: [{ name: "hello" }] }

      cache.set(source, result)
      expect(cache.get(source)).to eq(result)
    end

    it "returns nil for uncached source" do
      expect(cache.get("uncached")).to be_nil
    end
  end

  describe "#invalidate" do
    it "removes cached entry" do
      source = "def test: void\nend"
      cache.set(source, { functions: [] })
      cache.invalidate(source)
      expect(cache.get(source)).to be_nil
    end
  end
end

RSpec.describe TRuby::TypeResolutionCache do
  let(:cache) { TRuby::TypeResolutionCache.new }

  it "caches type resolutions" do
    cache.set("Array<String>", { container: "Array", element: "String" })
    expect(cache.get("Array<String>")).to eq({ container: "Array", element: "String" })
  end
end

RSpec.describe TRuby::IncrementalCompiler do
  let(:mock_compiler) do
    double("Compiler").tap do |c|
      allow(c).to receive(:compile) { |path| "compiled:#{path}" }
    end
  end

  let(:incremental) { TRuby::IncrementalCompiler.new(mock_compiler) }

  describe "#needs_compile?" do
    it "returns true for new files" do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return("content")

      expect(incremental.needs_compile?("new_file.trb")).to be true
    end
  end

  describe "#add_dependency" do
    it "tracks file dependencies" do
      incremental.add_dependency("a.trb", "b.trb")
      expect(incremental.dependencies["a.trb"]).to include("b.trb")
    end
  end

  describe "#clear" do
    it "clears all caches" do
      incremental.instance_variable_set(:@file_hashes, { "test" => "hash" })
      incremental.clear
      expect(incremental.file_hashes).to be_empty
    end
  end
end

RSpec.describe TRuby::ParallelProcessor do
  let(:processor) { TRuby::ParallelProcessor.new(thread_count: 2) }

  describe "#process_files" do
    it "processes files in parallel" do
      files = ["a.trb", "b.trb", "c.trb"]
      results = processor.process_files(files, &:upcase)

      expect(results).to contain_exactly("A.TRB", "B.TRB", "C.TRB")
    end

    it "handles empty input" do
      expect(processor.process_files([])).to eq([])
    end
  end

  describe "#process_with_queue" do
    it "processes using work queue" do
      files = %w[x y z]
      results = processor.process_with_queue(files) { |f| f * 2 }

      expect(results).to contain_exactly("xx", "yy", "zz")
    end
  end
end

RSpec.describe TRuby::CompilationProfiler do
  let(:profiler) { TRuby::CompilationProfiler.new }

  describe "#profile" do
    it "measures execution time" do
      result = profiler.profile("test") { 1 + 1 }
      expect(result).to eq(2)
    end

    it "accumulates timings" do
      profiler.profile("op") { sleep(0.01) }
      profiler.profile("op") { sleep(0.01) }

      data = profiler.to_h.find { |h| h[:name] == "op" }
      expect(data[:call_count]).to eq(2)
    end
  end

  describe "#reset" do
    it "clears all timings" do
      profiler.profile("test") { nil }
      profiler.reset
      expect(profiler.to_h).to be_empty
    end
  end
end

RSpec.describe TRuby::CacheEntry do
  it "tracks access count" do
    entry = TRuby::CacheEntry.new("key", "value")
    entry.access
    entry.access
    expect(entry.hits).to eq(2)
  end

  it "updates accessed_at on access" do
    entry = TRuby::CacheEntry.new("key", "value")
    first_access = entry.accessed_at
    sleep(0.01)
    entry.access
    expect(entry.accessed_at).to be > first_access
  end

  it "detects stale entries" do
    entry = TRuby::CacheEntry.new("key", "value")
    expect(entry.stale?(0)).to be true
    expect(entry.stale?(1000)).to be false
  end

  describe "#to_h" do
    it "returns hash representation" do
      entry = TRuby::CacheEntry.new("mykey", { data: 123 })
      entry.access
      hash = entry.to_h

      expect(hash[:key]).to eq("mykey")
      expect(hash[:value]).to eq({ data: 123 })
      expect(hash[:created_at]).to be_a(Integer)
      expect(hash[:hits]).to eq(1)
    end
  end
end

RSpec.describe TRuby::FileCache, "stale handling" do
  let(:cache_dir) { "/tmp/t-ruby-test-cache-stale-#{Process.pid}" }
  let(:cache) { TRuby::FileCache.new(cache_dir: cache_dir, max_age: 1) }

  after do
    FileUtils.rm_rf(cache_dir)
  end

  it "returns nil for stale entries" do
    cache.set("key", { value: "test" })
    # Make file appear old
    cache_path = Dir.glob(File.join(cache_dir, "*.json")).first
    FileUtils.touch(cache_path, mtime: Time.now - 10)

    expect(cache.get("key")).to be_nil
  end

  it "handles JSON parse errors gracefully" do
    cache.set("key", { value: "test" })
    cache_path = Dir.glob(File.join(cache_dir, "*.json")).first
    File.write(cache_path, "invalid json {{{")

    expect(cache.get("key")).to be_nil
    expect(File.exist?(cache_path)).to be false # Deleted on error
  end

  describe "#prune" do
    it "removes stale files" do
      cache.set("old", { value: 1 })
      cache.set("new", { value: 2 })

      # Make one file old
      old_path = Dir.glob(File.join(cache_dir, "*.json")).first
      FileUtils.touch(old_path, mtime: Time.now - 10)

      cache.prune
      expect(Dir.glob(File.join(cache_dir, "*.json")).count).to eq(1)
    end
  end
end

RSpec.describe TRuby::ParseCache, "with file cache" do
  let(:cache_dir) { "/tmp/t-ruby-parse-cache-#{Process.pid}" }
  let(:file_cache) { TRuby::FileCache.new(cache_dir: cache_dir) }
  let(:cache) { TRuby::ParseCache.new(file_cache: file_cache) }

  after do
    FileUtils.rm_rf(cache_dir)
  end

  it "falls back to file cache on memory miss" do
    source = "def test: void\nend"
    result = { parsed: true }

    # Set in cache (goes to both memory and file)
    cache.set(source, result)

    # Create new cache instance (empty memory cache)
    new_cache = TRuby::ParseCache.new(file_cache: file_cache)

    # Should get from file cache and populate memory
    expect(new_cache.get(source)).to eq(result)
  end

  describe "#stats" do
    it "returns memory cache stats" do
      stats = cache.stats
      expect(stats).to have_key(:size)
      expect(stats).to have_key(:hits)
      expect(stats).to have_key(:misses)
    end
  end
end

RSpec.describe TRuby::TypeResolutionCache do
  let(:cache) { TRuby::TypeResolutionCache.new }

  describe "#clear" do
    it "clears all entries" do
      cache.set("Type1", :resolved1)
      cache.set("Type2", :resolved2)
      cache.clear
      expect(cache.get("Type1")).to be_nil
      expect(cache.get("Type2")).to be_nil
    end
  end

  describe "#stats" do
    it "returns cache statistics" do
      cache.set("Type", :resolved)
      cache.get("Type")
      cache.get("Missing")

      stats = cache.stats
      expect(stats[:hits]).to eq(1)
      expect(stats[:misses]).to eq(1)
    end
  end
end

RSpec.describe TRuby::DeclarationCache do
  let(:cache_dir) { "/tmp/t-ruby-decl-cache-#{Process.pid}" }
  let(:cache) { TRuby::DeclarationCache.new(cache_dir: cache_dir) }

  after do
    FileUtils.rm_rf(cache_dir)
  end

  it "caches declarations by file path and mtime" do
    Dir.mktmpdir do |tmpdir|
      file_path = File.join(tmpdir, "test.trb")
      File.write(file_path, "def hello: String\nend")

      declarations = { functions: ["hello"] }
      cache.set(file_path, declarations)

      expect(cache.get(file_path)).to eq(declarations)
    end
  end

  it "returns nil for non-existent files" do
    expect(cache.get("/nonexistent/file.trb")).to be_nil
  end

  it "invalidates when file is modified" do
    Dir.mktmpdir do |tmpdir|
      file_path = File.join(tmpdir, "test.trb")
      File.write(file_path, "original")

      cache.set(file_path, { version: 1 })

      # Modify file with different mtime
      sleep(1.1) # File mtime has 1-second resolution on some systems
      File.write(file_path, "modified")

      # Cache should miss due to different mtime
      expect(cache.get(file_path)).to be_nil
    end
  end

  describe "#clear" do
    it "clears both memory and file caches" do
      Dir.mktmpdir do |tmpdir|
        file_path = File.join(tmpdir, "test.trb")
        File.write(file_path, "content")
        cache.set(file_path, { data: 1 })

        cache.clear

        expect(cache.get(file_path)).to be_nil
      end
    end
  end
end

RSpec.describe TRuby::IncrementalCompiler, "additional tests" do
  let(:mock_compiler) do
    double("Compiler").tap do |c|
      allow(c).to receive(:compile) { |path| "result:#{path}" }
    end
  end

  let(:incremental) { TRuby::IncrementalCompiler.new(mock_compiler) }

  describe "#compile" do
    it "compiles and caches result" do
      Dir.mktmpdir do |tmpdir|
        file_path = File.join(tmpdir, "test.trb")
        File.write(file_path, "content")

        result = incremental.compile(file_path)
        expect(result).to eq("result:#{file_path}")

        # Second call should not recompile
        expect(incremental.compile(file_path)).to eq(result)
        expect(mock_compiler).to have_received(:compile).once
      end
    end
  end

  describe "#compile_all" do
    it "compiles only changed files" do
      Dir.mktmpdir do |tmpdir|
        file1 = File.join(tmpdir, "a.trb")
        file2 = File.join(tmpdir, "b.trb")
        File.write(file1, "content1")
        File.write(file2, "content2")

        # First compile
        results = incremental.compile_all([file1, file2])
        expect(results.keys).to contain_exactly(file1, file2)

        # Second compile - nothing changed
        results2 = incremental.compile_all([file1, file2])
        expect(results2).to be_empty
      end
    end
  end

  describe "#update_file_hash" do
    it "updates hash for externally compiled file" do
      Dir.mktmpdir do |tmpdir|
        file_path = File.join(tmpdir, "test.trb")
        File.write(file_path, "original")

        incremental.update_file_hash(file_path)

        # Should not need compile now
        expect(incremental.needs_compile?(file_path)).to be false
      end
    end
  end

  describe "#needs_compile? with dependencies" do
    it "recompiles when dependency changes" do
      Dir.mktmpdir do |tmpdir|
        main = File.join(tmpdir, "main.trb")
        dep = File.join(tmpdir, "dep.trb")
        File.write(main, "main content")
        File.write(dep, "dep content")

        incremental.compile(main)
        incremental.compile(dep)
        incremental.add_dependency(main, dep)

        # Change dependency
        File.write(dep, "new dep content")

        expect(incremental.needs_compile?(main)).to be true
      end
    end
  end
end

RSpec.describe TRuby::CrossFileTypeChecker do
  let(:checker) { TRuby::CrossFileTypeChecker.new }

  describe "#register_file" do
    it "registers types from IR program" do
      ir_program = double("IR::Program")
      type_alias = TRuby::IR::TypeAlias.new(name: "MyType", definition: TRuby::IR::SimpleType.new(name: "String"))
      allow(ir_program).to receive(:declarations).and_return([type_alias])

      checker.register_file("test.trb", ir_program)

      expect(checker.all_types).to include("MyType")
    end

    it "registers interfaces" do
      ir_program = double("IR::Program")
      interface = TRuby::IR::Interface.new(name: "Printable", members: [])
      allow(ir_program).to receive(:declarations).and_return([interface])

      checker.register_file("test.trb", ir_program)

      expect(checker.all_types).to include("Printable")
    end

    it "registers functions" do
      ir_program = double("IR::Program")
      method_def = TRuby::IR::MethodDef.new(
        name: "greet",
        params: [],
        return_type: TRuby::IR::SimpleType.new(name: "String"),
        body: []
      )
      allow(ir_program).to receive(:declarations).and_return([method_def])

      checker.register_file("test.trb", ir_program)

      expect(checker.all_types).to include("greet")
    end
  end

  describe "#find_definition" do
    it "finds where a type is defined" do
      ir_program = double("IR::Program")
      type_alias = TRuby::IR::TypeAlias.new(name: "UserId", definition: TRuby::IR::SimpleType.new(name: "Integer"))
      allow(ir_program).to receive(:declarations).and_return([type_alias])

      checker.register_file("types.trb", ir_program)

      definition = checker.find_definition("UserId")
      expect(definition[:file]).to eq("types.trb")
      expect(definition[:kind]).to eq(:type)
    end
  end

  describe "#check_all" do
    it "returns success when no errors" do
      result = checker.check_all
      expect(result[:success]).to be true
      expect(result[:errors]).to be_empty
    end
  end

  describe "#check_file" do
    it "checks file against global types" do
      ir_program = double("IR::Program")
      param = TRuby::IR::Parameter.new(name: "x", type_annotation: TRuby::IR::SimpleType.new(name: "UnknownType"))
      method_def = TRuby::IR::MethodDef.new(
        name: "test",
        params: [param],
        return_type: nil,
        body: []
      )
      allow(ir_program).to receive(:declarations).and_return([method_def])

      errors = checker.check_file("test.trb", ir_program)
      expect(errors).not_to be_empty
      expect(errors.first[:message]).to include("UnknownType")
    end

    it "accepts known types" do
      ir_program = double("IR::Program")
      param = TRuby::IR::Parameter.new(name: "x", type_annotation: TRuby::IR::SimpleType.new(name: "String"))
      method_def = TRuby::IR::MethodDef.new(
        name: "test",
        params: [param],
        return_type: TRuby::IR::SimpleType.new(name: "Integer"),
        body: []
      )
      allow(ir_program).to receive(:declarations).and_return([method_def])

      errors = checker.check_file("test.trb", ir_program)
      expect(errors).to be_empty
    end
  end

  describe "#clear" do
    it "clears all registrations" do
      ir_program = double("IR::Program")
      type_alias = TRuby::IR::TypeAlias.new(name: "Test", definition: TRuby::IR::SimpleType.new(name: "String"))
      allow(ir_program).to receive(:declarations).and_return([type_alias])

      checker.register_file("test.trb", ir_program)
      checker.clear

      expect(checker.all_types).to be_empty
      expect(checker.file_types).to be_empty
    end
  end
end

RSpec.describe TRuby::EnhancedIncrementalCompiler do
  let(:mock_compiler) do
    double("Compiler").tap do |c|
      allow(c).to receive(:compile) { |path| "result:#{path}" }
      allow(c).to receive(:compile_to_ir) do |_path|
        program = double("IR::Program")
        allow(program).to receive(:declarations).and_return([])
        program
      end
    end
  end

  let(:enhanced) { TRuby::EnhancedIncrementalCompiler.new(mock_compiler) }

  describe "#compile_with_ir" do
    it "caches IR and compiles" do
      Dir.mktmpdir do |tmpdir|
        file_path = File.join(tmpdir, "test.trb")
        File.write(file_path, "content")

        result = enhanced.compile_with_ir(file_path)
        expect(result).to eq("result:#{file_path}")
        expect(enhanced.get_ir(file_path)).not_to be_nil
      end
    end
  end

  describe "#clear" do
    it "clears all caches including IR" do
      Dir.mktmpdir do |tmpdir|
        file_path = File.join(tmpdir, "test.trb")
        File.write(file_path, "content")

        enhanced.compile_with_ir(file_path)
        enhanced.clear

        expect(enhanced.ir_cache).to be_empty
        expect(enhanced.file_hashes).to be_empty
      end
    end
  end
end

RSpec.describe TRuby::CompilationProfiler, "additional tests" do
  let(:profiler) { TRuby::CompilationProfiler.new }

  describe "#report" do
    it "outputs profiling information" do
      profiler.profile("operation") { 1 + 1 }

      output = capture_stdout { profiler.report }
      expect(output).to include("Compilation Profile")
      expect(output).to include("operation")
    end
  end

  describe "#to_h" do
    it "returns structured profiling data" do
      profiler.profile("scan") { nil }
      profiler.profile("parse") { nil }

      data = profiler.to_h
      expect(data.map { |d| d[:name] }).to contain_exactly("scan", "parse")
      expect(data.first).to have_key(:total_time)
      expect(data.first).to have_key(:avg_time)
    end
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
