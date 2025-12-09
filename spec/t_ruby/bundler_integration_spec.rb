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
