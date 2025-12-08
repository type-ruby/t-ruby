# frozen_string_literal: true

module TRuby
  class CLI
    HELP_TEXT = <<~HELP
      t-ruby compiler (trc) v#{VERSION}

      Usage:
        trc <file.trb>           Compile a .trb file to .rb
        trc --decl <file.trb>    Generate .d.trb declaration file
        trc --lsp                Start LSP server (for IDE integration)
        trc --version, -v        Show version
        trc --help, -h           Show this help

      Examples:
        trc hello.trb            Compile hello.trb to build/hello.rb
        trc --decl hello.trb     Generate hello.d.trb declaration file
        trc --lsp                Start language server for VS Code
    HELP

    def self.run(args)
      new(args).run
    end

    def initialize(args)
      @args = args
    end

    def run
      if @args.empty? || @args.include?("--help") || @args.include?("-h")
        puts HELP_TEXT
        return
      end

      if @args.include?("--version") || @args.include?("-v")
        puts "trc #{VERSION}"
        return
      end

      if @args.include?("--lsp")
        start_lsp_server
        return
      end

      if @args.include?("--decl")
        input_file = @args[@args.index("--decl") + 1]
        generate_declaration(input_file)
        return
      end

      input_file = @args.first
      compile(input_file)
    end

    private

    def start_lsp_server
      server = LSPServer.new
      server.run
    end

    def generate_declaration(input_file)
      config = Config.new
      generator = DeclarationGenerator.new

      output_path = generator.generate_file(input_file, config.out_dir)
      puts "Generated: #{input_file} -> #{output_path}"
    rescue ArgumentError => e
      puts "Error: #{e.message}"
      exit 1
    end

    def compile(input_file)
      config = Config.new
      compiler = Compiler.new(config)

      output_path = compiler.compile(input_file)
      puts "Compiled: #{input_file} -> #{output_path}"
    rescue ArgumentError => e
      puts "Error: #{e.message}"
      exit 1
    end
  end
end
