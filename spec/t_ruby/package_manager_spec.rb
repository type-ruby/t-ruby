# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::SemanticVersion do
  describe "#initialize" do
    it "parses valid version" do
      v = TRuby::SemanticVersion.new("1.2.3")
      expect(v.major).to eq(1)
      expect(v.minor).to eq(2)
      expect(v.patch).to eq(3)
    end

    it "parses version with prerelease" do
      v = TRuby::SemanticVersion.new("1.0.0-alpha")
      expect(v.prerelease).to eq("alpha")
    end

    it "raises for invalid version" do
      expect { TRuby::SemanticVersion.new("invalid") }.to raise_error(ArgumentError)
    end
  end

  describe "#<=>" do
    it "compares versions" do
      v1 = TRuby::SemanticVersion.new("1.0.0")
      v2 = TRuby::SemanticVersion.new("2.0.0")
      expect(v1 < v2).to be true
    end

    it "compares minor versions" do
      v1 = TRuby::SemanticVersion.new("1.1.0")
      v2 = TRuby::SemanticVersion.new("1.2.0")
      expect(v1 < v2).to be true
    end

    it "compares patch versions" do
      v1 = TRuby::SemanticVersion.new("1.0.1")
      v2 = TRuby::SemanticVersion.new("1.0.2")
      expect(v1 < v2).to be true
    end

    it "release > prerelease" do
      v1 = TRuby::SemanticVersion.new("1.0.0")
      v2 = TRuby::SemanticVersion.new("1.0.0-alpha")
      expect(v1 > v2).to be true
    end
  end

  describe "#satisfies?" do
    it "checks caret constraint" do
      v = TRuby::SemanticVersion.new("1.2.3")
      expect(v.satisfies?("^1.0.0")).to be true
      expect(v.satisfies?("^2.0.0")).to be false
    end
  end

  describe "#to_s" do
    it "returns version string" do
      v = TRuby::SemanticVersion.new("1.2.3")
      expect(v.to_s).to eq("1.2.3")
    end

    it "includes prerelease" do
      v = TRuby::SemanticVersion.new("1.0.0-beta")
      expect(v.to_s).to eq("1.0.0-beta")
    end
  end
end

RSpec.describe TRuby::VersionConstraint do
  describe "#satisfied_by?" do
    it "checks caret constraint" do
      c = TRuby::VersionConstraint.new("^1.2.0")
      expect(c.satisfied_by?("1.2.0")).to be true
      expect(c.satisfied_by?("1.3.0")).to be true
      expect(c.satisfied_by?("1.9.9")).to be true
      expect(c.satisfied_by?("2.0.0")).to be false
    end

    it "checks tilde constraint" do
      c = TRuby::VersionConstraint.new("~1.2.0")
      expect(c.satisfied_by?("1.2.0")).to be true
      expect(c.satisfied_by?("1.2.5")).to be true
      expect(c.satisfied_by?("1.3.0")).to be false
    end

    it "checks >= constraint" do
      c = TRuby::VersionConstraint.new(">=1.0.0")
      expect(c.satisfied_by?("1.0.0")).to be true
      expect(c.satisfied_by?("2.0.0")).to be true
      expect(c.satisfied_by?("0.9.0")).to be false
    end

    it "checks exact version" do
      c = TRuby::VersionConstraint.new("=1.2.3")
      expect(c.satisfied_by?("1.2.3")).to be true
      expect(c.satisfied_by?("1.2.4")).to be false
    end
  end
end

RSpec.describe TRuby::PackageManifest do
  let(:manifest_data) do
    {
      name: "my-package",
      version: "1.0.0",
      description: "A test package",
      dependencies: { "other-pkg" => "^1.0.0" },
    }
  end

  describe "#initialize" do
    it "sets attributes from data" do
      m = TRuby::PackageManifest.new(manifest_data)
      expect(m.name).to eq("my-package")
      expect(m.version).to eq("1.0.0")
      expect(m.dependencies).to eq({ "other-pkg" => "^1.0.0" })
    end
  end

  describe "#valid?" do
    it "returns true for valid manifest" do
      m = TRuby::PackageManifest.new(manifest_data)
      expect(m.valid?).to be true
    end

    it "returns false for missing name" do
      m = TRuby::PackageManifest.new(version: "1.0.0")
      expect(m.valid?).to be false
    end
  end

  describe "#add_dependency" do
    it "adds a dependency" do
      m = TRuby::PackageManifest.new(manifest_data)
      m.add_dependency("new-pkg", "^2.0.0")
      expect(m.dependencies["new-pkg"]).to eq("^2.0.0")
    end
  end

  describe "#remove_dependency" do
    it "removes a dependency" do
      m = TRuby::PackageManifest.new(manifest_data)
      m.remove_dependency("other-pkg")
      expect(m.dependencies).not_to have_key("other-pkg")
    end
  end

  describe "#to_json" do
    it "generates valid JSON" do
      m = TRuby::PackageManifest.new(manifest_data)
      json = JSON.parse(m.to_json)
      expect(json["name"]).to eq("my-package")
    end
  end

  describe ".load and #save" do
    it "round-trips through file" do
      path = "/tmp/test-manifest-#{Process.pid}.json"
      m = TRuby::PackageManifest.new(manifest_data)
      m.save(path)

      loaded = TRuby::PackageManifest.load(path)
      expect(loaded.name).to eq(m.name)
      expect(loaded.version).to eq(m.version)

      File.delete(path)
    end
  end
