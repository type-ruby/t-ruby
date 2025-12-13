# frozen_string_literal: true

require "spec_helper"
require "fileutils"

describe TRuby::CLI do
  describe "--init option" do
    let(:tmpdir) { Dir.mktmpdir("trb_cli_init") }

    after do
      FileUtils.rm_rf(tmpdir)
    end

    it "creates trbconfig.yml file" do
      Dir.chdir(tmpdir) do
        expect { TRuby::CLI.run(["--init"]) }.to output(/Created:.*trbconfig\.yml/).to_stdout

        expect(File.exist?("trbconfig.yml")).to be true

        config = YAML.safe_load_file("trbconfig.yml")
        expect(config["emit"]["rb"]).to eq(true)
        expect(config["emit"]["rbs"]).to eq(false)
        expect(config["paths"]["src"]).to eq("./src")
        expect(config["paths"]["out"]).to eq("./build")
      end
    end

    it "creates src/ directory" do
      Dir.chdir(tmpdir) do
        expect { TRuby::CLI.run(["--init"]) }.to output(/Created:.*src\//).to_stdout

        expect(Dir.exist?("src")).to be true
      end
    end

    it "creates build/ directory" do
      Dir.chdir(tmpdir) do
        expect { TRuby::CLI.run(["--init"]) }.to output(/Created:.*build\//).to_stdout

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

        expect { TRuby::CLI.run(["--init"]) }.to output(/Skipped.*src\//).to_stdout
        expect { TRuby::CLI.run(["--init"]) }.to output(/Skipped.*build\//).to_stdout
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
end
