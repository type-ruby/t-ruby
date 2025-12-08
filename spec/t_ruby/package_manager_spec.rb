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
      dependencies: { "other-pkg" => "^1.0.0" }
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
  end
end