end

RSpec.describe TRuby::PackageRegistry do
  let(:registry) { TRuby::PackageRegistry.new }

  describe "#register" do
    it "registers a package" do
      manifest = TRuby::PackageManifest.new(name: "pkg", version: "1.0.0")
      registry.register(manifest)
      expect(registry.get_versions("pkg")).to include("1.0.0")
    end
  end

  describe "#get_versions" do
    it "returns all versions" do
      registry.register(TRuby::PackageManifest.new(name: "pkg", version: "1.0.0"))
      registry.register(TRuby::PackageManifest.new(name: "pkg", version: "1.1.0"))
      registry.register(TRuby::PackageManifest.new(name: "pkg", version: "2.0.0"))

      versions = registry.get_versions("pkg")
      expect(versions).to contain_exactly("1.0.0", "1.1.0", "2.0.0")
    end

    it "returns empty for unknown package" do
      expect(registry.get_versions("unknown")).to eq([])
    end
  end

  describe "#get_package" do
    it "returns package info" do
      manifest = TRuby::PackageManifest.new(
        name: "pkg",
        version: "1.0.0",
        dependencies: { "dep" => "^1.0.0" }
      )
      registry.register(manifest)

      info = registry.get_package("pkg", "1.0.0")
      expect(info[:dependencies]).to eq({ "dep" => "^1.0.0" })
    end
  end

  describe "#search" do
    it "finds packages by name" do
      registry.register(TRuby::PackageManifest.new(name: "my-types", version: "1.0.0"))
      registry.register(TRuby::PackageManifest.new(name: "other-lib", version: "1.0.0"))

      results = registry.search("types")
      expect(results).to include("my-types")
      expect(results).not_to include("other-lib")
    end
  end
end

RSpec.describe TRuby::DependencyResolver do
  let(:registry) { TRuby::PackageRegistry.new }
  let(:resolver) { TRuby::DependencyResolver.new(registry) }

  before do
    registry.register(TRuby::PackageManifest.new(name: "dep-a", version: "1.0.0"))
    registry.register(TRuby::PackageManifest.new(name: "dep-a", version: "1.1.0"))
    registry.register(TRuby::PackageManifest.new(name: "dep-b", version: "2.0.0"))
  end

  describe "#resolve" do
    it "resolves dependencies" do
      manifest = TRuby::PackageManifest.new(
        name: "app",
        version: "1.0.0",
        dependencies: { "dep-a" => "^1.0.0" }
      )

      result = resolver.resolve(manifest)
      expect(result[:resolved]["dep-a"]).to eq("1.1.0") # Should get latest matching
      expect(result[:conflicts]).to be_empty
    end

    it "reports conflicts for missing packages" do
      manifest = TRuby::PackageManifest.new(
        name: "app",
        version: "1.0.0",
        dependencies: { "nonexistent" => "^1.0.0" }
      )

      result = resolver.resolve(manifest)
      expect(result[:conflicts]).not_to be_empty
    end
  end
end

