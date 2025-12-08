# frozen_string_literal: true

require "json"
require "fileutils"
require "net/http"
require "uri"

module TRuby
  # Semantic version parsing and comparison
  class SemanticVersion
    include Comparable

    attr_reader :major, :minor, :patch, :prerelease

    VERSION_REGEX = /^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$/.freeze

    def initialize(version_string)
      match = VERSION_REGEX.match(version_string.to_s)
      raise ArgumentError, "Invalid version: #{version_string}" unless match

      @major = match[1].to_i
      @minor = match[2].to_i
      @patch = match[3].to_i
      @prerelease = match[4]
    end

    def <=>(other)
      return nil unless other.is_a?(SemanticVersion)

      result = [@major, @minor, @patch] <=> [other.major, other.minor, other.patch]
      return result unless result.zero?

      # Both have same version, compare prerelease
      return 0 if @prerelease.nil? && other.prerelease.nil?
      return 1 if @prerelease.nil? # Release > prerelease
      return -1 if other.prerelease.nil?

      @prerelease <=> other.prerelease
    end

    def satisfies?(constraint)
      VersionConstraint.new(constraint).satisfied_by?(self)
    end

    def to_s
      base = "#{@major}.#{@minor}.#{@patch}"
      @prerelease ? "#{base}-#{@prerelease}" : base
    end

    def self.parse(str)
      new(str)
    rescue ArgumentError
      nil
    end
  end

  # Version constraint (^1.0.0, ~>1.0, >=1.0.0 <2.0.0)
  class VersionConstraint
    attr_reader :constraints

    def initialize(constraint_string)
      @constraints = parse_constraints(constraint_string)
    end

    def satisfied_by?(version)
      version = SemanticVersion.new(version) if version.is_a?(String)
      @constraints.all? { |op, target| check_constraint(version, op, target) }
    end

    private

    def parse_constraints(str)
      constraints = []
      parts = str.split(/\s+/)

      i = 0
      while i < parts.length
        part = parts[i]

        case part
        when /^\^(.+)$/ # Caret range: ^1.2.3 means >=1.2.3 <2.0.0
          version = SemanticVersion.new(Regexp.last_match(1))
          constraints << [:>=, version]
          constraints << [:<, SemanticVersion.new("#{version.major + 1}.0.0")]
        when /^~(.+)$/, /^~>(.+)$/ # Tilde range: ~1.2.3 means >=1.2.3 <1.3.0
          version = SemanticVersion.new(Regexp.last_match(1))
          constraints << [:>=, version]
          constraints << [:<, SemanticVersion.new("#{version.major}.#{version.minor + 1}.0")]
        when /^>=(.+)$/
          constraints << [:>=, SemanticVersion.new(Regexp.last_match(1))]
        when /^<=(.+)$/
          constraints << [:<=, SemanticVersion.new(Regexp.last_match(1))]
        when /^>(.+)$/
          constraints << [:>, SemanticVersion.new(Regexp.last_match(1))]
        when /^<(.+)$/
          constraints << [:<, SemanticVersion.new(Regexp.last_match(1))]
        when /^=(.+)$/, /^(\d+\.\d+\.\d+.*)$/
          constraints << [:==, SemanticVersion.new(Regexp.last_match(1))]
        when "*"
          # Match any version
        end

        i += 1
      end

      constraints
    end

    def check_constraint(version, operator, target)
      version.send(operator, target)
    end
  end

  # Package manifest (.trb-manifest.json)
  class PackageManifest
    MANIFEST_FILE = ".trb-manifest.json"

    attr_accessor :name, :version, :description, :author, :license
    attr_accessor :types, :dependencies, :dev_dependencies
    attr_accessor :repository, :keywords, :main

    def initialize(data = {})
      @name = data[:name] || data["name"]
      @version = data[:version] || data["version"] || "0.0.0"
      @description = data[:description] || data["description"]
      @author = data[:author] || data["author"]
      @license = data[:license] || data["license"]
      @types = data[:types] || data["types"] || "lib/types/**/*.d.trb"
      @dependencies = data[:dependencies] || data["dependencies"] || {}
      @dev_dependencies = data[:dev_dependencies] || data["devDependencies"] || {}
      @repository = data[:repository] || data["repository"]
      @keywords = data[:keywords] || data["keywords"] || []
      @main = data[:main] || data["main"]
    end

    def to_h
      {
        name: @name,
        version: @version,
        description: @description,
        author: @author,
        license: @license,
        types: @types,
        dependencies: @dependencies,
        devDependencies: @dev_dependencies,
        repository: @repository,
        keywords: @keywords,
        main: @main
      }.compact
    end

    def to_json(*args)
      JSON.pretty_generate(to_h)
    end

    def save(path = MANIFEST_FILE)
      File.write(path, to_json)
    end

    def self.load(path = MANIFEST_FILE)
      return nil unless File.exist?(path)

      data = JSON.parse(File.read(path))
      new(data)
    rescue JSON::ParserError
      nil
    end

    def valid?
      !@name.nil? && !@name.empty? && !@version.nil?
    end

    def add_dependency(name, version)
      @dependencies[name] = version
    end

    def add_dev_dependency(name, version)
      @dev_dependencies[name] = version
    end

    def remove_dependency(name)
      @dependencies.delete(name)
    end
  end

  # Dependency resolver
  class DependencyResolver
    attr_reader :resolved, :conflicts

    def initialize(registry = nil)
      @registry = registry || PackageRegistry.new
      @resolved = {}
      @conflicts = []
      @in_progress = Set.new
    end

    # Resolve all dependencies for a manifest
    def resolve(manifest)
      @resolved = {}
      @conflicts = []

      manifest.dependencies.each do |name, version_constraint|
        resolve_package(name, version_constraint)
      end

      { resolved: @resolved, conflicts: @conflicts }
    end

    # Check for circular dependencies
    def check_circular(manifest)
      visited = Set.new
      path = []

      check_circular_recursive(manifest.name, manifest.dependencies, visited, path)
    end

    private

    def resolve_package(name, constraint)
      return if @resolved.key?(name)

      if @in_progress.include?(name)
        @conflicts << "Circular dependency detected: #{name}"
        return
      end

      @in_progress.add(name)

      # Find matching version
      available = @registry.get_versions(name)
      matching = find_matching_version(available, constraint)

      if matching
        @resolved[name] = matching

        # Resolve transitive dependencies
        pkg_info = @registry.get_package(name, matching)
        if pkg_info && pkg_info[:dependencies]
          pkg_info[:dependencies].each do |dep_name, dep_constraint|
            resolve_package(dep_name, dep_constraint)
          end
        end
      else
        @conflicts << "No matching version for #{name} (#{constraint})"
      end

      @in_progress.delete(name)
    end

    def find_matching_version(versions, constraint)
      constraint_obj = VersionConstraint.new(constraint)
      versions
        .map { |v| SemanticVersion.parse(v) }
        .compact
        .select { |v| constraint_obj.satisfied_by?(v) }
        .max
        &.to_s
    end

    def check_circular_recursive(name, deps, visited, path)
      return [] if deps.nil? || deps.empty?

      if path.include?(name)
        cycle_start = path.index(name)
        return [path[cycle_start..] + [name]]
      end

      return [] if visited.include?(name)

      visited.add(name)
      path.push(name)

      cycles = []
      deps.each_key do |dep_name|
        pkg = @registry.get_package(dep_name, "*")
        if pkg
          cycles.concat(check_circular_recursive(dep_name, pkg[:dependencies] || {}, visited, path.dup))
        end
      end

      path.pop
      cycles
    end
  end

  # Package registry (local or remote)
  class PackageRegistry
    attr_reader :packages, :local_path

    def initialize(local_path: nil, remote_url: nil)
      @local_path = local_path || ".trb-packages"
      @remote_url = remote_url
      @packages = {}
      FileUtils.mkdir_p(@local_path) if @local_path
    end

    # Register a package
    def register(manifest)
      @packages[manifest.name] ||= {}
      @packages[manifest.name][manifest.version] = {
        dependencies: manifest.dependencies,
        types: manifest.types
      }
    end

    # Get available versions
    def get_versions(name)
      @packages[name]&.keys || []
    end

    # Get specific package info
    def get_package(name, version)
      return nil unless @packages[name]

      if version == "*"
        latest = get_versions(name).map { |v| SemanticVersion.parse(v) }.compact.max
        return nil unless latest
        version = latest.to_s
      end

      @packages[name][version]
    end

    # Load package from local directory
    def load_local(package_dir)
      manifest_path = File.join(package_dir, PackageManifest::MANIFEST_FILE)
      return nil unless File.exist?(manifest_path)

      manifest = PackageManifest.load(manifest_path)
      register(manifest) if manifest&.valid?
      manifest
    end

    # Install package to local cache
    def install(name, version, target_dir = nil)
      target = target_dir || File.join(@local_path, name, version)
      FileUtils.mkdir_p(target)

      pkg = get_package(name, version)
      return nil unless pkg

      # Copy type definitions
      types_pattern = pkg[:types] || "**/*.d.trb"
      # In real implementation, would download from registry

      { name: name, version: version, path: target }
    end

    # Search packages by keyword
    def search(keyword)
      @packages.select do |name, versions|
        name.include?(keyword) ||
          versions.values.any? { |v| v[:keywords]&.include?(keyword) }
      end.keys
    end
  end

  # Package manager main class
  class PackageManager
    attr_reader :manifest, :registry, :resolver

    def initialize(project_dir: ".")
      @project_dir = project_dir
      @manifest = PackageManifest.load(File.join(project_dir, PackageManifest::MANIFEST_FILE))
      @registry = PackageRegistry.new(local_path: File.join(project_dir, ".trb-packages"))
      @resolver = DependencyResolver.new(@registry)
    end

    # Initialize a new package
    def init(name: nil)
      @manifest = PackageManifest.new(
        name: name || File.basename(@project_dir),
        version: "0.1.0",
        types: "lib/types/**/*.d.trb"
      )
      @manifest.save(File.join(@project_dir, PackageManifest::MANIFEST_FILE))
      @manifest
    end

    # Add a dependency
    def add(name, version = "*", dev: false)
      ensure_manifest!

      if dev
        @manifest.add_dev_dependency(name, version)
      else
        @manifest.add_dependency(name, version)
      end

      @manifest.save(File.join(@project_dir, PackageManifest::MANIFEST_FILE))

      # Resolve and install
      install
    end

    # Remove a dependency
    def remove(name)
      ensure_manifest!
      @manifest.remove_dependency(name)
      @manifest.save(File.join(@project_dir, PackageManifest::MANIFEST_FILE))
    end

    # Install all dependencies
    def install
      ensure_manifest!

      result = @resolver.resolve(@manifest)

      if result[:conflicts].any?
        raise "Dependency conflicts: #{result[:conflicts].join(', ')}"
      end

      installed = []
      result[:resolved].each do |name, version|
        pkg = @registry.install(name, version)
        installed << pkg if pkg
      end

      # Generate lockfile
      generate_lockfile(result[:resolved])

      installed
    end

    # Update dependencies
    def update(name = nil)
      ensure_manifest!

      if name
        # Update specific package
        current = @manifest.dependencies[name]
        if current
          @manifest.dependencies[name] = "*" # Get latest
          result = @resolver.resolve(@manifest)
          if result[:resolved][name]
            @manifest.dependencies[name] = "^#{result[:resolved][name]}"
            @manifest.save(File.join(@project_dir, PackageManifest::MANIFEST_FILE))
          end
        end
      else
        # Update all
        @manifest.dependencies.each_key do |dep_name|
          update(dep_name)
        end
      end

      install
    end

    # List installed packages
    def list
      lockfile_path = File.join(@project_dir, ".trb-lock.json")
      return {} unless File.exist?(lockfile_path)

      JSON.parse(File.read(lockfile_path))
    rescue JSON::ParserError
      {}
    end

    # Publish package (stub - would integrate with real registry)
    def publish
      ensure_manifest!

      unless @manifest.valid?
        raise "Invalid manifest: missing name or version"
      end

      # Validate package
      validate_package

      # In real implementation, would upload to registry
      {
        name: @manifest.name,
        version: @manifest.version,
        status: :published
      }
    end

    # Create deprecation notice
    def deprecate(version, message)
      ensure_manifest!

      {
        package: @manifest.name,
        version: version,
        deprecated: true,
        message: message
      }
    end

    private

    def ensure_manifest!
      unless @manifest
        raise "No manifest found. Run 'init' first."
      end
    end

    def generate_lockfile(resolved)
      lockfile = {
        lockfileVersion: 1,
        packages: resolved,
        generatedAt: Time.now.iso8601
      }

      File.write(
        File.join(@project_dir, ".trb-lock.json"),
        JSON.pretty_generate(lockfile)
      )
    end

    def validate_package
      errors = []

      errors << "Missing package name" unless @manifest.name
      errors << "Invalid version" unless SemanticVersion.parse(@manifest.version)

      # Check for type files
      types_pattern = @manifest.types || "**/*.d.trb"
      types_files = Dir.glob(File.join(@project_dir, types_pattern))
      errors << "No type definition files found" if types_files.empty?

      raise errors.join(", ") unless errors.empty?
    end
  end
end
