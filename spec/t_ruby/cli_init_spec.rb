# frozen_string_literal: true

require "spec_helper"
require "fileutils"

describe TRuby::CLI do
  describe "--init option" do
    let(:tmpdir) { Dir.mktmpdir("trb_cli_init") }

    after do
      FileUtils.rm_rf(tmpdir)
    end

    it "creates trbconfig.yml file with new schema" do
      Dir.chdir(tmpdir) do
        expect { TRuby::CLI.run(["--init"]) }.to output(/Created:.*trbconfig\.yml/).to_stdout

        expect(File.exist?("trbconfig.yml")).to be true

        config = YAML.safe_load_file("trbconfig.yml")

        # New schema structure
        expect(config["source"]).to be_a(Hash)
        expect(config["source"]["include"]).to eq(["src"])
        expect(config["source"]["exclude"]).to eq([])
        expect(config["source"]["extensions"]).to eq([".trb", ".rb"])

        expect(config["output"]).to be_a(Hash)
        expect(config["output"]["ruby_dir"]).to eq("build")

        expect(config["compiler"]).to be_a(Hash)
        expect(config["compiler"]["generate_rbs"]).to eq(true)
        expect(config["compiler"]["strictness"]).to eq("standard")
        expected_ruby = "#{RUBY_VERSION.split(".")[0]}.#{RUBY_VERSION.split(".")[1]}"
        expect(config["compiler"]["target_ruby"]).to eq(expected_ruby)

        expect(config["watch"]).to be_a(Hash)
        expect(config["watch"]["debounce"]).to eq(100)
      end
    end

    it "creates src/ directory" do
      Dir.chdir(tmpdir) do
        expect { TRuby::CLI.run(["--init"]) }.to output(%r{Created:.*src/}).to_stdout

        expect(Dir.exist?("src")).to be true
      end
    end

    it "creates build/ directory" do
      Dir.chdir(tmpdir) do
        expect { TRuby::CLI.run(["--init"]) }.to output(%r{Created:.*build/}).to_stdout

        expect(Dir.exist?("build")).to be true
      end
    end

    it "does not overwrite existing trbconfig.yml" do
      Dir.chdir(tmpdir) do
        File.write("trbconfig.yml", "custom: config\n")

        expect { TRuby::CLI.run(["--init"]) }.to output(/Skipped.*trbconfig\.yml/).to_stdout

        content = File.read("trbconfig.yml")
        expect(content).to eq("custom: config\n")
      end
    end

    it "does not fail if directories already exist" do
      Dir.chdir(tmpdir) do
        Dir.mkdir("src")
        Dir.mkdir("build")

        expect { TRuby::CLI.run(["--init"]) }.to output(%r{Skipped.*src/}).to_stdout
        expect { TRuby::CLI.run(["--init"]) }.to output(%r{Skipped.*build/}).to_stdout
      end
    end

    it "reports project already initialized when everything exists" do
      Dir.chdir(tmpdir) do
        File.write("trbconfig.yml", "emit:\n  rb: true\n")
        Dir.mkdir("src")
        Dir.mkdir("build")

        expect { TRuby::CLI.run(["--init"]) }.to output(/Project already initialized/).to_stdout
      end
    end

    it "shows success message when project is initialized" do
      Dir.chdir(tmpdir) do
        expect { TRuby::CLI.run(["--init"]) }.to output(/t-ruby project initialized successfully/).to_stdout
      end
    end
  end

  describe "--config option" do
    let(:tmpdir) { Dir.mktmpdir("trb_cli_config") }

    after do
      FileUtils.rm_rf(tmpdir)
    end

    it "accepts --config flag with a custom config path" do
      Dir.chdir(tmpdir) do
        # Create custom config file
        FileUtils.mkdir_p("configs")
        File.write("configs/custom.yml", <<~YAML)
          source:
            include:
              - lib
          output:
            ruby_dir: out
        YAML

        # Create source directory and file
        FileUtils.mkdir_p("lib")
        File.write("lib/test.trb", "puts 'hello'")

        # Compile with custom config
        expect do
          TRuby::CLI.run(["--config", "configs/custom.yml", "lib/test.trb"])
        rescue SystemExit => e
          raise "CLI exited with status #{e.status}" if e.status != 0
        end.to output(/Compiled:/).to_stdout

        # Should output to 'out' directory from custom config
        expect(File.exist?("out/test.rb")).to be true
      end
    end

    it "accepts -c shorthand for --config" do
      Dir.chdir(tmpdir) do
        # Create custom config file
        FileUtils.mkdir_p("configs")
        File.write("configs/custom.yml", <<~YAML)
          source:
            include:
              - lib
          output:
            ruby_dir: dist
        YAML

        # Create source directory and file
        FileUtils.mkdir_p("lib")
        File.write("lib/test.trb", "puts 'hello'")

        # Compile with custom config using shorthand
        expect do
          TRuby::CLI.run(["-c", "configs/custom.yml", "lib/test.trb"])
        rescue SystemExit => e
          raise "CLI exited with status #{e.status}" if e.status != 0
        end.to output(/Compiled:/).to_stdout

        # Should output to 'dist' directory from custom config
        expect(File.exist?("dist/test.rb")).to be true
      end
    end
  end
end
