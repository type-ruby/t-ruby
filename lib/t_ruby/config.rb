# frozen_string_literal: true

require "yaml"

module TRuby
  class Config
    # New schema structure (v0.0.12+)
    DEFAULT_CONFIG = {
      "source" => {
        "include" => ["src"],
        "exclude" => [],
        "extensions" => [".trb"]
      },
      "output" => {
        "ruby_dir" => "build",
        "rbs_dir" => nil,
        "preserve_structure" => true,
        "clean_before_build" => false
      },
      "compiler" => {
        "strictness" => "standard",
        "generate_rbs" => true,
        "target_ruby" => "3.0",
        "experimental" => [],
        "checks" => {
          "no_implicit_any" => false,
          "no_unused_vars" => false,
          "strict_nil" => false
        }
      },
      "watch" => {
        "paths" => [],
        "debounce" => 100,
        "clear_screen" => false,
        "on_success" => nil
      }
    }.freeze

    # Legacy keys for migration detection
    LEGACY_KEYS = %w[emit paths strict include exclude].freeze

    # Always excluded (not configurable)
    AUTO_EXCLUDE = [".git"].freeze

    attr_reader :source, :output, :compiler, :watch

    def initialize(config_path = nil)
      raw_config = load_raw_config(config_path)
      config = process_config(raw_config)

      @source = config["source"]
      @output = config["output"]
      @compiler = config["compiler"]
      @watch = config["watch"]
    end

    # Backwards compatible: output.ruby_dir
    def out_dir
      @output["ruby_dir"]
    end

    # Backwards compatible: first source.include directory
    def src_dir
      @source["include"].first || "src"
    end

    # Get source include directories
    # @return [Array<String>] list of include directories
    def source_include
      @source["include"] || ["src"]
    end

    # Get source exclude patterns
    # @return [Array<String>] list of exclude patterns
    def source_exclude
      @source["exclude"] || []
    end

    # Get source file extensions
    # @return [Array<String>] list of file extensions (e.g., [".trb", ".truby"])
    def source_extensions
      @source["extensions"] || [".trb"]
    end

    # Get include patterns for file discovery
    def include_patterns
      extensions = @source["extensions"] || [".trb"]
      extensions.map { |ext| "**/*#{ext}" }
    end

    # Get exclude patterns
    def exclude_patterns
      @source["exclude"] || []
    end

    # Find all source files matching include patterns, excluding exclude patterns
    # @return [Array<String>] list of matching file paths
    def find_source_files
      files = []

      @source["include"].each do |include_dir|
        base_dir = File.expand_path(include_dir)
        next unless Dir.exist?(base_dir)

        include_patterns.each do |pattern|
          full_pattern = File.join(base_dir, pattern)
          files.concat(Dir.glob(full_pattern))
        end
      end

      # Filter out excluded files
      files.reject { |f| excluded?(f) }.uniq.sort
    end

    # Check if a file path should be excluded
    # @param file_path [String] absolute or relative file path
    # @return [Boolean] true if file should be excluded
    def excluded?(file_path)
      relative_path = relative_to_src(file_path)
      all_exclude_patterns.any? { |pattern| matches_pattern?(relative_path, pattern) }
    end

    private

    def load_raw_config(config_path)
      if config_path && File.exist?(config_path)
        YAML.safe_load_file(config_path, permitted_classes: [Symbol]) || {}
      elsif File.exist?("trbconfig.yml")
        YAML.safe_load_file("trbconfig.yml", permitted_classes: [Symbol]) || {}
      else
        {}
      end
    end

    def process_config(raw_config)
      if legacy_config?(raw_config)
        warn "DEPRECATED: trbconfig.yml uses legacy format. Please migrate to new schema (source/output/compiler/watch)."
        migrate_legacy_config(raw_config)
      else
        merge_with_defaults(raw_config)
      end
    end

    def legacy_config?(raw_config)
      LEGACY_KEYS.any? { |key| raw_config.key?(key) }
    end

    def migrate_legacy_config(raw_config)
      result = deep_dup(DEFAULT_CONFIG)

      # Migrate emit -> compiler.generate_rbs
      if raw_config["emit"]
        result["compiler"]["generate_rbs"] = raw_config["emit"]["rbs"] if raw_config["emit"].key?("rbs")
      end

      # Migrate paths -> source.include and output.ruby_dir
      if raw_config["paths"]
        if raw_config["paths"]["src"]
          src_path = raw_config["paths"]["src"].sub(%r{^\./}, "")
          result["source"]["include"] = [src_path]
        end
        if raw_config["paths"]["out"]
          out_path = raw_config["paths"]["out"].sub(%r{^\./}, "")
          result["output"]["ruby_dir"] = out_path
        end
      end

      # Migrate include/exclude patterns
      if raw_config["include"]
        # Keep legacy include patterns as-is for now
        result["source"]["include"] = [result["source"]["include"].first || "src"]
      end

      if raw_config["exclude"]
        result["source"]["exclude"] = raw_config["exclude"]
      end

      result
    end

    def merge_with_defaults(user_config)
      result = deep_dup(DEFAULT_CONFIG)
      deep_merge(result, user_config)
      result
    end

    def deep_dup(hash)
      hash.each_with_object({}) do |(key, value), result|
        result[key] = value.is_a?(Hash) ? deep_dup(value) : (value.is_a?(Array) ? value.dup : value)
      end
    end

    def deep_merge(target, source)
      source.each do |key, value|
        if value.is_a?(Hash) && target[key].is_a?(Hash)
          deep_merge(target[key], value)
        elsif !value.nil?
          target[key] = value
        end
      end
    end

    # Combine auto-excluded patterns with user-configured patterns
    def all_exclude_patterns
      patterns = AUTO_EXCLUDE.dup
      patterns << out_dir.sub(%r{^\./}, "") # Add output directory
      patterns.concat(exclude_patterns)
      patterns.uniq
    end

    # Convert absolute path to relative path from first src_dir
    def relative_to_src(file_path)
      base_dir = File.expand_path(src_dir)
      full_path = File.expand_path(file_path)

      if full_path.start_with?(base_dir)
        full_path.sub("#{base_dir}/", "")
      else
        file_path
      end
    end

    # Check if path matches a glob/directory pattern
    def matches_pattern?(path, pattern)
      # Direct directory match (e.g., "node_modules" matches "node_modules/foo.rb")
      return true if path.start_with?("#{pattern}/") || path == pattern

      # Check if any path component matches
      path_parts = path.split("/")
      return true if path_parts.include?(pattern)

      # Glob pattern match
      File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
    end
  end
end