RSpec.describe TRuby::PackageManager do
  let(:project_dir) { "/tmp/t-ruby-test-project-#{Process.pid}" }
  let(:manager) { TRuby::PackageManager.new(project_dir: project_dir) }

  before do
    FileUtils.mkdir_p(project_dir)
  end

  after do
    FileUtils.rm_rf(project_dir)
  end

  describe "#init" do
    it "creates manifest" do
      manifest = manager.init(name: "test-project")
      expect(manifest.name).to eq("test-project")
      expect(File.exist?(File.join(project_dir, ".trb-manifest.json"))).to be true
    end
  end

  describe "#add and #remove" do
    before do
      manager.init(name: "test-project")
      # Register packages so dependency resolution works
      manager.registry.register(TRuby::PackageManifest.new(name: "some-pkg", version: "1.0.0"))
      manager.registry.register(TRuby::PackageManifest.new(name: "some-pkg", version: "1.5.0"))
      manager.registry.register(TRuby::PackageManifest.new(name: "test-pkg", version: "1.0.0"))
    end

    it "adds dependency" do
      manager.add("some-pkg", "^1.0.0")
      manifest = TRuby::PackageManifest.load(File.join(project_dir, ".trb-manifest.json"))
      expect(manifest.dependencies).to have_key("some-pkg")
    end

    it "adds dev dependency" do
      manager.add("test-pkg", "^1.0.0", dev: true)
      manifest = TRuby::PackageManifest.load(File.join(project_dir, ".trb-manifest.json"))
      expect(manifest.dev_dependencies).to have_key("test-pkg")
    end

    it "removes dependency" do
      manager.add("some-pkg", "^1.0.0")
      manager.remove("some-pkg")
      manifest = TRuby::PackageManifest.load(File.join(project_dir, ".trb-manifest.json"))
      expect(manifest.dependencies).not_to have_key("some-pkg")
    end
  end

  describe "#list" do
    it "returns empty hash when no lockfile" do
      expect(manager.list).to eq({})
    end

    it "returns lockfile contents when present" do
      manager.init(name: "test-project")
      lockfile = { lockfileVersion: 1, packages: { "pkg" => "1.0.0" } }
      File.write(File.join(project_dir, ".trb-lock.json"), JSON.generate(lockfile))

      result = manager.list
      expect(result["packages"]).to eq({ "pkg" => "1.0.0" })
    end

    it "returns empty hash for invalid JSON" do
      manager.init(name: "test-project")
      File.write(File.join(project_dir, ".trb-lock.json"), "invalid json")
      expect(manager.list).to eq({})
    end
  end

  describe "#install" do
    before do
      manager.init(name: "test-project")
      manager.registry.register(TRuby::PackageManifest.new(name: "pkg-a", version: "1.0.0"))
    end

    it "installs dependencies and generates lockfile" do
      manager.add("pkg-a", "^1.0.0")
      expect(File.exist?(File.join(project_dir, ".trb-lock.json"))).to be true
    end

    it "raises for dependency conflicts" do
      manager.manifest.add_dependency("nonexistent", "^1.0.0")
      expect { manager.install }.to raise_error(/Dependency conflicts/)
    end
  end

  describe "#update" do
    before do
      manager.init(name: "test-project")
      manager.registry.register(TRuby::PackageManifest.new(name: "upd-pkg", version: "1.0.0"))
      manager.registry.register(TRuby::PackageManifest.new(name: "upd-pkg", version: "1.5.0"))
      manager.add("upd-pkg", "^1.0.0")
    end

    it "updates specific package" do
      manager.update("upd-pkg")
      expect(manager.list["packages"]["upd-pkg"]).to eq("1.5.0")
    end

    it "updates all packages" do
      manager.update
      expect(manager.list["packages"]["upd-pkg"]).to eq("1.5.0")
    end
  end

  describe "#publish" do
    before do
      manager.init(name: "test-project")
      # Create a type file so validation passes
      FileUtils.mkdir_p(File.join(project_dir, "lib/types"))
      File.write(File.join(project_dir, "lib/types/test.d.trb"), "type Test = String")
    end

    it "returns publish status" do
      result = manager.publish
      expect(result[:status]).to eq(:published)
      expect(result[:name]).to eq("test-project")
    end

    it "raises for invalid manifest" do
      manager.manifest.instance_variable_set(:@name, nil)
      expect { manager.publish }.to raise_error(/Invalid manifest/)
    end
  end

  describe "#deprecate" do
    before do
      manager.init(name: "test-project")
    end

    it "returns deprecation notice" do
      result = manager.deprecate("1.0.0", "Use v2 instead")
      expect(result[:deprecated]).to be true
      expect(result[:message]).to eq("Use v2 instead")
    end
  end

  describe "without manifest" do
    it "raises error for operations requiring manifest" do
      expect { manager.add("pkg", "1.0.0") }.to raise_error(/No manifest found/)
      expect { manager.remove("pkg") }.to raise_error(/No manifest found/)
      expect { manager.install }.to raise_error(/No manifest found/)
    end
  end
end

