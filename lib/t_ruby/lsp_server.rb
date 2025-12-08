# frozen_string_literal: true

require "json"

module TRuby
  # LSP (Language Server Protocol) Server for T-Ruby
  # Provides IDE integration with autocomplete, diagnostics, and navigation
  class LSPServer
    VERSION = "0.1.0"

    # LSP Error codes
    module ErrorCodes
      PARSE_ERROR = -32700
      INVALID_REQUEST = -32600
      METHOD_NOT_FOUND = -32601
      INVALID_PARAMS = -32602
      INTERNAL_ERROR = -32603
      SERVER_NOT_INITIALIZED = -32002
      UNKNOWN_ERROR_CODE = -32001
    end

    # LSP Completion item kinds
    module CompletionItemKind
      TEXT = 1
      METHOD = 2
      FUNCTION = 3
      CONSTRUCTOR = 4
      FIELD = 5
      VARIABLE = 6
      CLASS = 7
      INTERFACE = 8
      MODULE = 9
      PROPERTY = 10
      UNIT = 11
      VALUE = 12
      ENUM = 13
      KEYWORD = 14
      SNIPPET = 15
      COLOR = 16
      FILE = 17
      REFERENCE = 18
      FOLDER = 19
      ENUM_MEMBER = 20
      CONSTANT = 21
      STRUCT = 22
      EVENT = 23
      OPERATOR = 24
      TYPE_PARAMETER = 25
    end

    # LSP Diagnostic severity
    module DiagnosticSeverity
      ERROR = 1
      WARNING = 2
      INFORMATION = 3
      HINT = 4
    end

    # Built-in types for completion
    BUILT_IN_TYPES = %w[String Integer Boolean Array Hash Symbol void nil].freeze

    # Type keywords for completion
    TYPE_KEYWORDS = %w[type interface def end].freeze

    def initialize(input: $stdin, output: $stdout)
      @input = input
      @output = output
      @documents = {}
      @initialized = false
      @shutdown_requested = false
      @type_alias_registry = TypeAliasRegistry.new
    end

    # Main run loop for the LSP server
    def run
      loop do
        message = read_message
        break if message.nil?

        response = handle_message(message)
        send_response(response) if response
      end
    end

    # Read a single LSP message from input
    def read_message
      # Read headers
      headers = {}
      loop do
        line = @input.gets
        return nil if line.nil?

        line = line.strip
        break if line.empty?

        if line =~ /^([^:]+):\s*(.+)$/
          headers[Regexp.last_match(1)] = Regexp.last_match(2)
        end
      end

      content_length = headers["Content-Length"]&.to_i
      return nil unless content_length && content_length > 0

      # Read content
      content = @input.read(content_length)
      return nil if content.nil?

      JSON.parse(content)
    rescue JSON::ParserError => e
      { "error" => "Parse error: #{e.message}" }
    end

    # Send a response message
    def send_response(response)
      return if response.nil?

      content = JSON.generate(response)
      message = "Content-Length: #{content.bytesize}\r\n\r\n#{content}"
      @output.write(message)
      @output.flush
    end

    # Send a notification (no response expected)
    def send_notification(method, params)
      notification = {
        "jsonrpc" => "2.0",
        "method" => method,
        "params" => params
      }
      send_response(notification)
    end

    # Handle an incoming message
    def handle_message(message)
      return error_response(nil, ErrorCodes::PARSE_ERROR, "Parse error") if message["error"]

      method = message["method"]
      params = message["params"] || {}
      id = message["id"]

      # Check if server is initialized for non-init methods
      if !@initialized && method != "initialize" && method != "exit"
        return error_response(id, ErrorCodes::SERVER_NOT_INITIALIZED, "Server not initialized")
      end

      result = dispatch_method(method, params, id)

      # For notifications (no id), don't send a response
      return nil if id.nil?

      if result.is_a?(Hash) && result[:error]
        error_response(id, result[:error][:code], result[:error][:message])
      else
        success_response(id, result)
      end
    end

    private

    def dispatch_method(method, params, id)
      case method
      when "initialize"
        handle_initialize(params)
      when "initialized"
        handle_initialized(params)
      when "shutdown"
        handle_shutdown
      when "exit"
        handle_exit
      when "textDocument/didOpen"
        handle_did_open(params)
      when "textDocument/didChange"
        handle_did_change(params)
      when "textDocument/didClose"
        handle_did_close(params)
      when "textDocument/completion"
        handle_completion(params)
      when "textDocument/hover"
        handle_hover(params)
      when "textDocument/definition"
        handle_definition(params)
      else
        { error: { code: ErrorCodes::METHOD_NOT_FOUND, message: "Method not found: #{method}" } }
      end
    end

    # === LSP Lifecycle Methods ===

    def handle_initialize(params)
      @initialized = true
      @root_uri = params["rootUri"]
      @workspace_folders = params["workspaceFolders"]

      {
        "capabilities" => {
          "textDocumentSync" => {
            "openClose" => true,
            "change" => 1, # Full sync
            "save" => { "includeText" => true }
          },
          "completionProvider" => {
            "triggerCharacters" => [":", "<", "|", "&"],
            "resolveProvider" => false
          },
          "hoverProvider" => true,
          "definitionProvider" => true,
          "diagnosticProvider" => {
            "interFileDependencies" => false,
            "workspaceDiagnostics" => false
          }
        },
        "serverInfo" => {
          "name" => "t-ruby-lsp",
          "version" => VERSION
        }
      }
    end

    def handle_initialized(_params)
      # Server is now fully initialized
      nil
    end

    def handle_shutdown
      @shutdown_requested = true
      nil
    end

    def handle_exit
      exit(@shutdown_requested ? 0 : 1)
    end

    # === Document Synchronization ===

    def handle_did_open(params)
      text_document = params["textDocument"]
      uri = text_document["uri"]
      text = text_document["text"]

      @documents[uri] = {
        text: text,
        version: text_document["version"]
      }

      # Parse and send diagnostics
      publish_diagnostics(uri, text)
      nil
    end

    def handle_did_change(params)
      text_document = params["textDocument"]
      uri = text_document["uri"]
      changes = params["contentChanges"]

      # For full sync, take the last change
      if changes && !changes.empty?
        @documents[uri] = {
          text: changes.last["text"],
          version: text_document["version"]
        }

        # Re-parse and send diagnostics
        publish_diagnostics(uri, changes.last["text"])
      end
      nil
    end

    def handle_did_close(params)
      uri = params["textDocument"]["uri"]
      @documents.delete(uri)

      # Clear diagnostics
      send_notification("textDocument/publishDiagnostics", {
        "uri" => uri,
        "diagnostics" => []
      })
      nil
    end

    # === Diagnostics ===

    def publish_diagnostics(uri, text)
      diagnostics = analyze_document(text)

      send_notification("textDocument/publishDiagnostics", {
        "uri" => uri,
        "diagnostics" => diagnostics
      })
    end

    def analyze_document(text)
      diagnostics = []

      # Use ErrorHandler to check for errors
      error_handler = ErrorHandler.new(text)
      errors = error_handler.check

      errors.each do |error|
        # Parse line number from error message
        if error =~ /^Line (\d+):\s*(.+)$/
          line_num = Regexp.last_match(1).to_i - 1 # LSP uses 0-based line numbers
          message = Regexp.last_match(2)

          diagnostics << create_diagnostic(line_num, message, DiagnosticSeverity::ERROR)
        end
      end

      # Additional validation using Parser
      begin
        parser = Parser.new(text)
        result = parser.parse

        # Validate type aliases
        validate_type_aliases(result[:type_aliases] || [], diagnostics, text)

        # Validate function types
        validate_functions(result[:functions] || [], diagnostics, text)
      rescue StandardError => e
        diagnostics << create_diagnostic(0, "Parse error: #{e.message}", DiagnosticSeverity::ERROR)
      end

      diagnostics
    end

    def validate_type_aliases(type_aliases, diagnostics, text)
      lines = text.split("\n")
      registry = TypeAliasRegistry.new

      type_aliases.each do |alias_info|
        line_num = find_line_number(lines, /^\s*type\s+#{Regexp.escape(alias_info[:name])}\s*=/)
        next unless line_num

        begin
          registry.register(alias_info[:name], alias_info[:definition])
        rescue DuplicateTypeAliasError => e
          diagnostics << create_diagnostic(line_num, e.message, DiagnosticSeverity::ERROR)
        rescue CircularTypeAliasError => e
          diagnostics << create_diagnostic(line_num, e.message, DiagnosticSeverity::ERROR)
        end
      end
    end

    def validate_functions(functions, diagnostics, text)
      lines = text.split("\n")

      functions.each do |func|
        line_num = find_line_number(lines, /^\s*def\s+#{Regexp.escape(func[:name])}\s*\(/)
        next unless line_num

        # Validate return type
        if func[:return_type]
          unless valid_type?(func[:return_type])
            diagnostics << create_diagnostic(
              line_num,
              "Unknown return type '#{func[:return_type]}'",
              DiagnosticSeverity::WARNING
            )
          end
        end

        # Validate parameter types
        func[:params]&.each do |param|
          if param[:type] && !valid_type?(param[:type])
            diagnostics << create_diagnostic(
              line_num,
              "Unknown parameter type '#{param[:type]}' for '#{param[:name]}'",
              DiagnosticSeverity::WARNING
            )
          end
        end
      end
    end

    def find_line_number(lines, pattern)
      lines.each_with_index do |line, idx|
        return idx if line.match?(pattern)
      end
      nil
    end

    def valid_type?(type_str)
      return true if type_str.nil?

      # Handle union types
      if type_str.include?("|")
        return type_str.split("|").map(&:strip).all? { |t| valid_type?(t) }
      end

      # Handle intersection types
      if type_str.include?("&")
        return type_str.split("&").map(&:strip).all? { |t| valid_type?(t) }
      end

      # Handle generic types
      if type_str.include?("<")
        base_type = type_str.split("<").first
        return BUILT_IN_TYPES.include?(base_type) || @type_alias_registry.valid_type?(base_type)
      end

      BUILT_IN_TYPES.include?(type_str) || @type_alias_registry.valid_type?(type_str)
    end

    def create_diagnostic(line, message, severity)
      {
        "range" => {
          "start" => { "line" => line, "character" => 0 },
          "end" => { "line" => line, "character" => 1000 }
        },
        "severity" => severity,
        "source" => "t-ruby",
        "message" => message
      }
    end

    # === Completion ===

    def handle_completion(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]

      document = @documents[uri]
      return { "items" => [] } unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      char_pos = position["character"]

      # Get the text before cursor
      prefix = line[0...char_pos] || ""

      completions = []

      # Context-aware completion
      if prefix =~ /:\s*$/
        # After colon - suggest types
        completions.concat(type_completions)
      elsif prefix =~ /\|\s*$/
        # After pipe - suggest types for union
        completions.concat(type_completions)
      elsif prefix =~ /&\s*$/
        # After ampersand - suggest types for intersection
        completions.concat(type_completions)
      elsif prefix =~ /<\s*$/
        # Inside generic - suggest types
        completions.concat(type_completions)
      elsif prefix =~ /^\s*$/
        # Start of line - suggest keywords
        completions.concat(keyword_completions)
      elsif prefix =~ /^\s*def\s+\w*$/
        # Function definition - no completion needed
        completions = []
      elsif prefix =~ /^\s*type\s+\w*$/
        # Type alias definition - no completion needed
        completions = []
      elsif prefix =~ /^\s*interface\s+\w*$/
        # Interface definition - no completion needed
        completions = []
      else
        # Default - suggest all
        completions.concat(type_completions)
        completions.concat(keyword_completions)
      end

      # Add document-specific completions
      completions.concat(document_type_completions(text))

      { "items" => completions }
    end

    def type_completions
      BUILT_IN_TYPES.map do |type|
        {
          "label" => type,
          "kind" => CompletionItemKind::CLASS,
          "detail" => "Built-in type",
          "documentation" => "T-Ruby built-in type: #{type}"
        }
      end
    end

    def keyword_completions
      TYPE_KEYWORDS.map do |keyword|
        {
          "label" => keyword,
          "kind" => CompletionItemKind::KEYWORD,
          "detail" => "Keyword",
          "documentation" => keyword_documentation(keyword)
        }
      end
    end

    def keyword_documentation(keyword)
      case keyword
      when "type"
        "Define a type alias: type AliasName = TypeDefinition"
      when "interface"
        "Define an interface: interface Name ... end"
      when "def"
        "Define a function with type annotations: def name(param: Type): ReturnType"
      when "end"
        "End a block (interface, class, method, etc.)"
      else
        keyword
      end
    end

    def document_type_completions(text)
      completions = []
      parser = Parser.new(text)
      result = parser.parse

      # Add type aliases from the document
      (result[:type_aliases] || []).each do |alias_info|
        completions << {
          "label" => alias_info[:name],
          "kind" => CompletionItemKind::CLASS,
          "detail" => "Type alias",
          "documentation" => "type #{alias_info[:name]} = #{alias_info[:definition]}"
        }
      end

      # Add interfaces from the document
      (result[:interfaces] || []).each do |interface_info|
        completions << {
          "label" => interface_info[:name],
          "kind" => CompletionItemKind::INTERFACE,
          "detail" => "Interface",
          "documentation" => "interface #{interface_info[:name]}"
        }
      end

      completions
    end

    # === Hover ===

    def handle_hover(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]

      document = @documents[uri]
      return nil unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      char_pos = position["character"]

      # Find the word at cursor position
      word = extract_word_at_position(line, char_pos)
      return nil if word.nil? || word.empty?

      hover_info = get_hover_info(word, text)
      return nil unless hover_info

      {
        "contents" => {
          "kind" => "markdown",
          "value" => hover_info
        },
        "range" => word_range(position["line"], line, char_pos, word)
      }
    end

    def extract_word_at_position(line, char_pos)
      return nil if char_pos > line.length

      # Find word boundaries
      start_pos = char_pos
      end_pos = char_pos

      # Move start back to word start
      while start_pos > 0 && line[start_pos - 1] =~ /[\w<>]/
        start_pos -= 1
      end

      # Move end forward to word end
      while end_pos < line.length && line[end_pos] =~ /[\w<>]/
        end_pos += 1
      end

      return nil if start_pos == end_pos

      line[start_pos...end_pos]
    end

    def word_range(line_num, line, char_pos, word)
      start_pos = line.index(word) || char_pos
      end_pos = start_pos + word.length

      {
        "start" => { "line" => line_num, "character" => start_pos },
        "end" => { "line" => line_num, "character" => end_pos }
      }
    end

    def get_hover_info(word, text)
      # Check if it's a built-in type
      if BUILT_IN_TYPES.include?(word)
        return "**#{word}** - Built-in T-Ruby type"
      end

      # Check if it's a type alias
      parser = Parser.new(text)
      result = parser.parse

      (result[:type_aliases] || []).each do |alias_info|
        if alias_info[:name] == word
          return "**Type Alias**\n\n```ruby\ntype #{alias_info[:name]} = #{alias_info[:definition]}\n```"
        end
      end

      # Check if it's an interface
      (result[:interfaces] || []).each do |interface_info|
        if interface_info[:name] == word
          members = interface_info[:members].map { |m| "  #{m[:name]}: #{m[:type]}" }.join("\n")
          return "**Interface**\n\n```ruby\ninterface #{interface_info[:name]}\n#{members}\nend\n```"
        end
      end

      # Check if it's a function
      (result[:functions] || []).each do |func|
        if func[:name] == word
          params = func[:params].map { |p| "#{p[:name]}: #{p[:type] || 'untyped'}" }.join(", ")
          return_type = func[:return_type] || "void"
          return "**Function**\n\n```ruby\ndef #{func[:name]}(#{params}): #{return_type}\n```"
        end
      end

      nil
    end

    # === Definition ===

    def handle_definition(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]

      document = @documents[uri]
      return nil unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      char_pos = position["character"]

      word = extract_word_at_position(line, char_pos)
      return nil if word.nil? || word.empty?

      # Find definition location
      location = find_definition(word, text, uri)
      return nil unless location

      location
    end

    def find_definition(word, text, uri)
      lines = text.split("\n")

      # Search for type alias definition
      lines.each_with_index do |line, idx|
        if line.match?(/^\s*type\s+#{Regexp.escape(word)}\s*=/)
          return {
            "uri" => uri,
            "range" => {
              "start" => { "line" => idx, "character" => 0 },
              "end" => { "line" => idx, "character" => line.length }
            }
          }
        end
      end

      # Search for interface definition
      lines.each_with_index do |line, idx|
        if line.match?(/^\s*interface\s+#{Regexp.escape(word)}\s*$/)
          return {
            "uri" => uri,
            "range" => {
              "start" => { "line" => idx, "character" => 0 },
              "end" => { "line" => idx, "character" => line.length }
            }
          }
        end
      end

      # Search for function definition
      lines.each_with_index do |line, idx|
        if line.match?(/^\s*def\s+#{Regexp.escape(word)}\s*\(/)
          return {
            "uri" => uri,
            "range" => {
              "start" => { "line" => idx, "character" => 0 },
              "end" => { "line" => idx, "character" => line.length }
            }
          }
        end
      end

      nil
    end

    # === Response Helpers ===

    def success_response(id, result)
      {
        "jsonrpc" => "2.0",
        "id" => id,
        "result" => result
      }
    end

    def error_response(id, code, message)
      {
        "jsonrpc" => "2.0",
        "id" => id,
        "error" => {
          "code" => code,
          "message" => message
        }
      }
    end
  end
end
