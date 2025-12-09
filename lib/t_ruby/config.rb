# frozen_string_literal: true

require "yaml"

module TRuby
  class Config
    DEFAULT_CONFIG = {
      "emit" => {
        "rb" => true,
        "rbs" => false,
        "dtrb" => false,
        "wasm" => false
      },
      "paths" => {
        "src" => "./src",
        "out" => "./build"
      },
      "strict" => {
        "rbs_compat" => true,
        "null_safety" => false,
        "inference" => "basic"
      }
    }.freeze

    attr_reader :emit, :paths, :strict

    def initialize(config_path = nil)
      config = load_config(config_path)
      @emit = config["emit"]
      @paths = config["paths"]
      @strict = config["strict"]
    end

    def out_dir
      @paths["out"]
    end

    def src_dir
      @paths["src"]
    end

    private

    def load_config(config_path)
      if config_path && File.exist?(config_path)
        YAML.safe_load_file(config_path, permitted_classes: [Symbol])
      elsif File.exist?(".trb.yml")
        YAML.safe_load_file(".trb.yml", permitted_classes: [Symbol])
      else
        DEFAULT_CONFIG.dup
      end
    end
  end
end
