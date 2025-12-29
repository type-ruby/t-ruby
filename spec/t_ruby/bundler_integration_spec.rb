# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"

RSpec.describe TRuby::BundlerIntegration do
  let(:temp_dir) { Dir.mktmpdir }
  let(:integration) { described_class.new(project_dir: temp_dir) }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#bundler_project?" do
    it "returns false when no Gemfile exists" do
      expect(integration.bundler_project?).to be false
    end

    it "returns true when Gemfile exists" do
      File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
      expect(integration.bundler_project?).to be true
    end
  end

  describe "#init" do
    context "without Gemfile" do
      it "returns false and adds error" do
        expect(integration.init).to be false
        expect(integration.errors).to include("No Gemfile found. Run 'bundle init' first.")
      end
    end

    context "with Gemfile" do
      before do
        File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'\n")
      end

      it "returns true" do
        expect(integration.init).to be true
      end

      it "adds types group to Gemfile" do
        integration.init
        content = File.read(File.join(temp_dir, "Gemfile"))
        expect(content).to include("group :types do")
      end

      it "creates types directory" do
        integration.init
        expect(Dir.exist?(File.join(temp_dir, "types"))).to be true
      end

      it "creates sample type definition file" do
        integration.init
        expect(File.exist?(File.join(temp_dir, "types", "custom.d.trb"))).to be true
      end

      it "does not duplicate types group if already exists" do
        File.write(File.join(temp_dir, "Gemfile"), <<~RUBY)
          source 'https://rubygems.org'
          group :types do
          end
        RUBY

        integration.init
        content = File.read(File.join(temp_dir, "Gemfile"))
        expect(content.scan("group :types").count).to eq(1)
      end
    end
  end

  describe "#add_type_gem" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), <<~RUBY)
        source 'https://rubygems.org'
        group :types do
        end
      RUBY
    end

    it "adds type gem to Gemfile" do
      result = integration.add_type_gem("rails", version: "~> 7.0")

      expect(result[:gem]).to eq("rails-types")
      expect(result[:status]).to eq(:added)

      content = File.read(File.join(temp_dir, "Gemfile"))
      expect(content).to include("gem 'rails-types'")
    end

    it "uses default version when not specified" do
      result = integration.add_type_gem("sidekiq")
      expect(result[:version]).to eq(">= 0")
    end
  end

  describe "#remove_type_gem" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), <<~RUBY)
        source 'https://rubygems.org'
        group :types do
          gem 'rails-types', '~> 7.0'
        end
      RUBY
    end

    it "removes type gem from Gemfile" do
      result = integration.remove_type_gem("rails")

      expect(result[:status]).to eq(:removed)

      content = File.read(File.join(temp_dir, "Gemfile"))
      expect(content).not_to include("rails-types")
    end
  end

  describe "#generate_bundle_manifest" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
    end

    it "creates .trb-bundle.json file" do
      path = integration.generate_bundle_manifest

      expect(File.exist?(path)).to be true
      expect(path).to end_with(".trb-bundle.json")
    end

    it "includes correct manifest structure" do
      integration.generate_bundle_manifest
      content = JSON.parse(File.read(File.join(temp_dir, ".trb-bundle.json")))

      expect(content["bundler_integration"]).to be true
      expect(content["types_group"]).to eq("types")
      expect(content).to have_key("type_gems")
      expect(content).to have_key("local_types")
    end
  end

  describe "#discover_type_packages" do
    it "returns empty hash when no Gemfile" do
      expect(integration.discover_type_packages).to eq({})
    end

    context "with Gemfile.lock" do
      before do
        File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
        File.write(File.join(temp_dir, "Gemfile.lock"), <<~LOCK)
          GEM
            remote: https://rubygems.org/
            specs:
              rails (7.0.0)
              sidekiq (6.5.0)

          PLATFORMS
            ruby

          DEPENDENCIES
            rails
            sidekiq
        LOCK
      end

      it "finds type packages for installed gems" do
        packages = integration.discover_type_packages

        expect(packages).to have_key("rails")
        expect(packages["rails"][:name]).to eq("rails-types")
      end
    end
  end

  describe "#check_version_compatibility" do
    it "returns empty array when no type gems" do
      expect(integration.check_version_compatibility).to eq([])
    end
  end

  describe "#create_type_gem_scaffold" do
    it "creates type gem directory structure" do
      result = integration.create_type_gem_scaffold("mylib")

      expect(result[:status]).to eq(:created)
      expect(Dir.exist?(result[:path])).to be true
    end

    it "creates gemspec file" do
      result = integration.create_type_gem_scaffold("mylib")
      gemspec = File.join(result[:path], "mylib-types.gemspec")

      expect(File.exist?(gemspec)).to be true
      content = File.read(gemspec)
      expect(content).to include('spec.name          = "mylib-types"')
    end

    it "creates README file" do
      result = integration.create_type_gem_scaffold("mylib")
      readme = File.join(result[:path], "README.md")

      expect(File.exist?(readme)).to be true
      content = File.read(readme)
      expect(content).to include("# mylib-types")
    end

    it "creates sig directory with type definition" do
      result = integration.create_type_gem_scaffold("mylib")
      type_file = File.join(result[:path], "sig", "mylib.d.trb")

      expect(File.exist?(type_file)).to be true
    end
  end

  describe "#load_bundled_types" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
      FileUtils.mkdir_p(File.join(temp_dir, "types"))
      File.write(File.join(temp_dir, "types", "local.d.trb"), <<~TRB)
        type UserId = String
        interface Serializable
          to_json: String
        end
      TRB
    end

    it "loads local type definitions" do
      types = integration.load_bundled_types

      expect(types).to have_key("UserId")
      expect(types["UserId"][:kind]).to eq(:alias)
      expect(types).to have_key("Serializable")
      expect(types["Serializable"][:kind]).to eq(:interface)
    end
  end

  describe "#sync_types" do
    it "returns empty synced array when not a bundler project" do
      result = integration.sync_types
      expect(result[:synced]).to eq([])
    end

    context "with bundler project" do
      before do
        File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
        File.write(File.join(temp_dir, "Gemfile.lock"), <<~LOCK)
          GEM
            specs:

          PLATFORMS
            ruby

          DEPENDENCIES
        LOCK
      end

      it "returns result structure" do
        result = integration.sync_types
        expect(result).to have_key(:synced)
        expect(result).to have_key(:errors)
      end
    end
  end
