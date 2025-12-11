# frozen_string_literal: true

require "fileutils"

module TRuby
  class Compiler
    attr_reader :declaration_loader, :use_ir, :optimizer

    def initialize(config = nil, use_ir: true, optimize: true)
      @config = config || Config.new
      @use_ir = use_ir
      @optimize = optimize
      @declaration_loader = DeclarationLoader.new
      @optimizer = IR::Optimizer.new if use_ir && optimize
      setup_declaration_paths if @config
    end

    def compile(input_path)
      unless File.exist?(input_path)
        raise ArgumentError, "File not found: #{input_path}"
      end

      unless input_path.end_with?(".trb")
        raise ArgumentError, "Expected .trb file, got: #{input_path}"
      end

      source = File.read(input_path)

      # Parse with IR support
      parser = Parser.new(source, use_combinator: @use_ir)
      parse_result = parser.parse

      # Transform source to Ruby code
      output = @use_ir ? transform_with_ir(source, parser) : transform_legacy(source, parse_result)

      out_dir = @config.out_dir
      FileUtils.mkdir_p(out_dir)

      base_filename = File.basename(input_path, ".trb")
      output_path = File.join(out_dir, base_filename + ".rb")

      File.write(output_path, output)

      # Generate .rbs file if enabled in config
      if @config.emit["rbs"]
        if @use_ir && parser.ir_program
          generate_rbs_from_ir(base_filename, out_dir, parser.ir_program)
        else
          generate_rbs_file(base_filename, out_dir, parse_result)
        end
      end

      # Generate .d.trb file if enabled in config
      if @config.emit["dtrb"]
        generate_dtrb_file(input_path, out_dir)
      end

      output_path
    end

    # Compile T-Ruby source code from a string (useful for WASM/playground)
    # @param source [String] T-Ruby source code
    # @param options [Hash] Options for compilation
    # @option options [Boolean] :rbs Whether to generate RBS output (default: true)
    # @return [Hash] Result with :ruby, :rbs, :errors keys
    def compile_string(source, options = {})
      generate_rbs = options.fetch(:rbs, true)

      parser = Parser.new(source, use_combinator: @use_ir)
      parse_result = parser.parse

      # Transform source to Ruby code
      ruby_output = @use_ir ? transform_with_ir(source, parser) : transform_legacy(source, parse_result)

      # Generate RBS if requested
      rbs_output = ""
      if generate_rbs
        if @use_ir && parser.ir_program
          generator = IR::RBSGenerator.new
          rbs_output = generator.generate(parser.ir_program)
        else
          generator = RBSGenerator.new
          rbs_output = generator.generate(
            parse_result[:functions] || [],
            parse_result[:type_aliases] || []
          )
        end
      end

      {
        ruby: ruby_output,
        rbs: rbs_output,
        errors: []
      }
    rescue ParseError => e
      {
        ruby: "",
        rbs: "",
        errors: [e.message]
      }
    rescue StandardError => e
      {
        ruby: "",
        rbs: "",
        errors: ["Compilation error: #{e.message}"]
      }
    end

    # Compile to IR without generating output files
    def compile_to_ir(input_path)
      unless File.exist?(input_path)
        raise ArgumentError, "File not found: #{input_path}"
      end

      source = File.read(input_path)
      parser = Parser.new(source, use_combinator: true)
      parser.parse
      parser.ir_program
    end

    # Compile from IR program directly
    def compile_from_ir(ir_program, output_path)
      out_dir = File.dirname(output_path)
      FileUtils.mkdir_p(out_dir)

      # Optimize if enabled
      program = ir_program
      if @optimize && @optimizer
        result = @optimizer.optimize(program)
        program = result[:program]
      end

      # Generate Ruby code
      generator = IRCodeGenerator.new
      output = generator.generate(program)
      File.write(output_path, output)

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

    # Get optimization statistics (only available after IR compilation)
    def optimization_stats
      @optimizer&.stats
    end

    private

    def setup_declaration_paths
      # Add default declaration paths
      @declaration_loader.add_search_path(@config.out_dir)
      @declaration_loader.add_search_path(@config.src_dir)
      @declaration_loader.add_search_path("./types")
      @declaration_loader.add_search_path("./lib/types")
    end

    # Transform using IR system (new approach)
    def transform_with_ir(source, parser)
      ir_program = parser.ir_program
      return transform_legacy(source, parser.parse) unless ir_program

      # Run optimization passes if enabled
      if @optimize && @optimizer
        result = @optimizer.optimize(ir_program)
        ir_program = result[:program]
      end

      # Generate Ruby code using IR-aware generator
      generator = IRCodeGenerator.new
      generator.generate_with_source(ir_program, source)
    end

    # Legacy transformation using TypeErasure (backward compatible)
    def transform_legacy(source, parse_result)
      if parse_result[:type] == :success
        eraser = TypeErasure.new(source)
        eraser.erase
      else
        source
      end
    end

    # Generate RBS from IR
    def generate_rbs_from_ir(base_filename, out_dir, ir_program)
      generator = IR::RBSGenerator.new
      rbs_content = generator.generate(ir_program)

      rbs_path = File.join(out_dir, base_filename + ".rbs")
      File.write(rbs_path, rbs_content) unless rbs_content.strip.empty?
    end

    # Legacy RBS generation
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
  end

  # IR-aware code generator for source-preserving transformation
  class IRCodeGenerator
    def initialize
      @output = []
    end

    # Generate Ruby code from IR program
    def generate(program)
      generator = IR::CodeGenerator.new
      generator.generate(program)
    end

    # Generate Ruby code while preserving source structure
    def generate_with_source(program, source)
      result = source.dup

      # Collect type alias names to remove
      type_alias_names = program.declarations
        .select { |d| d.is_a?(IR::TypeAlias) }
        .map(&:name)

      # Collect interface names to remove
      interface_names = program.declarations
        .select { |d| d.is_a?(IR::Interface) }
        .map(&:name)

      # Remove type alias definitions
      result = result.gsub(/^\s*type\s+\w+\s*=\s*.+?$\n?/, '')

      # Remove interface definitions (multi-line)
      result = result.gsub(/^\s*interface\s+\w+.*?^\s*end\s*$/m, '')

      # Remove parameter type annotations using IR info
      # Enhanced: Handle complex types (generics, unions, etc.)
      result = erase_parameter_types(result)

      # Remove return type annotations
      result = erase_return_types(result)

      # Clean up extra blank lines
      result = result.gsub(/\n{3,}/, "\n\n")

      result
    end

    private

    # Erase parameter type annotations
    def erase_parameter_types(source)
      result = source.dup

      # Match function definitions and remove type annotations from parameters
      result.gsub!(/^(\s*def\s+\w+\s*\()([^)]+)(\)\s*)(?::\s*[^\n]+)?(\s*$)/) do |match|
        indent = $1
        params = $2
        close_paren = $3
        ending = $4

        # Remove type annotations from each parameter
        cleaned_params = remove_param_types(params)

        "#{indent}#{cleaned_params}#{close_paren.rstrip}#{ending}"
      end

      result
    end

    # Remove type annotations from parameter list
    def remove_param_types(params_str)
      return params_str if params_str.strip.empty?

      params = []
      current = ""
      depth = 0

      params_str.each_char do |char|
        case char
        when "<", "[", "("
          depth += 1
          current += char
        when ">", "]", ")"
          depth -= 1
          current += char
        when ","
          if depth == 0
            params << clean_param(current.strip)
            current = ""
          else
            current += char
          end
        else
          current += char
        end
      end

      params << clean_param(current.strip) unless current.empty?
      params.join(", ")
    end

    # Clean a single parameter (remove type annotation)
    def clean_param(param)
      # Match: name: Type or name
      if match = param.match(/^(\w+)\s*:/)
        match[1]
      else
        param
      end
    end

    # Erase return type annotations
    def erase_return_types(source)
      result = source.dup

      # Remove return type: ): Type or ): Type<Foo> etc.
      result.gsub!(/\)\s*:\s*[^\n]+?(?=\s*$)/m) do |match|
        ")"
      end

      result
    end
  end

  # Legacy Compiler for backward compatibility (no IR)
  class LegacyCompiler < Compiler
    def initialize(config)
      super(config, use_ir: false, optimize: false)
    end
  end
end