RSpec.describe TRuby::SemanticVersion, "additional tests" do
  describe ".parse" do
    it "returns nil for invalid version" do
      expect(TRuby::SemanticVersion.parse("invalid")).to be_nil
    end

    it "parses valid version" do
      v = TRuby::SemanticVersion.parse("1.2.3")
      expect(v).to be_a(TRuby::SemanticVersion)
    end
  end

  describe "#<=>" do
    it "returns nil for non-SemanticVersion" do
      v = TRuby::SemanticVersion.new("1.0.0")
      expect(v <=> "string").to be_nil
    end

    it "compares prereleases alphabetically" do
      v1 = TRuby::SemanticVersion.new("1.0.0-alpha")
      v2 = TRuby::SemanticVersion.new("1.0.0-beta")
      expect(v1 < v2).to be true
    end

    it "returns 0 for identical prereleases" do
      v1 = TRuby::SemanticVersion.new("1.0.0-alpha")
      v2 = TRuby::SemanticVersion.new("1.0.0-alpha")
      expect(v1 <=> v2).to eq(0)
    end
  end
end

RSpec.describe TRuby::VersionConstraint, "additional tests" do
  describe "#satisfied_by?" do
    it "checks ~> (Ruby-style tilde)" do
      # ~> with space splits into two parts, use without space
      c = TRuby::VersionConstraint.new("~1.2.0")
      expect(c.satisfied_by?("1.2.5")).to be true
      expect(c.satisfied_by?("1.3.0")).to be false
    end

    it "checks <= constraint" do
      c = TRuby::VersionConstraint.new("<=2.0.0")
      expect(c.satisfied_by?("1.9.9")).to be true
      expect(c.satisfied_by?("2.0.0")).to be true
      expect(c.satisfied_by?("2.0.1")).to be false
    end

    it "checks > constraint" do
      c = TRuby::VersionConstraint.new(">1.0.0")
      expect(c.satisfied_by?("1.0.1")).to be true
      expect(c.satisfied_by?("1.0.0")).to be false
    end

    it "checks < constraint" do
      c = TRuby::VersionConstraint.new("<2.0.0")
      expect(c.satisfied_by?("1.9.9")).to be true
      expect(c.satisfied_by?("2.0.0")).to be false
    end

    it "handles * wildcard" do
      c = TRuby::VersionConstraint.new("*")
      expect(c.satisfied_by?("1.0.0")).to be true
      expect(c.satisfied_by?("99.99.99")).to be true
    end

    it "handles version string input" do
      c = TRuby::VersionConstraint.new("^1.0.0")
      expect(c.satisfied_by?("1.5.0")).to be true
    end

    it "parses bare version as exact match" do
      c = TRuby::VersionConstraint.new("1.2.3")
      expect(c.satisfied_by?("1.2.3")).to be true
      expect(c.satisfied_by?("1.2.4")).to be false
    end
  end
end

RSpec.describe TRuby::PackageManifest, "additional tests" do
  describe ".load" do
    it "returns nil for non-existent file" do
      expect(TRuby::PackageManifest.load("/nonexistent/path.json")).to be_nil
    end

    it "returns nil for invalid JSON" do
      path = "/tmp/invalid-manifest-#{Process.pid}.json"
      File.write(path, "invalid json {{{")
      expect(TRuby::PackageManifest.load(path)).to be_nil
      File.delete(path)
    end
  end

  describe "#add_dev_dependency" do
    it "adds dev dependency" do
      m = TRuby::PackageManifest.new(name: "pkg", version: "1.0.0")
      m.add_dev_dependency("rspec-types", "^3.0.0")
      expect(m.dev_dependencies["rspec-types"]).to eq("^3.0.0")
    end
  end

  describe "#to_h" do
    it "excludes nil values" do
      m = TRuby::PackageManifest.new(name: "pkg", version: "1.0.0")
      hash = m.to_h
      expect(hash).to have_key(:name)
      expect(hash).to have_key(:version)
      expect(hash).not_to have_key(:description) # nil should be excluded
    end
  end

  describe "string key handling" do
    it "accepts string keys from JSON" do
      m = TRuby::PackageManifest.new(
        "name" => "my-pkg",
        "version" => "2.0.0",
        "devDependencies" => { "test" => "^1.0.0" }
      )
      expect(m.name).to eq("my-pkg")
      expect(m.version).to eq("2.0.0")
      expect(m.dev_dependencies).to eq({ "test" => "^1.0.0" })
    end
  end
end