end

RSpec.describe TRuby::BundlerIntegration, "additional tests" do
  let(:temp_dir) { Dir.mktmpdir }
  let(:integration) { described_class.new(project_dir: temp_dir) }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#add_type_gem without existing types group" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), <<~RUBY)
        source 'https://rubygems.org'
        gem 'rails'
      RUBY
    end

    it "creates types group and adds gem" do
      integration.add_type_gem("rails", version: "~> 7.0")

      content = File.read(File.join(temp_dir, "Gemfile"))
      expect(content).to include("group :types do")
      expect(content).to include("gem 'rails-types'")
    end
  end

  describe "#check_version_compatibility with mismatch" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
      File.write(File.join(temp_dir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            rails (7.0.0)
            rails-types (6.0.0)

        PLATFORMS
          ruby
      LOCK
    end

    it "reports version mismatch" do
      integration.instance_variable_set(:@type_gems, {
                                          "rails" => { name: "rails-types", version: "~> 6.0" },
                                        })

      issues = integration.check_version_compatibility
      expect(issues).not_to be_empty
      expect(issues.first[:message]).to include("Version mismatch")
    end
  end

  describe "#check_version_compatibility with compatible versions" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
      File.write(File.join(temp_dir, "Gemfile.lock"), <<~LOCK)
        GEM
          specs:
            rails (7.0.5)
            rails-types (7.0.0)

        PLATFORMS
          ruby
      LOCK
    end

    it "returns empty when versions match" do
      integration.instance_variable_set(:@type_gems, {
                                          "rails" => { name: "rails-types", version: "~> 7.0" },
                                        })

      issues = integration.check_version_compatibility
      expect(issues).to be_empty
    end
  end

  describe "#create_type_gem_scaffold with custom output" do
    it "creates scaffold in specified directory" do
      output = File.join(temp_dir, "custom", "path")
      result = integration.create_type_gem_scaffold("mylib", output_dir: output)

      expect(result[:path]).to eq(output)
      expect(Dir.exist?(output)).to be true
    end

    it "creates lib subdirectory structure" do
      result = integration.create_type_gem_scaffold("my-gem")

      lib_dir = File.join(result[:path], "lib", "my_gem_types")
      expect(Dir.exist?(lib_dir)).to be true
    end

    it "creates version.rb file" do
      result = integration.create_type_gem_scaffold("mylib")

      version_file = File.join(result[:path], "lib", "mylib_types", "version.rb")
      expect(File.exist?(version_file)).to be true
      content = File.read(version_file)
      expect(content).to include("MylibTypes")
      expect(content).to include('VERSION = "0.1.0"')
    end
  end

  describe "#load_bundled_types with no types directory" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
      File.write(File.join(temp_dir, "Gemfile.lock"), "GEM\n  specs:\n")
    end

    it "returns empty definitions" do
      types = integration.load_bundled_types
      expect(types).to eq({})
    end
  end

  describe "attribute readers" do
    it "has project_dir" do
      expect(integration.project_dir).to eq(temp_dir)
    end

    it "has errors" do
      expect(integration.errors).to be_an(Array)
    end
  end

  describe "#sync_types" do
    context "with type gems having path" do
      before do
        File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
        File.write(File.join(temp_dir, "Gemfile.lock"), <<~LOCK)
          GEM
            remote: https://rubygems.org/
            specs:
              rails-types (7.0.0)

          PLATFORMS
            ruby

          DEPENDENCIES
            rails-types
        LOCK

        # Create a fake gem directory with type files
        gem_path = File.join(temp_dir, "vendor", "bundle", "ruby", "3.0.0", "gems", "rails-types-7.0.0")
        FileUtils.mkdir_p(File.join(gem_path, "sig"))
        File.write(File.join(gem_path, "sig", "rails.rbs"), "class Rails; end")
      end

      it "syncs type files from gems" do
        result = integration.sync_types
        expect(result).to have_key(:synced)
        expect(result).to have_key(:errors)
      end
    end
  end

  describe "#load_bundled_types with gem types" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
      File.write(File.join(temp_dir, "Gemfile.lock"), <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            mylib-types (1.0.0)

        PLATFORMS
          ruby
      LOCK

      # Create fake gem with type definitions
      gem_path = File.join(temp_dir, "vendor", "bundle", "ruby", "3.0.0", "gems", "mylib-types-1.0.0")
      FileUtils.mkdir_p(gem_path)
      File.write(File.join(gem_path, "types.d.trb"), <<~TRB)
        type MyLibId = String
        interface MyLibClient
          connect: Boolean
        end
      TRB
    end

    it "loads types from gems and local" do
      types = integration.load_bundled_types
      expect(types).to be_a(Hash)
    end
  end

  describe "private #parse_gemfile_lock" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
      File.write(File.join(temp_dir, "Gemfile.lock"), <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            gem1 (1.2.3)
            gem2 (4.5.6)
              dep1 (~> 1.0)

        PLATFORMS
          arm64-darwin-24
          ruby

        DEPENDENCIES
          gem1
          gem2
      LOCK
    end

    it "parses gems from Gemfile.lock" do
      gems = integration.send(:parse_gemfile_lock)
      expect(gems["gem1"]).to eq("1.2.3")
      expect(gems["gem2"]).to eq("4.5.6")
    end
  end

  describe "private #find_type_gem" do
    it "returns available: true for common type gems" do
      result = integration.send(:find_type_gem, "rails")
      expect(result[:name]).to eq("rails-types")
      expect(result[:available]).to be true
    end

    it "returns available: false for unknown gems" do
      result = integration.send(:find_type_gem, "unknown-gem")
      expect(result[:name]).to eq("unknown-gem-types")
      expect(result[:available]).to be false
    end
  end

  describe "private #versions_compatible?" do
    it "returns true when major.minor match" do
      expect(integration.send(:versions_compatible?, "7.0.5", "7.0.0")).to be true
    end

    it "returns false when major.minor differ" do
      expect(integration.send(:versions_compatible?, "7.1.0", "7.0.0")).to be false
    end
  end

  describe "private #create_types_directory with existing file" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
      types_dir = File.join(temp_dir, "types")
      FileUtils.mkdir_p(types_dir)
      File.write(File.join(types_dir, "custom.d.trb"), "# existing content")
    end

    it "does not overwrite existing sample file" do
      integration.init
      content = File.read(File.join(temp_dir, "types", "custom.d.trb"))
      expect(content).to eq("# existing content")
    end
  end

  describe "private #list_local_types" do
    before do
      File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
      types_dir = File.join(temp_dir, "types")
      FileUtils.mkdir_p(types_dir)
      File.write(File.join(types_dir, "one.d.trb"), "type A = String")
      File.write(File.join(types_dir, "two.d.trb"), "type B = Integer")
    end

    it "lists local type files" do
      files = integration.send(:list_local_types)
      expect(files).to include("one.d.trb")
      expect(files).to include("two.d.trb")
    end
  end

  describe "private #list_local_types with no types directory" do
    it "returns empty array" do
      files = integration.send(:list_local_types)
      expect(files).to eq([])
    end
  end
end

RSpec.describe TRuby::PackageManager do
  let(:temp_dir) { Dir.mktmpdir }
  let(:manager) { described_class.new(project_dir: temp_dir) }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#bundler" do
    it "provides access to BundlerIntegration" do
      expect(manager.bundler).to be_a(TRuby::BundlerIntegration)
    end
  end

  describe "#install_with_bundler_fallback" do
    context "without Bundler" do
      it "raises error when no manifest exists" do
        # Without Bundler and without manifest, should raise error
        expect { manager.install_with_bundler_fallback }.to raise_error(/No manifest found/)
      end
    end

    context "with Bundler" do
      before do
        File.write(File.join(temp_dir, "Gemfile"), "source 'https://rubygems.org'")
        File.write(File.join(temp_dir, "Gemfile.lock"), "")
      end

      it "uses bundler sync" do
        result = manager.install_with_bundler_fallback
        expect(result).to have_key(:synced)
      end
    end
  end

  describe "#migrate_to_bundler" do
    context "without Bundler project" do
      it "returns error" do
        result = manager.migrate_to_bundler
        expect(result[:success]).to be false
        expect(result[:error]).to include("Not a Bundler project")
      end
    end

    context "with Bundler project" do
      before do
        File.write(File.join(temp_dir, "Gemfile"), <<~RUBY)
          source 'https://rubygems.org'
          group :types do
          end
        RUBY
      end

      it "returns success" do
        result = manager.migrate_to_bundler
        expect(result[:success]).to be true
      end

      it "generates bundle manifest" do
        manager.migrate_to_bundler
        expect(File.exist?(File.join(temp_dir, ".trb-bundle.json"))).to be true
      end
    end
  end
end
