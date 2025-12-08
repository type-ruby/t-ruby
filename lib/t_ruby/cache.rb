# frozen_string_literal: true

require "digest"
require "json"
require "fileutils"

module TRuby
  # Cache entry with metadata
  class CacheEntry
    attr_reader :key, :value, :created_at, :accessed_at, :hits

    def initialize(key, value)
      @key = key
      @value = value
      @created_at = Time.now
      @accessed_at = Time.now
      @hits = 0
    end

    def access
      @accessed_at = Time.now
      @hits += 1
      @value
    end

    def stale?(max_age)
      Time.now - @created_at > max_age
    end

    def to_h
      {
        key: @key,
        value: @value,
        created_at: @created_at.to_i,
        hits: @hits
      }
    end
  end

  # In-memory LRU cache
  class MemoryCache
    attr_reader :max_size, :hits, :misses

    def initialize(max_size: 1000)
      @max_size = max_size
      @cache = {}
      @access_order = []
      @hits = 0
      @misses = 0
      @mutex = Mutex.new
    end

    def get(key)
      @mutex.synchronize do
        if @cache.key?(key)
          @hits += 1
          touch(key)
          @cache[key].access
        else
          @misses += 1
          nil
        end
      end
    end

    def set(key, value)
      @mutex.synchronize do
        evict if @cache.size >= @max_size && !@cache.key?(key)

        @cache[key] = CacheEntry.new(key, value)
        touch(key)
        value
      end
    end

    def delete(key)
      @mutex.synchronize do
        @cache.delete(key)
        @access_order.delete(key)
      end
    end

    def clear
      @mutex.synchronize do
        @cache.clear
        @access_order.clear
        @hits = 0
        @misses = 0
      end
    end

    def size
      @cache.size
    end

    def hit_rate
      total = @hits + @misses
      return 0.0 if total.zero?
      @hits.to_f / total
    end

    def stats
      {
        size: size,
        max_size: @max_size,
        hits: @hits,
        misses: @misses,
        hit_rate: hit_rate
      }
    end

    private

    def touch(key)
      @access_order.delete(key)
      @access_order.push(key)
    end

    def evict
      return if @access_order.empty?

      # Evict least recently used
      oldest_key = @access_order.shift
      @cache.delete(oldest_key)
    end
  end

  # File-based persistent cache
  class FileCache
    attr_reader :cache_dir, :max_age

    def initialize(cache_dir: ".t-ruby-cache", max_age: 3600)
      @cache_dir = cache_dir
      @max_age = max_age
      FileUtils.mkdir_p(@cache_dir)
    end

    def get(key)
      path = cache_path(key)
      return nil unless File.exist?(path)

      # Check if stale
      if File.mtime(path) < Time.now - @max_age
        File.delete(path)
        return nil
      end

      data = File.read(path)
      JSON.parse(data, symbolize_names: true)
    rescue JSON::ParserError
      File.delete(path)
      nil
    end

    def set(key, value)
      path = cache_path(key)
      File.write(path, JSON.generate(value))
      value
    end

    def delete(key)
      path = cache_path(key)
      File.delete(path) if File.exist?(path)
    end

    def clear
      FileUtils.rm_rf(@cache_dir)
      FileUtils.mkdir_p(@cache_dir)
    end

    def prune
      Dir.glob(File.join(@cache_dir, "*.json")).each do |path|
        File.delete(path) if File.mtime(path) < Time.now - @max_age
      end
    end

    private

    def cache_path(key)
      hash = Digest::SHA256.hexdigest(key.to_s)[0, 16]
      File.join(@cache_dir, "#{hash}.json")
    end
  end

  # AST parse tree cache
  class ParseCache
    def initialize(memory_cache: nil, file_cache: nil)
      @memory_cache = memory_cache || MemoryCache.new(max_size: 500)
      @file_cache = file_cache
    end

    def get(source)
      key = source_key(source)

      # Try memory first
      result = @memory_cache.get(key)
      return result if result

      # Try file cache
      if @file_cache
        result = @file_cache.get(key)
        if result
          @memory_cache.set(key, result)
          return result
        end
      end

      nil
    end

    def set(source, parse_result)
      key = source_key(source)

      @memory_cache.set(key, parse_result)
      @file_cache&.set(key, parse_result)

      parse_result
    end

    def invalidate(source)
      key = source_key(source)
      @memory_cache.delete(key)
      @file_cache&.delete(key)
    end

    def stats
      @memory_cache.stats
    end

    private

    def source_key(source)
      Digest::SHA256.hexdigest(source)
    end
  end

  # Type resolution cache
  class TypeResolutionCache
    def initialize
      @cache = MemoryCache.new(max_size: 2000)
    end

    def get(type_expression)
      @cache.get(type_expression)
    end

    def set(type_expression, resolved_type)
      @cache.set(type_expression, resolved_type)
    end

    def clear
      @cache.clear
    end

    def stats
      @cache.stats
    end
  end

  # Declaration file cache
  class DeclarationCache
    def initialize(cache_dir: ".t-ruby-cache/declarations")
      @file_cache = FileCache.new(cache_dir: cache_dir, max_age: 86400) # 24 hours
      @memory_cache = MemoryCache.new(max_size: 200)
    end

    def get(file_path)
      # Check modification time
      return nil unless File.exist?(file_path)

      mtime = File.mtime(file_path).to_i
      cache_key = "#{file_path}:#{mtime}"

      # Try memory first
      result = @memory_cache.get(cache_key)
      return result if result

      # Try file cache
      result = @file_cache.get(cache_key)
      if result
        @memory_cache.set(cache_key, result)
        return result
      end

      nil
    end

    def set(file_path, declarations)
      mtime = File.mtime(file_path).to_i
      cache_key = "#{file_path}:#{mtime}"

      @memory_cache.set(cache_key, declarations)
      @file_cache.set(cache_key, declarations)

      declarations
    end

    def clear
      @memory_cache.clear
      @file_cache.clear
    end
  end

  # Incremental compilation support
  class IncrementalCompiler
    attr_reader :file_hashes, :dependencies

    def initialize(compiler, cache: nil)
      @compiler = compiler
      @cache = cache || ParseCache.new
      @file_hashes = {}
      @dependencies = {}
      @compiled_files = {}
    end

    # Check if file needs recompilation
    def needs_compile?(file_path)
      return true unless File.exist?(file_path)

      current_hash = file_hash(file_path)
      stored_hash = @file_hashes[file_path]

      return true if stored_hash.nil? || stored_hash != current_hash

      # Check dependencies
      deps = @dependencies[file_path] || []
      deps.any? { |dep| needs_compile?(dep) }
    end

    # Compile file with caching
    def compile(file_path)
      return @compiled_files[file_path] unless needs_compile?(file_path)

      result = @compiler.compile(file_path)
      @file_hashes[file_path] = file_hash(file_path)
      @compiled_files[file_path] = result

      result
    end

    # Compile multiple files, skipping unchanged
    def compile_all(file_paths)
      results = {}
      to_compile = file_paths.select { |f| needs_compile?(f) }

      to_compile.each do |file_path|
        results[file_path] = compile(file_path)
      end

      results
    end

    # Register dependency between files
    def add_dependency(file_path, depends_on)
      @dependencies[file_path] ||= []
      @dependencies[file_path] << depends_on unless @dependencies[file_path].include?(depends_on)
    end

    # Clear compilation cache
    def clear
      @file_hashes.clear
      @dependencies.clear
      @compiled_files.clear
      @cache.stats # Just accessing for potential cleanup
    end

    private

    def file_hash(file_path)
      return nil unless File.exist?(file_path)
      Digest::SHA256.hexdigest(File.read(file_path))
    end
  end

  # Parallel file processor
  class ParallelProcessor
    attr_reader :thread_count

    def initialize(thread_count: nil)
      @thread_count = thread_count || determine_thread_count
    end

    # Process files in parallel
    def process_files(file_paths, &block)
      return [] if file_paths.empty?

      # Split into batches
      batches = file_paths.each_slice(batch_size(file_paths.length)).to_a

      results = []
      mutex = Mutex.new

      threads = batches.map do |batch|
        Thread.new do
          batch_results = batch.map { |file| block.call(file) }
          mutex.synchronize { results.concat(batch_results) }
        end
      end

      threads.each(&:join)
      results
    end

    # Process with work stealing
    def process_with_queue(file_paths, &block)
      queue = Queue.new
      file_paths.each { |f| queue << f }

      results = []
      mutex = Mutex.new

      threads = @thread_count.times.map do
        Thread.new do
          loop do
            file = queue.pop(true) rescue break
            result = block.call(file)
            mutex.synchronize { results << result }
          end
        end
      end

      threads.each(&:join)
      results
    end

    private

    def determine_thread_count
      # Use number of CPU cores, max 8
      [Etc.nprocessors, 8].min
    rescue
      4
    end

    def batch_size(total)
      [total / @thread_count, 1].max
    end
  end

  # Compilation profiler
  class CompilationProfiler
    def initialize
      @timings = {}
      @call_counts = {}
    end

    def profile(name, &block)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = block.call
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

      @timings[name] ||= 0.0
      @timings[name] += elapsed

      @call_counts[name] ||= 0
      @call_counts[name] += 1

      result
    end

    def report
      puts "=== Compilation Profile ==="
      @timings.sort_by { |_, v| -v }.each do |name, time|
        calls = @call_counts[name]
        avg = time / calls
        puts "#{name}: #{format('%.3f', time)}s total, #{calls} calls, #{format('%.3f', avg * 1000)}ms avg"
      end
    end

    def reset
      @timings.clear
      @call_counts.clear
    end

    def to_h
      @timings.map do |name, time|
        {
          name: name,
          total_time: time,
          call_count: @call_counts[name],
          avg_time: time / @call_counts[name]
        }
      end
    end
  end
end
