# frozen_string_literal: true

module TRuby
  class CLI
    HELP_TEXT = <<~HELP.freeze
      t-ruby compiler (trc) v#{VERSION}

      Usage:
        trc <file.trb>           Compile a .trb file to .rb
        trc <file.rb>            Copy .rb file to build/ and generate .rbs
        trc --init               Initialize a new t-ruby project
        trc --config, -c <path>  Use custom config file
        trc --watch, -w          Watch input files and recompile on change
        trc --decl <file.trb>    Generate .d.trb declaration file
        trc --lsp                Start LSP server (for IDE integration)
        trc update               Update t-ruby to the latest version
        trc --version, -v        Show version (and check for updates)
        trc --help, -h           Show this help

      Examples:
        trc hello.trb            Compile hello.trb to build/hello.rb
        trc utils.rb             Copy utils.rb to build/ and generate utils.rbs
        trc --init               Create trbconfig.yml and src/, build/ directories
        trc -c custom.yml file.trb  Compile with custom config file
        trc -w                   Watch all .trb and .rb files in current directory
        trc -w src/              Watch all .trb and .rb files in src/ directory
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
        check_for_updates
        return
      end

      if @args.include?("update")
        update_gem
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

      # Extract config path if --config or -c flag is present
      config_path = extract_config_path

      # Get input file (first non-flag argument)
      input_file = find_input_file
      compile(input_file, config_path: config_path)
    end

    private

    def check_for_updates
      result = VersionChecker.check
      return unless result

      puts ""
      puts "New version available: #{result[:latest]} (current: #{result[:current]})"
      puts "Run 'trc update' to update"
    end

    def update_gem
      puts "Updating t-ruby..."
      if VersionChecker.update
        puts "Successfully updated t-ruby!"
      else
        puts "Update failed. Try: gem install t-ruby"
      end
    end

    def init_project
      config_file = "trbconfig.yml"
      src_dir = "src"
      build_dir = "build"

      created = []
      skipped = []

      # Create trbconfig.yml with new schema
      if File.exist?(config_file)
        skipped << config_file
      else
        File.write(config_file, <<~YAML)
          # T-Ruby configuration file
          # See: https://type-ruby.github.io/docs/getting-started/project-configuration

          source:
            include:
              - #{src_dir}
            exclude: []
            extensions:
              - ".trb"
              - ".rb"

          output:
            ruby_dir: #{build_dir}
            # rbs_dir: sig  # Optional: separate directory for .rbs files
            # clean_before_build: false

          compiler:
            strictness: standard  # strict | standard | permissive
            generate_rbs: true
            target_ruby: "#{RubyVersion.current.major}.#{RubyVersion.current.minor}"
            # experimental: []
            # checks:
            #   no_implicit_any: false
            #   no_unused_vars: false
            #   strict_nil: false

          watch:
            # paths: []  # Additional paths to watch
            debounce: 100
            # clear_screen: false
            # on_success: "bundle exec rspec"
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
        puts "Created: #{created.join(", ")}"
      end
      if skipped.any?
        puts "Skipped (already exists): #{skipped.join(", ")}"
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

    def compile(input_file, config_path: nil)
      config = Config.new(config_path)
      compiler = Compiler.new(config)

      output_path = compiler.compile(input_file)
      puts "Compiled: #{input_file} -> #{output_path}"
    rescue TypeCheckError => e
      puts "Type error: #{e.message}"
      exit 1
    rescue ArgumentError => e
      puts "Error: #{e.message}"
      exit 1
    end

    # Extract config path from --config or -c flag
    def extract_config_path
      config_index = @args.index("--config") || @args.index("-c")
      return nil unless config_index

      @args[config_index + 1]
    end

    # Find the input file (first non-flag argument)
    def find_input_file
      skip_next = false
      @args.each do |arg|
        if skip_next
          skip_next = false
          next
        end

        # Skip known flags with arguments
        if %w[--config -c --decl].include?(arg)
          skip_next = true
          next
        end

        # Skip flags without arguments
        next if arg.start_with?("-")

        return arg
      end
      nil
    end
  end
end
