# frozen_string_literal: true

module TRuby
  class CLI
    HELP_TEXT = <<~HELP
      t-ruby compiler (trc) v#{VERSION}

      Usage:
        trc <file.trb>           Compile a .trb file to .rb
        trc --init               Initialize a new t-ruby project
        trc --watch, -w          Watch input files and recompile on change
        trc --decl <file.trb>    Generate .d.trb declaration file
        trc --lsp                Start LSP server (for IDE integration)
        trc --version, -v        Show version
        trc --help, -h           Show this help

      Examples:
        trc hello.trb            Compile hello.trb to build/hello.rb
        trc --init               Create trbconfig.yml and src/, build/ directories
        trc -w                   Watch all .trb files in current directory
        trc -w src/              Watch all .trb files in src/ directory
        trc --watch hello.trb    Watch specific file for changes
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

      if @args.include?("--init")
        init_project
        return
      end

      if @args.include?("--lsp")
        start_lsp_server
        return
      end

      if @args.include?("--watch") || @args.include?("-w")
        start_watch_mode
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

    def init_project
      config_file = "trbconfig.yml"
      src_dir = "src"
      build_dir = "build"

      created = []
      skipped = []

      # Create trbconfig.yml
      if File.exist?(config_file)
        skipped << config_file
      else
        File.write(config_file, <<~YAML)
          emit:
            rb: true
            rbs: false
            dtrb: false

          paths:
            src: "./#{src_dir}"
            out: "./#{build_dir}"

          strict:
            rbs_compat: true
            null_safety: false
            inference: basic
        YAML
        created << config_file
      end

      # Create src/ directory
      if Dir.exist?(src_dir)
        skipped << "#{src_dir}/"
      else
        Dir.mkdir(src_dir)
        created << "#{src_dir}/"
      end

      # Create build/ directory
      if Dir.exist?(build_dir)
        skipped << "#{build_dir}/"
      else
        Dir.mkdir(build_dir)
        created << "#{build_dir}/"
      end

      # Output results
      if created.any?
        puts "Created: #{created.join(', ')}"
      end
      if skipped.any?
        puts "Skipped (already exists): #{skipped.join(', ')}"
      end
      if created.empty? && skipped.any?
        puts "Project already initialized."
      else
        puts "t-ruby project initialized successfully!"
      end
    end

    def start_lsp_server
      server = LSPServer.new
      server.run
    end

    def start_watch_mode
      # Get paths to watch (everything after --watch or -w flag)
      watch_index = @args.index("--watch") || @args.index("-w")
      paths = @args[(watch_index + 1)..]

      # Default to current directory if no paths specified
      paths = ["."] if paths.empty?

      config = Config.new
      watcher = Watcher.new(paths: paths, config: config)
      watcher.watch
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
