# frozen_string_literal: true

require "fileutils"

module TRuby
  # Pattern for method names that supports Unicode characters
  # \p{L} matches any Unicode letter, \p{N} matches any Unicode number
  IDENTIFIER_CHAR = '[\p{L}\p{N}_]'
  METHOD_NAME_PATTERN = "#{IDENTIFIER_CHAR}+[?!]?".freeze
  # Visibility modifiers for method definitions
  VISIBILITY_PATTERN = '(?:(?:private|protected|public)\s+)?'

  class Compiler
    attr_reader :declaration_loader, :optimizer

    def initialize(config = nil, optimize: true)
      @config = config || Config.new
      @optimize = optimize
      @declaration_loader = DeclarationLoader.new
      @optimizer = IR::Optimizer.new if optimize
      @type_inferrer = ASTTypeInferrer.new if type_check?
      setup_declaration_paths if @config
    end

    def type_check?
      @config.type_check?
    end

    def compile(input_path)
      unless File.exist?(input_path)
        raise ArgumentError, "File not found: #{input_path}"
      end

      # Handle .rb files separately
      if input_path.end_with?(".rb")
        return copy_ruby_file(input_path)
      end

      unless input_path.end_with?(".trb")
        raise ArgumentError, "Expected .trb or .rb file, got: #{input_path}"
      end

      source = File.read(input_path)

      # Parse with IR support
      parser = Parser.new(source)
      parser.parse

      # Run type checking if enabled
      if type_check? && parser.ir_program
        check_types(parser.ir_program, input_path)
      end

      # Transform source to Ruby code
      output = transform_with_ir(source, parser)

      # Compute output path (respects preserve_structure setting)
      output_path = compute_output_path(input_path, @config.ruby_dir, ".rb")
      FileUtils.mkdir_p(File.dirname(output_path))

      File.write(output_path, output)

      # Generate .rbs file if enabled in config
      if @config.compiler["generate_rbs"]
        rbs_path = compute_output_path(input_path, @config.rbs_dir, ".rbs")
        FileUtils.mkdir_p(File.dirname(rbs_path))
        generate_rbs_from_ir_to_path(rbs_path, parser.ir_program)
      end

      # Generate .d.trb file if enabled in config (legacy support)
      # TODO: Add compiler.generate_dtrb option in future
      if @config.compiler.key?("generate_dtrb") && @config.compiler["generate_dtrb"]
        generate_dtrb_file(input_path, @config.ruby_dir)
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

      parser = Parser.new(source)
      parser.parse

      # Transform source to Ruby code
      ruby_output = transform_with_ir(source, parser)

      # Generate RBS if requested
      rbs_output = ""
      if generate_rbs && parser.ir_program
        generator = IR::RBSGenerator.new
        rbs_output = generator.generate(parser.ir_program)
      end

      {
        ruby: ruby_output,
        rbs: rbs_output,
        errors: [],
      }
    rescue ParseError => e
      {
        ruby: "",
        rbs: "",
        errors: [e.message],
      }
    rescue StandardError => e
      {
        ruby: "",
        rbs: "",
        errors: ["Compilation error: #{e.message}"],
      }
    end

    # Compile to IR without generating output files
    def compile_to_ir(input_path)
      unless File.exist?(input_path)
        raise ArgumentError, "File not found: #{input_path}"
      end

      source = File.read(input_path)
      parser = Parser.new(source)
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

    # Compute output path for a source file
    # @param input_path [String] path to source file
    # @param output_dir [String] base output directory
    # @param new_extension [String] new file extension (e.g., ".rb", ".rbs")
    # @return [String] computed output path (always preserves directory structure)
    def compute_output_path(input_path, output_dir, new_extension)
      relative = compute_relative_path(input_path)
      base = relative.sub(/\.[^.]+$/, new_extension)
      File.join(output_dir, base)
    end

    # Compute relative path from source directory
    # @param input_path [String] path to source file
    # @return [String] relative path preserving directory structure
    def compute_relative_path(input_path)
      # Use realpath to resolve symlinks (e.g., /var vs /private/var on macOS)
      absolute_input = resolve_path(input_path)
      source_dirs = @config.source_include

      # Check if file is inside any source_include directory
      if source_dirs.size > 1
        # Multiple source directories: include the source dir name in output
        # src/models/user.trb → src/models/user.trb
        source_dirs.each do |src_dir|
          absolute_src = resolve_path(src_dir)
          next unless absolute_input.start_with?("#{absolute_src}/")

          # Return path relative to parent of source dir (includes src dir name)
          parent_of_src = File.dirname(absolute_src)
          return absolute_input.sub("#{parent_of_src}/", "")
        end
      else
        # Single source directory: exclude the source dir name from output
        # src/models/user.trb → models/user.trb
        src_dir = source_dirs.first
        if src_dir
          absolute_src = resolve_path(src_dir)
          if absolute_input.start_with?("#{absolute_src}/")
            return absolute_input.sub("#{absolute_src}/", "")
          end
        end
      end

      # File outside source directories: use path relative to current working directory
      # external/foo.trb → external/foo.trb
      cwd = resolve_path(".")
      if absolute_input.start_with?("#{cwd}/")
        return absolute_input.sub("#{cwd}/", "")
      end

      # Absolute path from outside cwd: use basename only
      File.basename(input_path)
    end

    private

    # Check types in IR program and raise TypeCheckError if mismatches found
    # @param ir_program [IR::Program] IR program to check
    # @param file_path [String] source file path for error messages
    def check_types(ir_program, file_path)
      ir_program.declarations.each do |decl|
        case decl
        when IR::MethodDef
          check_method_return_type(decl, nil, file_path)
        when IR::ClassDecl
          decl.body.each do |member|
            check_method_return_type(member, decl, file_path) if member.is_a?(IR::MethodDef)
          end
        end
      end
    end

    # Check if method's inferred return type matches declared return type
    # @param method [IR::MethodDef] method to check
    # @param class_def [IR::ClassDef, nil] containing class if any
    # @param file_path [String] source file path for error messages
    def check_method_return_type(method, class_def, file_path)
      # Skip if no explicit return type annotation
      return unless method.return_type

      declared_type = normalize_type(method.return_type.to_rbs)

      # Create type environment for the class context
      class_env = create_class_env(class_def) if class_def

      # Infer actual return type
      inferred_type = @type_inferrer.infer_method_return_type(method, class_env)
      inferred_type = normalize_type(inferred_type || "nil")

      # Check compatibility
      return if types_compatible?(inferred_type, declared_type)

      location = method.location ? "#{file_path}:#{method.location}" : file_path
      method_name = class_def ? "#{class_def.name}##{method.name}" : method.name

      raise TypeCheckError.new(
        message: "Return type mismatch in method '#{method_name}': " \
                 "declared '#{declared_type}' but inferred '#{inferred_type}'",
        location: location,
        expected: declared_type,
        actual: inferred_type
      )
    end

    # Create type environment for class context
    # @param class_def [IR::ClassDecl] class declaration
    # @return [TypeEnv] type environment with instance variables
    def create_class_env(class_def)
      env = TypeEnv.new

      # Register instance variables from class
      class_def.instance_vars&.each do |ivar|
        type = ivar.type_annotation&.to_rbs || "untyped"
        env.define_instance_var(ivar.name, type)
      end

      env
    end

    # Normalize type string for comparison
    # @param type [String] type string
    # @return [String] normalized type string
    def normalize_type(type)
      return "untyped" if type.nil?

      normalized = type.to_s.strip

      # Normalize boolean types (bool/Boolean/TrueClass/FalseClass -> bool)
      case normalized
      when "Boolean", "TrueClass", "FalseClass"
        "bool"
      else
        normalized
      end
    end

    # Check if inferred type is compatible with declared type
    # @param inferred [String] inferred type
    # @param declared [String] declared type
    # @return [Boolean] true if compatible
    def types_compatible?(inferred, declared)
      # Exact match
      return true if inferred == declared

      # untyped is compatible with anything
      return true if inferred == "untyped" || declared == "untyped"

      # void is compatible with anything (no return value check)
      return true if declared == "void"

      # nil is compatible with nullable types
      return true if inferred == "nil" && declared.end_with?("?")

      # Subtype relationships
      return true if subtype_of?(inferred, declared)

      # Handle union types in declared
      if declared.include?("|")
        declared_types = declared.split("|").map(&:strip)
        return true if declared_types.include?(inferred)
        return true if declared_types.any? { |t| types_compatible?(inferred, t) }
      end

      # Handle union types in inferred - all must be compatible
      if inferred.include?("|")
        inferred_types = inferred.split("|").map(&:strip)
        return inferred_types.all? { |t| types_compatible?(t, declared) }
      end

      false
    end

    # Check if subtype is a subtype of supertype
    # @param subtype [String] potential subtype
    # @param supertype [String] potential supertype
    # @return [Boolean] true if subtype
    def subtype_of?(subtype, supertype)
      # Handle nullable - X is subtype of X?
      return true if supertype.end_with?("?") && supertype[0..-2] == subtype

      # Numeric hierarchy
      return true if subtype == "Integer" && supertype == "Numeric"
      return true if subtype == "Float" && supertype == "Numeric"

      # Object is supertype of everything
      return true if supertype == "Object"

      false
    end

    # Resolve path to absolute path, following symlinks
    # Falls back to expand_path if realpath fails (e.g., file doesn't exist yet)
    def resolve_path(path)
      File.realpath(path)
    rescue Errno::ENOENT
      File.expand_path(path)
    end

    def setup_declaration_paths
      # Add default declaration paths
      @declaration_loader.add_search_path(@config.out_dir)
      @declaration_loader.add_search_path(@config.src_dir)
      @declaration_loader.add_search_path("./types")
      @declaration_loader.add_search_path("./lib/types")
    end

    # Transform using IR system
    def transform_with_ir(source, parser)
      ir_program = parser.ir_program
      return source unless ir_program

      # Run optimization passes if enabled
      if @optimize && @optimizer
        result = @optimizer.optimize(ir_program)
        ir_program = result[:program]
      end

      # Generate Ruby code using IR-aware generator
      generator = IRCodeGenerator.new
      generator.generate_with_source(ir_program, source)
    end

    # Generate RBS from IR to a specific path
    def generate_rbs_from_ir_to_path(rbs_path, ir_program)
      return unless ir_program

      generator = IR::RBSGenerator.new
      rbs_content = generator.generate(ir_program)
      File.write(rbs_path, rbs_content) unless rbs_content.strip.empty?
    end

    def generate_dtrb_file(input_path, out_dir)
      dtrb_path = compute_output_path(input_path, out_dir, DeclarationGenerator::DECLARATION_EXTENSION)
      FileUtils.mkdir_p(File.dirname(dtrb_path))

      generator = DeclarationGenerator.new
      generator.generate_file_to_path(input_path, dtrb_path)
    end

    # Copy .rb file to output directory and generate .rbs signature
    def copy_ruby_file(input_path)
      unless File.exist?(input_path)
        raise ArgumentError, "File not found: #{input_path}"
      end

      # Compute output path (respects preserve_structure setting)
      output_path = compute_output_path(input_path, @config.ruby_dir, ".rb")
      FileUtils.mkdir_p(File.dirname(output_path))

      # Copy the .rb file to output directory
      FileUtils.cp(input_path, output_path)

      # Generate .rbs file if enabled in config
      if @config.compiler["generate_rbs"]
        rbs_path = compute_output_path(input_path, @config.rbs_dir, ".rbs")
        FileUtils.mkdir_p(File.dirname(rbs_path))
        generate_rbs_from_ruby_to_path(rbs_path, input_path)
      end

      output_path
    end

    # Generate RBS from Ruby file using rbs prototype to a specific path
    def generate_rbs_from_ruby_to_path(rbs_path, input_path)
      result = `rbs prototype rb #{input_path} 2>/dev/null`
      File.write(rbs_path, result) unless result.strip.empty?
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
      program.declarations
             .select { |d| d.is_a?(IR::TypeAlias) }
             .map(&:name)

      # Collect interface names to remove
      program.declarations
             .select { |d| d.is_a?(IR::Interface) }
             .map(&:name)

      # Remove type alias definitions
      result = result.gsub(/^\s*type\s+\w+\s*=\s*.+?$\n?/, "")

      # Remove interface definitions (multi-line)
      result = result.gsub(/^\s*interface\s+\w+.*?^\s*end\s*$/m, "")

      # Remove parameter type annotations using IR info
      # Enhanced: Handle complex types (generics, unions, etc.)
      result = erase_parameter_types(result)

      # Remove return type annotations
      result = erase_return_types(result)

      # Clean up extra blank lines
      result.gsub(/\n{3,}/, "\n\n")
    end

    private

    # Erase parameter type annotations
    def erase_parameter_types(source)
      result = source.dup

      # Match function definitions and remove type annotations from parameters
      # Also supports visibility modifiers: private def, protected def, public def
      result.gsub!(/^(\s*#{TRuby::VISIBILITY_PATTERN}def\s+#{TRuby::METHOD_NAME_PATTERN}\s*\()([^)]+)(\)\s*)(?::\s*[^\n]+)?(\s*$)/) do |_match|
        indent = ::Regexp.last_match(1)
        params = ::Regexp.last_match(2)
        close_paren = ::Regexp.last_match(3)
        ending = ::Regexp.last_match(4)

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
          if depth.zero?
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

    # Clean a single parameter (remove type annotation, preserve default value)
    def clean_param(param)
      # Match: name: Type = value (with default value)
      if (match = param.match(/^(#{TRuby::IDENTIFIER_CHAR}+)\s*:\s*.+?\s*(=\s*.+)$/))
        "#{match[1]} #{match[2]}"
      # Match: name: Type (without default value)
      elsif (match = param.match(/^(#{TRuby::IDENTIFIER_CHAR}+)\s*:/))
        match[1]
      else
        param
      end
    end

    # Erase return type annotations
    def erase_return_types(source)
      result = source.dup

      # Remove return type: ): Type or ): Type<Foo> etc.
      result.gsub!(/\)\s*:\s*[^\n]+?(?=\s*$)/m) do |_match|
        ")"
      end

      result
    end
  end
end