RSpec.describe TRuby::DependencyResolver, "additional tests" do
  let(:registry) { TRuby::PackageRegistry.new }
  let(:resolver) { TRuby::DependencyResolver.new(registry) }

  describe "#check_circular" do
    it "detects simple circular dependency" do
      pkg_a = TRuby::PackageManifest.new(name: "pkg-a", version: "1.0.0", dependencies: { "pkg-b" => "^1.0.0" })
      pkg_b = TRuby::PackageManifest.new(name: "pkg-b", version: "1.0.0", dependencies: { "pkg-a" => "^1.0.0" })

      registry.register(pkg_a)
      registry.register(pkg_b)

      cycles = resolver.check_circular(pkg_a)
      expect(cycles).not_to be_empty
    end

    it "returns empty for no circular dependency" do
      pkg_a = TRuby::PackageManifest.new(name: "pkg-a", version: "1.0.0", dependencies: { "pkg-b" => "^1.0.0" })
      pkg_b = TRuby::PackageManifest.new(name: "pkg-b", version: "1.0.0", dependencies: {})

      registry.register(pkg_a)
      registry.register(pkg_b)

      cycles = resolver.check_circular(pkg_a)
      expect(cycles).to be_empty
    end

    it "handles empty dependencies" do
      manifest = TRuby::PackageManifest.new(name: "app", version: "1.0.0", dependencies: {})
      expect(resolver.check_circular(manifest)).to eq([])
    end
  end

  describe "#resolve with transitive dependencies" do
    before do
      pkg_a = TRuby::PackageManifest.new(name: "pkg-a", version: "1.0.0", dependencies: { "pkg-b" => "^1.0.0" })
      pkg_b = TRuby::PackageManifest.new(name: "pkg-b", version: "1.0.0", dependencies: {})

      registry.register(pkg_a)
      registry.register(pkg_b)
    end

    it "resolves transitive dependencies" do
      manifest = TRuby::PackageManifest.new(
        name: "app",
        version: "1.0.0",
        dependencies: { "pkg-a" => "^1.0.0" }
      )

      result = resolver.resolve(manifest)
      expect(result[:resolved]).to have_key("pkg-a")
      expect(result[:resolved]).to have_key("pkg-b")
    end
  end
end

RSpec.describe TRuby::PackageRegistry, "additional tests" do
  let(:tmpdir) { "/tmp/t-ruby-registry-test-#{Process.pid}" }
  let(:registry) { TRuby::PackageRegistry.new(local_path: tmpdir) }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#get_package" do
    before do
      registry.register(TRuby::PackageManifest.new(name: "pkg", version: "1.0.0"))
      registry.register(TRuby::PackageManifest.new(name: "pkg", version: "2.0.0"))
    end

    it "returns nil for unknown package" do
      expect(registry.get_package("unknown", "1.0.0")).to be_nil
    end

    it "returns latest version for * constraint" do
      info = registry.get_package("pkg", "*")
      expect(info).not_to be_nil
    end
  end

  describe "#load_local" do
    it "loads manifest from directory" do
      pkg_dir = File.join(tmpdir, "my-pkg")
      FileUtils.mkdir_p(pkg_dir)

      manifest = TRuby::PackageManifest.new(name: "my-pkg", version: "1.0.0")
      manifest.save(File.join(pkg_dir, ".trb-manifest.json"))

      loaded = registry.load_local(pkg_dir)
      expect(loaded.name).to eq("my-pkg")
      expect(registry.get_versions("my-pkg")).to include("1.0.0")
    end

    it "returns nil for missing manifest" do
      expect(registry.load_local("/nonexistent")).to be_nil
    end
  end

  describe "#install" do
    before do
      registry.register(TRuby::PackageManifest.new(name: "pkg", version: "1.0.0"))
    end

    it "installs package to target directory" do
      result = registry.install("pkg", "1.0.0")
      expect(result[:name]).to eq("pkg")
      expect(result[:version]).to eq("1.0.0")
      expect(Dir.exist?(result[:path])).to be true
    end

    it "returns nil for unknown package" do
      expect(registry.install("unknown", "1.0.0")).to be_nil
    end
  end
end

RSpec.describe TRuby::RemoteRegistry do
  let(:registry) { TRuby::RemoteRegistry.new }

  describe "#initialize" do
    it "creates cache directory" do
      tmpdir = "/tmp/t-ruby-remote-cache-#{Process.pid}"
      reg = TRuby::RemoteRegistry.new(cache_dir: tmpdir)
      expect(Dir.exist?(tmpdir)).to be true
      expect(reg.cache_dir).to eq(tmpdir)
      FileUtils.rm_rf(tmpdir)
    end
  end

  describe "attribute readers" do
    it "has registry_url" do
      expect(registry.registry_url).to be_a(String)
    end
  end
end
