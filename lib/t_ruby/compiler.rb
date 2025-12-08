# frozen_string_literal: true

require "fileutils"

module TRuby
  class Compiler
    def initialize(config)
      @config = config
    end

    def compile(input_path)
      unless File.exist?(input_path)
        raise ArgumentError, "File not found: #{input_path}"
      end

      unless input_path.end_with?(".trb")
        raise ArgumentError, "Expected .trb file, got: #{input_path}"
      end

      source = File.read(input_path)
      output = transform(source)

      out_dir = @config.out_dir
      FileUtils.mkdir_p(out_dir)

      output_filename = File.basename(input_path, ".trb") + ".rb"
      output_path = File.join(out_dir, output_filename)

      File.write(output_path, output)
      output_path
    end

    private

    def transform(source)
      # Milestone 1: Parse and erase type annotations
      parser = Parser.new(source)
      parse_result = parser.parse

      if parse_result[:type] == :success
        eraser = TypeErasure.new(source)
        eraser.erase
      else
        source
      end
    end
  end
end
