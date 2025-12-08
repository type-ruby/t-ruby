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
      parser = Parser.new(source)
      parse_result = parser.parse
      output = transform(source)

      out_dir = @config.out_dir
      FileUtils.mkdir_p(out_dir)

      base_filename = File.basename(input_path, ".trb")
      output_path = File.join(out_dir, base_filename + ".rb")

      File.write(output_path, output)

      # Generate .rbs file if enabled in config
      if @config.emit["rbs"]
        generate_rbs_file(base_filename, out_dir, parse_result)
      end

      output_path
    end

    private

    def generate_rbs_file(base_filename, out_dir, parse_result)
      generator = RBSGenerator.new
      rbs_content = generator.generate(
        parse_result[:functions] || [],
        parse_result[:type_aliases] || []
      )

      rbs_path = File.join(out_dir, base_filename + ".rbs")
      File.write(rbs_path, rbs_content) unless rbs_content.empty?
    end

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
