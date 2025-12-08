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
      results = processor.process_files(files) { |f| f.upcase }

      expect(results).to contain_exactly("A.TRB", "B.TRB", "C.TRB")
    end

    it "handles empty input" do
      expect(processor.process_files([])).to eq([])
    end
  end

  describe "#process_with_queue" do
    it "processes using work queue" do
      files = ["x", "y", "z"]
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
end
