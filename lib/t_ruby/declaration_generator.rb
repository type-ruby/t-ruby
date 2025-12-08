# frozen_string_literal: true

module TRuby
  # Generator for .d.trb type declaration files
  # Similar to TypeScript's .d.ts files
  class DeclarationGenerator
    DECLARATION_EXTENSION = ".d.trb"

    def initialize
      @parser = nil
    end

    # Generate declaration content from source code
    def generate(source)
      @parser = Parser.new(source)
      result = @parser.parse

      declarations = []

      # Add header comment
      declarations << "# Auto-generated type declaration file"
      declarations << "# Do not edit manually"
      declarations << ""

      # Generate type alias declarations
      (result[:type_aliases] || []).each do |type_alias|
        declarations << generate_type_alias(type_alias)
      end

      # Generate interface declarations
      (result[:interfaces] || []).each do |interface|
        declarations << generate_interface(interface)
      end

      # Generate function declarations
      (result[:functions] || []).each do |function|
        declarations << generate_function(function)
      end

      declarations.join("\n")
    end

    # Generate declaration file from a .trb source file
    def generate_file(input_path, output_dir = nil)
      unless File.exist?(input_path)
        raise ArgumentError, "File not found: #{input_path}"
      end

      unless input_path.end_with?(".trb")
        raise ArgumentError, "Expected .trb file, got: #{input_path}"
      end

      source = File.read(input_path)
      content = generate(source)

      # Determine output path
      output_dir ||= File.dirname(input_path)
      FileUtils.mkdir_p(output_dir)

      base_name = File.basename(input_path, ".trb")
      output_path = File.join(output_dir, "#{base_name}#{DECLARATION_EXTENSION}")

      File.write(output_path, content)
      output_path
    end

    private

    def generate_type_alias(type_alias)
      "type #{type_alias[:name]} = #{type_alias[:definition]}"
    end

    def generate_interface(interface)
      lines = []
      lines << "interface #{interface[:name]}"

      interface[:members].each do |member|
        lines << "  #{member[:name]}: #{member[:type]}"
      end

      lines << "end"
      lines.join("\n")
    end

    def generate_function(function)
      params = function[:params].map do |param|
        if param[:type]
          "#{param[:name]}: #{param[:type]}"
        else
          param[:name]
        end
      end.join(", ")

      return_type = function[:return_type] ? ": #{function[:return_type]}" : ""

      "def #{function[:name]}(#{params})#{return_type}"
    end
  end

  # Parser for .d.trb declaration files
  class DeclarationParser
    attr_reader :type_aliases, :interfaces, :functions

    def initialize
      @type_aliases = {}
      @interfaces = {}
      @functions = {}
    end

    # Parse a declaration file content (resets existing data)
    def parse(content)
      @type_aliases = {}
      @interfaces = {}
      @functions = {}

      parse_and_merge(content)
    end

    # Parse content and merge with existing data
    def parse_and_merge(content)
      parser = Parser.new(content)
      result = parser.parse

      # Process type aliases
      (result[:type_aliases] || []).each do |type_alias|
        @type_aliases[type_alias[:name]] = type_alias[:definition]
      end

      # Process interfaces
      (result[:interfaces] || []).each do |interface|
        @interfaces[interface[:name]] = interface
      end

      # Process functions
      (result[:functions] || []).each do |function|
        @functions[function[:name]] = function
      end

      self
    end

    # Parse a declaration file from path
    def parse_file(file_path)
      unless File.exist?(file_path)
        raise ArgumentError, "Declaration file not found: #{file_path}"
      end

      unless file_path.end_with?(DeclarationGenerator::DECLARATION_EXTENSION)
        raise ArgumentError, "Expected #{DeclarationGenerator::DECLARATION_EXTENSION} file, got: #{file_path}"
      end

      content = File.read(file_path)
      parse(content)
    end

    # Load multiple declaration files from a directory
    def load_directory(dir_path, recursive: false)
      unless Dir.exist?(dir_path)
        raise ArgumentError, "Directory not found: #{dir_path}"
      end

      pattern = recursive ? "**/*#{DeclarationGenerator::DECLARATION_EXTENSION}" : "*#{DeclarationGenerator::DECLARATION_EXTENSION}"
      files = Dir.glob(File.join(dir_path, pattern))

      files.each do |file|
        content = File.read(file)
        parse_and_merge(content)
      end

      self
    end

    # Check if a type is defined
    def type_defined?(name)
      @type_aliases.key?(name) || @interfaces.key?(name)
    end

    # Resolve a type alias
    def resolve_type(name)
      @type_aliases[name]
    end

    # Get an interface definition
    def get_interface(name)
      @interfaces[name]
    end

    # Get a function signature
    def get_function(name)
      @functions[name]
    end

    # Get all declarations as a hash
    def to_h
      {
        type_aliases: @type_aliases,
        interfaces: @interfaces,
        functions: @functions
      }
    end

    # Merge another parser's declarations into this one
    def merge(other_parser)
      @type_aliases.merge!(other_parser.type_aliases)
      @interfaces.merge!(other_parser.interfaces)
      @functions.merge!(other_parser.functions)
      self
    end
  end

  # Loader for managing declaration files
  class DeclarationLoader
    attr_reader :search_paths

    def initialize
      @search_paths = []
      @loaded_declarations = DeclarationParser.new
      @loaded_files = Set.new
    end

    # Add a search path for declaration files
    def add_search_path(path)
      @search_paths << path unless @search_paths.include?(path)
      self
    end

    # Load a specific declaration file by name (without extension)
    def load(name)
      file_name = "#{name}#{DeclarationGenerator::DECLARATION_EXTENSION}"

      @search_paths.each do |path|
        full_path = File.join(path, file_name)
        if File.exist?(full_path) && !@loaded_files.include?(full_path)
          parser = DeclarationParser.new
          parser.parse_file(full_path)
          @loaded_declarations.merge(parser)
          @loaded_files.add(full_path)
          return true
        end
      end

      false
    end

    # Load all declaration files from search paths
    def load_all
      @search_paths.each do |path|
        next unless Dir.exist?(path)

        Dir.glob(File.join(path, "*#{DeclarationGenerator::DECLARATION_EXTENSION}")).each do |file|
          next if @loaded_files.include?(file)

          parser = DeclarationParser.new
          parser.parse_file(file)
          @loaded_declarations.merge(parser)
          @loaded_files.add(file)
        end
      end

      self
    end

    # Get the combined declarations
    def declarations
      @loaded_declarations
    end

    # Check if a type is defined in any loaded declaration
    def type_defined?(name)
      @loaded_declarations.type_defined?(name)
    end

    # Resolve a type from loaded declarations
    def resolve_type(name)
      @loaded_declarations.resolve_type(name)
    end

    # Get all loaded type aliases
    def type_aliases
      @loaded_declarations.type_aliases
    end

    # Get all loaded interfaces
    def interfaces
      @loaded_declarations.interfaces
    end

    # Get all loaded functions
    def functions
      @loaded_declarations.functions
    end

    # Get list of loaded files
    def loaded_files
      @loaded_files.to_a
    end
  end
end
