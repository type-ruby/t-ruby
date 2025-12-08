# frozen_string_literal: true

require "fileutils"

module TRuby
  class Compiler
    attr_reader :declaration_loader

    def initialize(config)
      @config = config
      @declaration_loader = DeclarationLoader.new
      setup_declaration_paths
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

      # Generate .d.trb file if enabled in config
      if @config.emit["dtrb"]
        generate_dtrb_file(input_path, out_dir)
      end

      output_path
    end

    # Load external declarations from a file
    def load_declaration(name)
      @declaration_loader.load(name)
    end

    # Add a search path for declaration files
    def add_declaration_path(path)
      @declaration_loader.add_search_path(path)
    end

    private

    def setup_declaration_paths
      # Add default declaration paths
      @declaration_loader.add_search_path(@config.out_dir)
      @declaration_loader.add_search_path(@config.src_dir)
      @declaration_loader.add_search_path("./types")
      @declaration_loader.add_search_path("./lib/types")
    end

    def generate_rbs_file(base_filename, out_dir, parse_result)
      generator = RBSGenerator.new
      rbs_content = generator.generate(
        parse_result[:functions] || [],
        parse_result[:type_aliases] || []
      )

      rbs_path = File.join(out_dir, base_filename + ".rbs")
      File.write(rbs_path, rbs_content) unless rbs_content.empty?
    end

    def generate_dtrb_file(input_path, out_dir)
      generator = DeclarationGenerator.new
      generator.generate_file(input_path, out_dir)
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
