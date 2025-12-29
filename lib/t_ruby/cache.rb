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
        hits: @hits,
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
        hit_rate: hit_rate,
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
      FileUtils.rm_f(path)
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
      @file_cache = FileCache.new(cache_dir: cache_dir, max_age: 86_400) # 24 hours
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

      current_hash = compute_file_hash(file_path)
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
      @file_hashes[file_path] = compute_file_hash(file_path)
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

    # Update file hash after external compile (for watcher integration)
    def update_file_hash(file_path)
      @file_hashes[file_path] = compute_file_hash(file_path)
    end

    private

    def compute_file_hash(file_path)
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
            file = begin
              queue.pop(true)
            rescue StandardError
              break
            end
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
    rescue StandardError
      4
    end

    def batch_size(total)
      [total / @thread_count, 1].max
    end
  end

  # Cross-file Type Checker
  class CrossFileTypeChecker
    attr_reader :errors, :warnings, :file_types

    def initialize(type_checker: nil)
      @type_checker = type_checker || TypeChecker.new
      @file_types = {} # file_path => { types: [], functions: [], interfaces: [] }
      @global_registry = {} # name => { file: path, kind: :type/:func/:interface, definition: ... }
      @errors = []
      @warnings = []
    end

    # Register types from a file
    def register_file(file_path, ir_program)
      types = []
      functions = []
      interfaces = []

      ir_program.declarations.each do |decl|
        case decl
        when IR::TypeAlias
          types << { name: decl.name, definition: decl.definition }
          register_global(decl.name, file_path, :type, decl)
        when IR::Interface
          interfaces << { name: decl.name, members: decl.members }
          register_global(decl.name, file_path, :interface, decl)
        when IR::MethodDef
          functions << { name: decl.name, params: decl.params, return_type: decl.return_type }
          register_global(decl.name, file_path, :function, decl)
        end
      end

      @file_types[file_path] = { types: types, functions: functions, interfaces: interfaces }
    end

    # Check cross-file type consistency
    def check_all
      @errors = []
      @warnings = []

      # Check for duplicate definitions
      check_duplicate_definitions

      # Check for unresolved type references
      check_unresolved_references

      # Check interface implementations
      check_interface_implementations

      {
        success: @errors.empty?,
        errors: @errors,
        warnings: @warnings,
      }
    end

    # Check a specific file against global types
    def check_file(file_path, ir_program)
      file_errors = []

      ir_program.declarations.each do |decl|
        case decl
        when IR::MethodDef
          # Check parameter types
          decl.params.each do |param|
            next unless param.type_annotation && !type_exists?(param.type_annotation)

            file_errors << {
              file: file_path,
              message: "Unknown type '#{type_name(param.type_annotation)}' in parameter '#{param.name}'",
            }
          end

          # Check return type
          if decl.return_type && !type_exists?(decl.return_type)
            file_errors << {
              file: file_path,
              message: "Unknown return type '#{type_name(decl.return_type)}' in function '#{decl.name}'",
            }
          end
        end
      end

      file_errors
    end

    # Get all registered types
    def all_types
      @global_registry.keys
    end

    # Find where a type is defined
    def find_definition(name)
      @global_registry[name]
    end

    # Clear all registrations
    def clear
      @file_types.clear
      @global_registry.clear
      @errors.clear
      @warnings.clear
    end

    private

    def register_global(name, file_path, kind, definition)
      if @global_registry[name] && @global_registry[name][:file] != file_path
        # Duplicate definition from different file
        @warnings << {
          message: "#{kind.to_s.capitalize} '#{name}' defined in multiple files",
          files: [@global_registry[name][:file], file_path],
        }
      end

      @global_registry[name] = { file: file_path, kind: kind, definition: definition }
    end

    def check_duplicate_definitions
      @global_registry.group_by { |_, v| v[:file] }.each do |file, entries|
        # Check for duplicates within file
        names = entries.map(&:first)
        duplicates = names.select { |n| names.count(n) > 1 }.uniq

        duplicates.each do |name|
          @errors << {
            file: file,
            message: "Duplicate definition of '#{name}'",
          }
        end
      end
    end

    def check_unresolved_references
      @file_types.each do |file_path, info|
        # Check type alias definitions for unresolved types
        info[:types].each do |type_info|
          referenced_types = extract_type_references(type_info[:definition])
          referenced_types.each do |ref|
            next if type_exists_by_name?(ref)

            @errors << {
              file: file_path,
              message: "Unresolved type reference '#{ref}' in type alias '#{type_info[:name]}'",
            }
          end
        end
      end
    end

    def check_interface_implementations
      # For future: check that classes implement all interface methods
    end

    def type_exists?(type_node)
      case type_node
      when IR::SimpleType
        type_exists_by_name?(type_node.name)
      when IR::GenericType
        type_exists_by_name?(type_node.base)
      when IR::UnionType
        type_node.types.all? { |t| type_exists?(t) }
      when IR::IntersectionType
        type_node.types.all? { |t| type_exists?(t) }
      when IR::NullableType
        type_exists?(type_node.inner_type)
      else
        true # Assume valid for unknown types
      end
    end

    def type_exists_by_name?(name)
      return true if %w[String Integer Float Boolean Array Hash Symbol void nil Object Numeric
                        Enumerable].include?(name)
      return true if @global_registry[name]

      false
    end

    def type_name(type_node)
      case type_node
      when IR::SimpleType
        type_node.name
      when IR::GenericType
        "#{type_node.base}<...>"
      else
        type_node.to_s
      end
    end

    def extract_type_references(definition)
      return [] unless definition

      case definition
      when IR::SimpleType
        [definition.name]
      when IR::GenericType
        [definition.base] + definition.type_args.flat_map { |t| extract_type_references(t) }
      when IR::UnionType
        definition.types.flat_map { |t| extract_type_references(t) }
      when IR::IntersectionType
        definition.types.flat_map { |t| extract_type_references(t) }
      when IR::NullableType
        extract_type_references(definition.inner_type)
      else
        []
      end
    end
  end

  # Enhanced Incremental Compiler with IR and Cross-file support
  class EnhancedIncrementalCompiler < IncrementalCompiler
    attr_reader :cross_file_checker, :ir_cache

    def initialize(compiler, cache: nil, enable_cross_file: true)
      super(compiler, cache: cache)
      @ir_cache = {} # file_path => IR::Program
      @cross_file_checker = CrossFileTypeChecker.new if enable_cross_file
    end

    # Compile with IR caching
    def compile_with_ir(file_path)
      return @compiled_files[file_path] unless needs_compile?(file_path)

      # Get IR from compiler
      ir_program = @compiler.compile_to_ir(file_path)
      @ir_cache[file_path] = ir_program

      # Register with cross-file checker
      @cross_file_checker&.register_file(file_path, ir_program)

      # Compile from IR
      result = @compiler.compile(file_path)
      @file_hashes[file_path] = file_hash(file_path)
      @compiled_files[file_path] = result

      result
    end

    # Compile all with cross-file checking
    # Returns diagnostics using unified Diagnostic format
    def compile_all_with_checking(file_paths)
      results = {}
      all_diagnostics = []

      # First pass: compile and register all files
      file_paths.each do |file_path|
        source = File.exist?(file_path) ? File.read(file_path) : nil

        begin
          results[file_path] = compile_with_ir(file_path)
        rescue TypeCheckError => e
          all_diagnostics << Diagnostic.from_type_check_error(e, file: file_path, source: source)
        rescue ParseError => e
          all_diagnostics << Diagnostic.from_parse_error(e, file: file_path, source: source)
        rescue Scanner::ScanError => e
          all_diagnostics << Diagnostic.from_scan_error(e, file: file_path, source: source)
        rescue StandardError => e
          all_diagnostics << Diagnostic.new(
            code: "TR0001",
            message: e.message,
            file: file_path,
            line: 1,
            column: 1
          )
        end
      end

      # Second pass: cross-file type checking
      if @cross_file_checker
        check_result = @cross_file_checker.check_all
        check_result[:errors].each do |e|
          all_diagnostics << Diagnostic.new(
            code: "TR2002",
            message: e[:message],
            file: e[:file],
            line: 1,
            column: 1
          )
        end
      end

      {
        results: results,
        diagnostics: all_diagnostics,
        success: all_diagnostics.empty?,
      }
    end

    # Get cached IR for a file
    def get_ir(file_path)
      @ir_cache[file_path]
    end

    # Clear all caches
    def clear
      super
      @ir_cache.clear
      @cross_file_checker&.clear
    end

    private

    def file_hash(file_path)
      return nil unless File.exist?(file_path)

      Digest::SHA256.hexdigest(File.read(file_path))
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
        puts "#{name}: #{format("%.3f", time)}s total, #{calls} calls, #{format("%.3f", avg * 1000)}ms avg"
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
          avg_time: time / @call_counts[name],
        }
      end
    end
  end
end
