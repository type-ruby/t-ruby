# frozen_string_literal: true

require "fileutils"
require "time"

module TRuby
  # Integrates T-Ruby type packages with Bundler/RubyGems ecosystem
  class BundlerIntegration
    TYPES_GROUP = :types
    TYPE_SUFFIX = "-types"
    GEMFILE = "Gemfile"
    GEMFILE_LOCK = "Gemfile.lock"

    attr_reader :project_dir, :errors

    def initialize(project_dir: ".")
      @project_dir = project_dir
      @errors = []
      @type_gems = {}
    end

    # Check if project uses Bundler
    def bundler_project?
      File.exist?(gemfile_path)
    end

    # Initialize T-Ruby types support in existing Bundler project
    def init
      unless bundler_project?
        @errors << "No Gemfile found. Run 'bundle init' first."
        return false
      end

      add_types_group_to_gemfile unless types_group_exists?
      create_types_directory
      true
    end

    # Find type packages for installed gems
    def discover_type_packages
      return {} unless bundler_project?

      installed_gems = parse_gemfile_lock
      type_packages = {}

      installed_gems.each_key do |gem_name|
        type_gem = find_type_gem(gem_name)
        type_packages[gem_name] = type_gem if type_gem
      end

      type_packages
    end

    # Add a type package dependency
    def add_type_gem(gem_name, version: nil)
      type_gem_name = "#{gem_name}#{TYPE_SUFFIX}"
      version_constraint = version || ">= 0"

      append_to_gemfile(type_gem_name, version_constraint, group: TYPES_GROUP)
      @type_gems[gem_name] = { name: type_gem_name, version: version_constraint }

      { gem: type_gem_name, version: version_constraint, status: :added }
    end

    # Remove a type package dependency
    def remove_type_gem(gem_name)
      type_gem_name = "#{gem_name}#{TYPE_SUFFIX}"
      remove_from_gemfile(type_gem_name)
      @type_gems.delete(gem_name)

      { gem: type_gem_name, status: :removed }
    end

    # Sync type definitions from installed type gems
    def sync_types
      return { synced: [], errors: @errors } unless bundler_project?

      synced = []
      type_gems = find_installed_type_gems

      type_gems.each do |gem_info|
        result = sync_gem_types(gem_info)
        synced << result if result[:success]
      end

      { synced: synced, errors: @errors }
    end

    # Generate a .trb-bundle.json manifest for compatibility
    def generate_bundle_manifest
      manifest = {
        bundler_integration: true,
        version: TRuby::VERSION,
        types_group: TYPES_GROUP.to_s,
        type_gems: list_type_gems,
        local_types: list_local_types,
        generated_at: Time.now.iso8601,
      }

      manifest_path = File.join(@project_dir, ".trb-bundle.json")
      File.write(manifest_path, JSON.pretty_generate(manifest))
      manifest_path
    end

    # Load type definitions from Bundler-managed gems
    def load_bundled_types
      type_definitions = {}

      find_installed_type_gems.each do |gem_info|
        defs = load_gem_type_definitions(gem_info)
        type_definitions.merge!(defs)
      end

      # Also load local types
      local_types = load_local_type_definitions
      type_definitions.merge!(local_types)

      type_definitions
    end

    # Check compatibility between gem version and type version
    def check_version_compatibility
      issues = []
      gemfile_lock = parse_gemfile_lock

      @type_gems.each do |base_gem, type_info|
        base_version = gemfile_lock[base_gem]
        type_version = gemfile_lock[type_info[:name]]

        next unless base_version && type_version

        next if versions_compatible?(base_version, type_version)

        issues << {
          gem: base_gem,
          gem_version: base_version,
          type_gem: type_info[:name],
          type_version: type_version,
          message: "Version mismatch: #{base_gem}@#{base_version} vs #{type_info[:name]}@#{type_version}",
        }
      end

      issues
    end

    # Create a new type gem scaffold
    def create_type_gem_scaffold(gem_name, output_dir: nil)
      type_gem_name = "#{gem_name}#{TYPE_SUFFIX}"
      output = output_dir || File.join(@project_dir, type_gem_name)

      FileUtils.mkdir_p(output)
      FileUtils.mkdir_p(File.join(output, "lib", type_gem_name.gsub("-", "_")))
      FileUtils.mkdir_p(File.join(output, "sig"))

      # Create gemspec
      create_type_gemspec(type_gem_name, gem_name, output)

      # Create main type file
      create_main_type_file(type_gem_name, gem_name, output)

      # Create README
      create_type_gem_readme(type_gem_name, gem_name, output)

      { path: output, gem_name: type_gem_name, status: :created }
    end

    private

    def gemfile_path
      File.join(@project_dir, GEMFILE)
    end

    def gemfile_lock_path
      File.join(@project_dir, GEMFILE_LOCK)
    end

    def types_group_exists?
      return false unless File.exist?(gemfile_path)

      content = File.read(gemfile_path)
      content.include?("group :#{TYPES_GROUP}") || content.include?("group :types")
    end

    def add_types_group_to_gemfile
      content = File.read(gemfile_path)

      types_group = <<~RUBY

        # T-Ruby type definitions
        group :types do
          # Add type gems here, e.g.:
          # gem 'rails-types', '~> 7.0'
        end
      RUBY

      File.write(gemfile_path, content + types_group)
    end

    def create_types_directory
      types_dir = File.join(@project_dir, "types")
      FileUtils.mkdir_p(types_dir)

      # Create a sample .d.trb file
      sample_path = File.join(types_dir, "custom.d.trb")
      return if File.exist?(sample_path)

      File.write(sample_path, <<~TRB)
        # Custom type definitions for your project
        # These types are available throughout your T-Ruby code

        # Example type alias
        # type UserId = String

        # Example interface
        # interface Serializable
        #   to_json: String
        #   from_json: (String) -> self
        # end
      TRB
    end

    def append_to_gemfile(gem_name, version, group:)
      content = File.read(gemfile_path)

      # Find the types group and add gem there
      if content.include?("group :#{group}")
        # Add inside existing group
        new_content = content.gsub(
          /(group :#{group}.*?do\s*\n)/m,
          "\\1  gem '#{gem_name}', '#{version}'\n"
        )
        File.write(gemfile_path, new_content)
      else
        # Create group with gem
        File.write(gemfile_path, content + <<~RUBY)

          group :#{group} do
            gem '#{gem_name}', '#{version}'
          end
        RUBY
      end
    end

    def remove_from_gemfile(gem_name)
      content = File.read(gemfile_path)
      new_content = content.gsub(/^\s*gem ['"]#{gem_name}['"].*$\n?/, "")
      File.write(gemfile_path, new_content)
    end

    def parse_gemfile_lock
      return {} unless File.exist?(gemfile_lock_path)

      gems = {}
      in_specs = false

      File.readlines(gemfile_lock_path).each do |line|
        if line.strip == "specs:"
          in_specs = true
          next
        end

        if in_specs && line.match?(/^\s{4}(\S+)\s+\((.+)\)/)
          match = line.match(/^\s{4}(\S+)\s+\((.+)\)/)
          gems[match[1]] = match[2]
        end

        in_specs = false if in_specs && !line.start_with?("  ")
      end

      gems
    end

    def find_type_gem(gem_name)
      type_gem_name = "#{gem_name}#{TYPE_SUFFIX}"

      # Check if type gem exists in known registries
      # This is a simplified check - in production would query RubyGems API
      {
        name: type_gem_name,
        available: check_gem_availability(type_gem_name),
      }
    end

    def check_gem_availability(gem_name)
      # Simplified availability check
      # In production, would use: Gem::SpecFetcher.fetcher.detect(:latest)
      # For now, return based on common type packages
      common_type_gems = %w[
        rails-types
        activerecord-types
        activesupport-types
        rspec-types
        sidekiq-types
        redis-types
        pg-types
      ]

      common_type_gems.include?(gem_name)
    end

    def find_installed_type_gems
      gems = parse_gemfile_lock
      gems.select { |name, _| name.end_with?(TYPE_SUFFIX) }.map do |name, version|
        base_gem = name.sub(/#{TYPE_SUFFIX}$/, "")
        {
          name: name,
          base_gem: base_gem,
          version: version,
          path: find_gem_path(name, version),
        }
      end
    end

    def find_gem_path(gem_name, version)
      # Try to find gem in standard locations
      possible_paths = [
        File.join(ENV["GEM_HOME"] || "", "gems", "#{gem_name}-#{version}"),
        File.join(Dir.home, ".gem", "ruby", "*", "gems", "#{gem_name}-#{version}"),
        File.join(@project_dir, "vendor", "bundle", "**", "gems", "#{gem_name}-#{version}"),
      ]

      possible_paths.each do |pattern|
        matches = Dir.glob(pattern)
        return matches.first if matches.any?
      end

      nil
    end

    def sync_gem_types(gem_info)
      return { success: false, gem: gem_info[:name] } unless gem_info[:path]

      # Look for type definitions in the gem
      type_files = Dir.glob(File.join(gem_info[:path], "**", "*.d.trb"))
      rbs_files = Dir.glob(File.join(gem_info[:path], "sig", "**", "*.rbs"))

      target_dir = File.join(@project_dir, ".trb-types", gem_info[:name])
      FileUtils.mkdir_p(target_dir)

      copied = []

      (type_files + rbs_files).each do |file|
        target = File.join(target_dir, File.basename(file))
        FileUtils.cp(file, target)
        copied << target
      end

      { success: true, gem: gem_info[:name], files: copied }
    end

    def load_gem_type_definitions(gem_info)
      definitions = {}
      return definitions unless gem_info[:path]

      type_files = Dir.glob(File.join(gem_info[:path], "**", "*.d.trb"))

      type_files.each do |file|
        content = File.read(file)
        parsed = parse_type_definitions(content)
        definitions.merge!(parsed)
      end

      definitions
    end

    def load_local_type_definitions
      definitions = {}
      types_dir = File.join(@project_dir, "types")

      return definitions unless Dir.exist?(types_dir)

      Dir.glob(File.join(types_dir, "**", "*.d.trb")).each do |file|
        content = File.read(file)
        parsed = parse_type_definitions(content)
        definitions.merge!(parsed)
      end

      definitions
    end

    def parse_type_definitions(content)
      definitions = {}

      # Parse type aliases
      content.scan(/^\s*type\s+(\w+)\s*=\s*(.+)$/).each do |match|
        definitions[match[0]] = { kind: :alias, definition: match[1] }
      end

      # Parse interfaces
      content.scan(/^\s*interface\s+(\w+)/).each do |match|
        definitions[match[0]] = { kind: :interface }
      end

      definitions
    end

    def list_type_gems
      find_installed_type_gems.map do |gem_info|
        {
          name: gem_info[:name],
          base_gem: gem_info[:base_gem],
          version: gem_info[:version],
        }
      end
    end

    def list_local_types
      types_dir = File.join(@project_dir, "types")
      return [] unless Dir.exist?(types_dir)

      Dir.glob(File.join(types_dir, "**", "*.d.trb")).map do |file|
        File.basename(file)
      end
    end

    def versions_compatible?(gem_version, type_version)
      # Check if major.minor versions match
      gem_parts = gem_version.split(".")
      type_parts = type_version.split(".")

      gem_parts[0] == type_parts[0] && gem_parts[1] == type_parts[1]
    end

    def create_type_gemspec(type_gem_name, base_gem, output_dir)
      gemspec_content = <<~RUBY
        # frozen_string_literal: true

        Gem::Specification.new do |spec|
          spec.name          = "#{type_gem_name}"
          spec.version       = "0.1.0"
          spec.authors       = ["Your Name"]
          spec.email         = ["your.email@example.com"]

          spec.summary       = "T-Ruby type definitions for #{base_gem}"
          spec.description   = "Type definitions for #{base_gem} to be used with T-Ruby"
          spec.homepage      = "https://github.com/your-username/#{type_gem_name}"
          spec.license       = "MIT"
          spec.required_ruby_version = ">= 3.0.0"

          spec.metadata["rubygems_mfa_required"] = "true"
          spec.metadata["source_code_uri"] = spec.homepage
          spec.metadata["changelog_uri"] = "\#{spec.homepage}/blob/main/CHANGELOG.md"

          spec.files = Dir.glob("{lib,sig}/**/*") + %w[README.md LICENSE.txt]
          spec.require_paths = ["lib"]

          # Match the base gem version
          spec.add_dependency "#{base_gem}"
        end
      RUBY

      File.write(File.join(output_dir, "#{type_gem_name}.gemspec"), gemspec_content)
    end

    def create_main_type_file(type_gem_name, base_gem, output_dir)
      module_name = type_gem_name.gsub("-", "_").split("_").map(&:capitalize).join
      lib_dir = File.join(output_dir, "lib", type_gem_name.gsub("-", "_"))

      main_file = <<~RUBY
        # frozen_string_literal: true

        # Type definitions for #{base_gem}
        # Auto-generated scaffold - customize as needed

        module #{module_name}
          VERSION = "0.1.0"
        end
      RUBY

      File.write(File.join(lib_dir, "version.rb"), main_file)

      # Create types directory and sample file
      types_dir = File.join(output_dir, "sig")
      FileUtils.mkdir_p(types_dir)

      types_file = <<~TRB
        # Type definitions for #{base_gem}
        # Add your type definitions here

        # Example:
        # interface #{base_gem.capitalize}Client
        #   connect: (String) -> Boolean
        #   disconnect: () -> void
        # end
      TRB

      File.write(File.join(types_dir, "#{base_gem}.d.trb"), types_file)
    end

    def create_type_gem_readme(type_gem_name, base_gem, output_dir)
      readme = <<~MARKDOWN
        # #{type_gem_name}

        T-Ruby type definitions for [#{base_gem}](https://rubygems.org/gems/#{base_gem}).

        ## Installation

        Add this line to your Gemfile:

        ```ruby
        group :types do
          gem '#{type_gem_name}'
        end
        ```

        Then run:

        ```bash
        bundle install
        ```

        ## Usage

        The type definitions will be automatically loaded by T-Ruby when compiling your `.trb` files.

        ## Contributing

        Bug reports and pull requests are welcome.

        ## License

        MIT License
      MARKDOWN

      File.write(File.join(output_dir, "README.md"), readme)
    end
  end

  # Extension to PackageManager for Bundler support
  class PackageManager
    attr_reader :bundler

    def initialize(project_dir: ".")
      @project_dir = project_dir
      @manifest = PackageManifest.load(File.join(project_dir, PackageManifest::MANIFEST_FILE))
      @registry = PackageRegistry.new(local_path: File.join(project_dir, ".trb-packages"))
      @resolver = DependencyResolver.new(@registry)
      @bundler = BundlerIntegration.new(project_dir: project_dir)
    end

    # Use Bundler if available, fall back to native package management
    def install_with_bundler_fallback
      if @bundler.bundler_project?
        @bundler.sync_types
      else
        install
      end
    end

    # Migrate from native T-Ruby packages to Bundler
    def migrate_to_bundler
      return { success: false, error: "Not a Bundler project" } unless @bundler.bundler_project?

      migrated = []

      # Read existing T-Ruby manifest
      @manifest&.dependencies&.each do |name, version|
        result = @bundler.add_type_gem(name, version: version)
        migrated << result
      end

      # Generate new bundle manifest
      @bundler.generate_bundle_manifest

      { success: true, migrated: migrated }
    end
  end
end
