# frozen_string_literal: true

require "json"

module TRuby
  # LSP (Language Server Protocol) Server for T-Ruby
  # Provides IDE integration with autocomplete, diagnostics, and navigation
  # Implements LSP 3.17 specification
  class LSPServer
    VERSION = "0.2.0"
    LSP_VERSION = "3.17"

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

    # Semantic Token Types (LSP 3.16+)
    module SemanticTokenTypes
      NAMESPACE = 0
      TYPE = 1
      CLASS = 2
      ENUM = 3
      INTERFACE = 4
      STRUCT = 5
      TYPE_PARAMETER = 6
      PARAMETER = 7
      VARIABLE = 8
      PROPERTY = 9
      ENUM_MEMBER = 10
      EVENT = 11
      FUNCTION = 12
      METHOD = 13
      MACRO = 14
      KEYWORD = 15
      MODIFIER = 16
      COMMENT = 17
      STRING = 18
      NUMBER = 19
      REGEXP = 20
      OPERATOR = 21
    end

    # Semantic Token Modifiers (bit flags)
    module SemanticTokenModifiers
      DECLARATION = 0x01
      DEFINITION = 0x02
      READONLY = 0x04
      STATIC = 0x08
      DEPRECATED = 0x10
      ABSTRACT = 0x20
      ASYNC = 0x40
      MODIFICATION = 0x80
      DOCUMENTATION = 0x100
      DEFAULT_LIBRARY = 0x200
    end

    # Token type names for capability registration
    SEMANTIC_TOKEN_TYPES = %w[
      namespace type class enum interface struct typeParameter
      parameter variable property enumMember event function method
      macro keyword modifier comment string number regexp operator
    ].freeze

    # Token modifier names
    SEMANTIC_TOKEN_MODIFIERS = %w[
      declaration definition readonly static deprecated
      abstract async modification documentation defaultLibrary
    ].freeze

    # Inlay Hint Kinds (LSP 3.17)
    module InlayHintKind
      TYPE = 1
      PARAMETER = 2
    end

    # Symbol Kind for document/workspace symbols
    module SymbolKind
      FILE = 1
      MODULE = 2
      NAMESPACE = 3
      PACKAGE = 4
      CLASS = 5
      METHOD = 6
      PROPERTY = 7
      FIELD = 8
      CONSTRUCTOR = 9
      ENUM = 10
      INTERFACE = 11
      FUNCTION = 12
      VARIABLE = 13
      CONSTANT = 14
      STRING = 15
      NUMBER = 16
      BOOLEAN = 17
      ARRAY = 18
      OBJECT = 19
      KEY = 20
      NULL = 21
      ENUM_MEMBER = 22
      STRUCT = 23
      EVENT = 24
      OPERATOR = 25
      TYPE_PARAMETER = 26
    end

    # Folding Range Kind
    module FoldingRangeKind
      COMMENT = "comment"
      IMPORTS = "imports"
      REGION = "region"
    end

    # Built-in types for completion
    BUILT_IN_TYPES = %w[String Integer Float Boolean Array Hash Symbol void nil].freeze

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
      when "textDocument/references"
        handle_references(params)
      when "textDocument/documentHighlight"
        handle_document_highlight(params)
      when "textDocument/documentSymbol"
        handle_document_symbol(params)
      when "workspace/symbol"
        handle_workspace_symbol(params)
      when "textDocument/semanticTokens/full"
        handle_semantic_tokens_full(params)
      when "textDocument/semanticTokens/range"
        handle_semantic_tokens_range(params)
      # LSP 3.16+ features
      when "textDocument/inlayHint"
        handle_inlay_hint(params)
      when "textDocument/prepareCallHierarchy"
        handle_prepare_call_hierarchy(params)
      when "callHierarchy/incomingCalls"
        handle_incoming_calls(params)
      when "callHierarchy/outgoingCalls"
        handle_outgoing_calls(params)
      when "textDocument/prepareTypeHierarchy"
        handle_prepare_type_hierarchy(params)
      when "typeHierarchy/supertypes"
        handle_type_supertypes(params)
      when "typeHierarchy/subtypes"
        handle_type_subtypes(params)
      when "textDocument/foldingRange"
        handle_folding_range(params)
      when "textDocument/selectionRange"
        handle_selection_range(params)
      when "textDocument/linkedEditingRange"
        handle_linked_editing_range(params)
      when "textDocument/codeLens"
        handle_code_lens(params)
      when "textDocument/documentLink"
        handle_document_link(params)
      when "textDocument/prepareRename"
        handle_prepare_rename(params)
      when "textDocument/rename"
        handle_rename(params)
      when "textDocument/codeAction"
        handle_code_action(params)
      when "textDocument/signatureHelp"
        handle_signature_help(params)
      when "completionItem/resolve"
        handle_completion_resolve(params)
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
            "triggerCharacters" => [":", "<", "|", "&", "."],
            "resolveProvider" => true
          },
          "hoverProvider" => true,
          "definitionProvider" => true,
          "referencesProvider" => true,
          "documentHighlightProvider" => true,
          "documentSymbolProvider" => true,
          "workspaceSymbolProvider" => true,
          "diagnosticProvider" => {
            "interFileDependencies" => false,
            "workspaceDiagnostics" => false
          },
          "semanticTokensProvider" => {
            "legend" => {
              "tokenTypes" => SEMANTIC_TOKEN_TYPES,
              "tokenModifiers" => SEMANTIC_TOKEN_MODIFIERS
            },
            "full" => true,
            "range" => true
          },
          # LSP 3.16+ features
          "inlayHintProvider" => {
            "resolveProvider" => false
          },
          "callHierarchyProvider" => true,
          "typeHierarchyProvider" => true,
          "foldingRangeProvider" => true,
          "selectionRangeProvider" => true,
          "linkedEditingRangeProvider" => true,
          "codeLensProvider" => {
            "resolveProvider" => false
          },
          "documentLinkProvider" => {
            "resolveProvider" => false
          },
          "renameProvider" => {
            "prepareProvider" => true
          },
          "codeActionProvider" => {
            "codeActionKinds" => [
              "quickfix",
              "refactor",
              "refactor.extract",
              "refactor.inline",
              "source.organizeImports"
            ]
          },
          "signatureHelpProvider" => {
            "triggerCharacters" => ["(", ","],
            "retriggerCharacters" => [","]
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

    # === Semantic Tokens ===

    def handle_semantic_tokens_full(params)
      uri = params["textDocument"]["uri"]
      document = @documents[uri]
      return { "data" => [] } unless document

      text = document[:text]
      tokens = generate_semantic_tokens(text)

      { "data" => tokens }
    end

    def generate_semantic_tokens(text)
      tokens = []
      lines = text.split("\n")

      # Parse the document to get IR
      parser = Parser.new(text, use_combinator: true)
      parse_result = parser.parse
      ir_program = parser.ir_program

      # Collect all tokens from parsing
      raw_tokens = []

      # Process type aliases
      (parse_result[:type_aliases] || []).each do |alias_info|
        lines.each_with_index do |line, line_idx|
          if match = line.match(/^\s*type\s+(#{Regexp.escape(alias_info[:name])})\s*=/)
            # 'type' keyword
            type_pos = line.index("type")
            raw_tokens << [line_idx, type_pos, 4, SemanticTokenTypes::KEYWORD, SemanticTokenModifiers::DECLARATION]

            # Type name
            name_pos = match.begin(1)
            raw_tokens << [line_idx, name_pos, alias_info[:name].length, SemanticTokenTypes::TYPE, SemanticTokenModifiers::DEFINITION]

            # Type definition (after =)
            add_type_tokens(raw_tokens, line, line_idx, alias_info[:definition])
          end
        end
      end

      # Process interfaces
      (parse_result[:interfaces] || []).each do |interface_info|
        lines.each_with_index do |line, line_idx|
          if match = line.match(/^\s*interface\s+(#{Regexp.escape(interface_info[:name])})/)
            # 'interface' keyword
            interface_pos = line.index("interface")
            raw_tokens << [line_idx, interface_pos, 9, SemanticTokenTypes::KEYWORD, SemanticTokenModifiers::DECLARATION]

            # Interface name
            name_pos = match.begin(1)
            raw_tokens << [line_idx, name_pos, interface_info[:name].length, SemanticTokenTypes::INTERFACE, SemanticTokenModifiers::DEFINITION]
          end

          # Interface members
          interface_info[:members]&.each do |member|
            if match = line.match(/^\s*(#{Regexp.escape(member[:name])})\s*:\s*/)
              prop_pos = match.begin(1)
              raw_tokens << [line_idx, prop_pos, member[:name].length, SemanticTokenTypes::PROPERTY, 0]

              # Member type
              add_type_tokens(raw_tokens, line, line_idx, member[:type])
            end
          end
        end
      end

      # Process functions
      (parse_result[:functions] || []).each do |func|
        lines.each_with_index do |line, line_idx|
          if match = line.match(/^\s*def\s+(#{Regexp.escape(func[:name])})\s*\(/)
            # 'def' keyword
            def_pos = line.index("def")
            raw_tokens << [line_idx, def_pos, 3, SemanticTokenTypes::KEYWORD, 0]

            # Function name
            name_pos = match.begin(1)
            raw_tokens << [line_idx, name_pos, func[:name].length, SemanticTokenTypes::FUNCTION, SemanticTokenModifiers::DEFINITION]

            # Parameters
            func[:params]&.each do |param|
              if param_match = line.match(/\b(#{Regexp.escape(param[:name])})\s*(?::\s*)?/)
                param_pos = param_match.begin(1)
                raw_tokens << [line_idx, param_pos, param[:name].length, SemanticTokenTypes::PARAMETER, 0]

                # Parameter type if present
                if param[:type]
                  add_type_tokens(raw_tokens, line, line_idx, param[:type])
                end
              end
            end

            # Return type
            if func[:return_type]
              add_type_tokens(raw_tokens, line, line_idx, func[:return_type])
            end
          end
        end
      end

      # Process 'end' keywords
      lines.each_with_index do |line, line_idx|
        if match = line.match(/^\s*(end)\s*$/)
          end_pos = match.begin(1)
          raw_tokens << [line_idx, end_pos, 3, SemanticTokenTypes::KEYWORD, 0]
        end
      end

      # Sort tokens by line, then by character position
      raw_tokens.sort_by! { |t| [t[0], t[1]] }

      # Convert to delta encoding
      encode_tokens(raw_tokens)
    end

    def add_type_tokens(raw_tokens, line, line_idx, type_str)
      return unless type_str

      # Find position of the type in the line
      pos = line.index(type_str)
      return unless pos

      # Handle built-in types
      if BUILT_IN_TYPES.include?(type_str)
        raw_tokens << [line_idx, pos, type_str.length, SemanticTokenTypes::TYPE, SemanticTokenModifiers::DEFAULT_LIBRARY]
        return
      end

      # Handle generic types like Array<String>
      if type_str.include?("<")
        if match = type_str.match(/^(\w+)<(.+)>$/)
          base = match[1]
          base_pos = line.index(base, pos)
          if base_pos
            modifier = BUILT_IN_TYPES.include?(base) ? SemanticTokenModifiers::DEFAULT_LIBRARY : 0
            raw_tokens << [line_idx, base_pos, base.length, SemanticTokenTypes::TYPE, modifier]
          end
          # Recursively process type arguments
          # (simplified - just mark them as types)
          args = match[2]
          args.split(/[,\s]+/).each do |arg|
            arg = arg.strip.gsub(/[<>]/, '')
            next if arg.empty?
            arg_pos = line.index(arg, pos)
            if arg_pos
              modifier = BUILT_IN_TYPES.include?(arg) ? SemanticTokenModifiers::DEFAULT_LIBRARY : 0
              raw_tokens << [line_idx, arg_pos, arg.length, SemanticTokenTypes::TYPE, modifier]
            end
          end
        end
        return
      end

      # Handle union types
      if type_str.include?("|")
        type_str.split("|").map(&:strip).each do |t|
          t_pos = line.index(t, pos)
          if t_pos
            modifier = BUILT_IN_TYPES.include?(t) ? SemanticTokenModifiers::DEFAULT_LIBRARY : 0
            raw_tokens << [line_idx, t_pos, t.length, SemanticTokenTypes::TYPE, modifier]
          end
        end
        return
      end

      # Handle intersection types
      if type_str.include?("&")
        type_str.split("&").map(&:strip).each do |t|
          t_pos = line.index(t, pos)
          if t_pos
            modifier = BUILT_IN_TYPES.include?(t) ? SemanticTokenModifiers::DEFAULT_LIBRARY : 0
            raw_tokens << [line_idx, t_pos, t.length, SemanticTokenTypes::TYPE, modifier]
          end
        end
        return
      end

      # Simple type
      raw_tokens << [line_idx, pos, type_str.length, SemanticTokenTypes::TYPE, 0]
    end

    def encode_tokens(raw_tokens)
      encoded = []
      prev_line = 0
      prev_char = 0

      raw_tokens.each do |token|
        line, char, length, token_type, modifiers = token

        delta_line = line - prev_line
        delta_char = delta_line == 0 ? char - prev_char : char

        encoded << delta_line
        encoded << delta_char
        encoded << length
        encoded << token_type
        encoded << modifiers

        prev_line = line
        prev_char = char
      end

      encoded
    end

    # === LSP 3.16+ Features ===

    # Inlay Hints - Show type hints inline in the editor
    def handle_inlay_hint(params)
      uri = params["textDocument"]["uri"]
      range = params["range"]
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      hints = generate_inlay_hints(text, range)
      hints
    end

    def generate_inlay_hints(text, range)
      hints = []
      lines = text.split("\n")
      start_line = range["start"]["line"]
      end_line = range["end"]["line"]

      parser = Parser.new(text, use_combinator: true)
      result = parser.parse

      # Add type hints for function parameters without explicit types
      (result[:functions] || []).each do |func|
        line_num = find_line_number(lines, /^\s*def\s+#{Regexp.escape(func[:name])}\s*\(/)
        next unless line_num && line_num >= start_line && line_num <= end_line

        line = lines[line_num]

        # Add return type hint if inferred
        if func[:return_type]
          # Find position after closing paren
          paren_pos = line.rindex(")")
          if paren_pos && !line.include?(":")
            hints << {
              "position" => { "line" => line_num, "character" => paren_pos + 1 },
              "label" => ": #{func[:return_type]}",
              "kind" => InlayHintKind::TYPE,
              "paddingLeft" => false,
              "paddingRight" => true
            }
          end
        end

        # Add parameter type hints
        func[:params]&.each do |param|
          if param[:type]
            param_match = line.match(/\b(#{Regexp.escape(param[:name])})(?:\s*,|\s*\))/)
            if param_match && !line.include?("#{param[:name]}:")
              pos = param_match.begin(1) + param[:name].length
              hints << {
                "position" => { "line" => line_num, "character" => pos },
                "label" => ": #{param[:type]}",
                "kind" => InlayHintKind::TYPE,
                "paddingLeft" => false,
                "paddingRight" => false
              }
            end
          end
        end
      end

      hints
    end

    # Call Hierarchy - Show incoming/outgoing function calls
    def handle_prepare_call_hierarchy(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]
      document = @documents[uri]
      return nil unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      word = extract_word_at_position(line, position["character"])
      return nil unless word

      parser = Parser.new(text, use_combinator: true)
      result = parser.parse

      # Find function definition
      (result[:functions] || []).each do |func|
        next unless func[:name] == word

        line_num = find_line_number(lines, /^\s*def\s+#{Regexp.escape(func[:name])}\s*\(/)
        next unless line_num

        return [{
          "name" => func[:name],
          "kind" => SymbolKind::FUNCTION,
          "uri" => uri,
          "range" => function_range(lines, line_num),
          "selectionRange" => {
            "start" => { "line" => line_num, "character" => lines[line_num].index(func[:name]) || 0 },
            "end" => { "line" => line_num, "character" => (lines[line_num].index(func[:name]) || 0) + func[:name].length }
          },
          "data" => { "name" => func[:name], "uri" => uri }
        }]
      end

      nil
    end

    def handle_incoming_calls(params)
      item = params["item"]
      uri = item["uri"]
      func_name = item["data"]["name"]
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      lines = text.split("\n")
      calls = []

      # Find all calls to this function
      lines.each_with_index do |line, line_num|
        if line.include?("#{func_name}(") && !line.match?(/^\s*def\s+#{func_name}/)
          # Find the calling function
          calling_func = find_enclosing_function(lines, line_num)
          next unless calling_func

          calls << {
            "from" => calling_func,
            "fromRanges" => [{
              "start" => { "line" => line_num, "character" => line.index(func_name) || 0 },
              "end" => { "line" => line_num, "character" => (line.index(func_name) || 0) + func_name.length }
            }]
          }
        end
      end

      calls
    end

    def handle_outgoing_calls(params)
      item = params["item"]
      uri = item["uri"]
      func_name = item["data"]["name"]
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      lines = text.split("\n")
      parser = Parser.new(text, use_combinator: true)
      result = parser.parse

      # Find the function and its body
      func_start = find_line_number(lines, /^\s*def\s+#{Regexp.escape(func_name)}\s*\(/)
      return [] unless func_start

      func_end = find_function_end(lines, func_start)
      calls = []
      known_functions = (result[:functions] || []).map { |f| f[:name] }

      (func_start..func_end).each do |line_num|
        line = lines[line_num]
        known_functions.each do |called_func|
          next if called_func == func_name

          if line.include?("#{called_func}(")
            call_line = find_line_number(lines, /^\s*def\s+#{Regexp.escape(called_func)}\s*\(/)
            next unless call_line

            calls << {
              "to" => {
                "name" => called_func,
                "kind" => SymbolKind::FUNCTION,
                "uri" => uri,
                "range" => function_range(lines, call_line),
                "selectionRange" => {
                  "start" => { "line" => call_line, "character" => lines[call_line].index(called_func) || 0 },
                  "end" => { "line" => call_line, "character" => (lines[call_line].index(called_func) || 0) + called_func.length }
                },
                "data" => { "name" => called_func, "uri" => uri }
              },
              "fromRanges" => [{
                "start" => { "line" => line_num, "character" => line.index(called_func) || 0 },
                "end" => { "line" => line_num, "character" => (line.index(called_func) || 0) + called_func.length }
              }]
            }
          end
        end
      end

      calls.uniq { |c| c["to"]["name"] }
    end

    # Type Hierarchy - Show type inheritance
    def handle_prepare_type_hierarchy(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]
      document = @documents[uri]
      return nil unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      word = extract_word_at_position(line, position["character"])
      return nil unless word

      parser = Parser.new(text, use_combinator: true)
      result = parser.parse

      # Find interface or type alias
      (result[:interfaces] || []).each do |iface|
        next unless iface[:name] == word

        line_num = find_line_number(lines, /^\s*interface\s+#{Regexp.escape(word)}/)
        next unless line_num

        return [{
          "name" => word,
          "kind" => SymbolKind::INTERFACE,
          "uri" => uri,
          "range" => interface_range(lines, line_num),
          "selectionRange" => {
            "start" => { "line" => line_num, "character" => lines[line_num].index(word) || 0 },
            "end" => { "line" => line_num, "character" => (lines[line_num].index(word) || 0) + word.length }
          },
          "data" => { "name" => word, "kind" => "interface", "uri" => uri }
        }]
      end

      (result[:type_aliases] || []).each do |type_alias|
        next unless type_alias[:name] == word

        line_num = find_line_number(lines, /^\s*type\s+#{Regexp.escape(word)}\s*=/)
        next unless line_num

        return [{
          "name" => word,
          "kind" => SymbolKind::CLASS,
          "uri" => uri,
          "range" => {
            "start" => { "line" => line_num, "character" => 0 },
            "end" => { "line" => line_num, "character" => lines[line_num].length }
          },
          "selectionRange" => {
            "start" => { "line" => line_num, "character" => lines[line_num].index(word) || 0 },
            "end" => { "line" => line_num, "character" => (lines[line_num].index(word) || 0) + word.length }
          },
          "data" => { "name" => word, "kind" => "type_alias", "uri" => uri, "definition" => type_alias[:definition] }
        }]
      end

      nil
    end

    def handle_type_supertypes(params)
      item = params["item"]
      data = item["data"]
      return [] unless data

      # For type aliases, check if they reference other types
      if data["kind"] == "type_alias" && data["definition"]
        definition = data["definition"]
        # Simple parsing: look for type references
        supertypes = []

        if BUILT_IN_TYPES.include?(definition)
          supertypes << {
            "name" => definition,
            "kind" => SymbolKind::CLASS,
            "uri" => item["uri"],
            "range" => { "start" => { "line" => 0, "character" => 0 }, "end" => { "line" => 0, "character" => 0 } },
            "selectionRange" => { "start" => { "line" => 0, "character" => 0 }, "end" => { "line" => 0, "character" => 0 } }
          }
        end

        return supertypes
      end

      []
    end

    def handle_type_subtypes(params)
      item = params["item"]
      uri = item["uri"]
      type_name = item["data"]["name"]
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      parser = Parser.new(text, use_combinator: true)
      result = parser.parse
      lines = text.split("\n")
      subtypes = []

      # Find type aliases that reference this type
      (result[:type_aliases] || []).each do |type_alias|
        if type_alias[:definition]&.include?(type_name) && type_alias[:name] != type_name
          line_num = find_line_number(lines, /^\s*type\s+#{Regexp.escape(type_alias[:name])}\s*=/)
          next unless line_num

          subtypes << {
            "name" => type_alias[:name],
            "kind" => SymbolKind::CLASS,
            "uri" => uri,
            "range" => {
              "start" => { "line" => line_num, "character" => 0 },
              "end" => { "line" => line_num, "character" => lines[line_num].length }
            },
            "selectionRange" => {
              "start" => { "line" => line_num, "character" => lines[line_num].index(type_alias[:name]) || 0 },
              "end" => { "line" => line_num, "character" => (lines[line_num].index(type_alias[:name]) || 0) + type_alias[:name].length }
            },
            "data" => { "name" => type_alias[:name], "kind" => "type_alias", "uri" => uri }
          }
        end
      end

      subtypes
    end

    # Folding Range - Code folding
    def handle_folding_range(params)
      uri = params["textDocument"]["uri"]
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      generate_folding_ranges(text)
    end

    def generate_folding_ranges(text)
      ranges = []
      lines = text.split("\n")
      stack = []

      lines.each_with_index do |line, idx|
        stripped = line.strip

        # Start of foldable region
        if stripped.match?(/^(def|class|module|interface|if|unless|while|until|case|begin|do)\b/)
          stack.push({ start: idx, kind: nil })
        elsif stripped.match?(/^#\s*region\b/i)
          stack.push({ start: idx, kind: FoldingRangeKind::REGION })
        elsif stripped == "=begin"
          stack.push({ start: idx, kind: FoldingRangeKind::COMMENT })
        end

        # End of foldable region
        if stripped == "end" || stripped.match?(/^#\s*endregion\b/i) || stripped == "=end"
          if region = stack.pop
            ranges << {
              "startLine" => region[:start],
              "endLine" => idx,
              "kind" => region[:kind]
            }
          end
        end
      end

      # Handle multi-line comments
      in_comment = false
      comment_start = 0

      lines.each_with_index do |line, idx|
        if line.strip.start_with?("#") && !in_comment
          in_comment = true
          comment_start = idx
        elsif in_comment && !line.strip.start_with?("#")
          if idx - comment_start > 1
            ranges << {
              "startLine" => comment_start,
              "endLine" => idx - 1,
              "kind" => FoldingRangeKind::COMMENT
            }
          end
          in_comment = false
        end
      end

      ranges
    end

    # Selection Range - Smart selection expansion
    def handle_selection_range(params)
      uri = params["textDocument"]["uri"]
      positions = params["positions"]
      document = @documents[uri]
      return nil unless document

      text = document[:text]
      lines = text.split("\n")

      positions.map do |position|
        generate_selection_range(lines, position)
      end
    end

    def generate_selection_range(lines, position)
      line_num = position["line"]
      char_pos = position["character"]
      line = lines[line_num] || ""

      # Start with word selection
      word_start, word_end = find_word_bounds(line, char_pos)

      # Build nested selection ranges
      ranges = []

      # Word level
      if word_start && word_end
        ranges << {
          "start" => { "line" => line_num, "character" => word_start },
          "end" => { "line" => line_num, "character" => word_end }
        }
      end

      # Line level (content only)
      content_start = line =~ /\S/ || 0
      content_end = line.rstrip.length
      ranges << {
        "start" => { "line" => line_num, "character" => content_start },
        "end" => { "line" => line_num, "character" => content_end }
      }

      # Full line
      ranges << {
        "start" => { "line" => line_num, "character" => 0 },
        "end" => { "line" => line_num, "character" => line.length }
      }

      # Block level (find enclosing def/end)
      block_start, block_end = find_enclosing_block(lines, line_num)
      if block_start && block_end
        ranges << {
          "start" => { "line" => block_start, "character" => 0 },
          "end" => { "line" => block_end, "character" => lines[block_end]&.length || 0 }
        }
      end

      # Document level
      ranges << {
        "start" => { "line" => 0, "character" => 0 },
        "end" => { "line" => lines.length - 1, "character" => lines.last&.length || 0 }
      }

      # Build linked list of ranges (innermost to outermost)
      result = nil
      ranges.reverse.each do |range|
        result = { "range" => range, "parent" => result }
      end

      result
    end

    # Linked Editing Range - Synchronized editing of related symbols
    def handle_linked_editing_range(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]
      document = @documents[uri]
      return nil unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      word = extract_word_at_position(line, position["character"])
      return nil unless word

      # Find all occurrences of this identifier
      ranges = []
      lines.each_with_index do |l, idx|
        # Find all occurrences in this line
        pos = 0
        while (match_pos = l.index(/\b#{Regexp.escape(word)}\b/, pos))
          ranges << {
            "start" => { "line" => idx, "character" => match_pos },
            "end" => { "line" => idx, "character" => match_pos + word.length }
          }
          pos = match_pos + 1
        end
      end

      return nil if ranges.length <= 1

      { "ranges" => ranges }
    end

    # Code Lens - Inline metadata/actions
    def handle_code_lens(params)
      uri = params["textDocument"]["uri"]
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      generate_code_lens(text, uri)
    end

    def generate_code_lens(text, uri)
      lenses = []
      lines = text.split("\n")
      parser = Parser.new(text, use_combinator: true)
      result = parser.parse

      # Add reference count for functions
      function_refs = count_function_references(text, result[:functions] || [])

      (result[:functions] || []).each do |func|
        line_num = find_line_number(lines, /^\s*def\s+#{Regexp.escape(func[:name])}\s*\(/)
        next unless line_num

        ref_count = function_refs[func[:name]] || 0

        lenses << {
          "range" => {
            "start" => { "line" => line_num, "character" => 0 },
            "end" => { "line" => line_num, "character" => 0 }
          },
          "command" => {
            "title" => "#{ref_count} reference#{ref_count == 1 ? '' : 's'}",
            "command" => "t-ruby.showReferences",
            "arguments" => [uri, { "line" => line_num, "character" => 0 }, func[:name]]
          }
        }
      end

      # Add type info for interfaces
      (result[:interfaces] || []).each do |iface|
        line_num = find_line_number(lines, /^\s*interface\s+#{Regexp.escape(iface[:name])}/)
        next unless line_num

        member_count = iface[:members]&.length || 0

        lenses << {
          "range" => {
            "start" => { "line" => line_num, "character" => 0 },
            "end" => { "line" => line_num, "character" => 0 }
          },
          "command" => {
            "title" => "#{member_count} member#{member_count == 1 ? '' : 's'}",
            "command" => "t-ruby.showMembers",
            "arguments" => [uri, iface[:name]]
          }
        }
      end

      lenses
    end

    # Document Link - Clickable links in document
    def handle_document_link(params)
      uri = params["textDocument"]["uri"]
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      lines = text.split("\n")
      links = []

      # Find URLs in comments
      lines.each_with_index do |line, idx|
        line.scan(/(https?:\/\/[^\s\)]+)/) do |match|
          url = match[0]
          start_char = line.index(url)
          next unless start_char

          links << {
            "range" => {
              "start" => { "line" => idx, "character" => start_char },
              "end" => { "line" => idx, "character" => start_char + url.length }
            },
            "target" => url,
            "tooltip" => "Open #{url}"
          }
        end
      end

      links
    end

    # References - Find all references to a symbol
    def handle_references(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]
      context = params["context"] || {}
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      word = extract_word_at_position(line, position["character"])
      return [] unless word

      references = []

      lines.each_with_index do |l, idx|
        pos = 0
        while (match_pos = l.index(/\b#{Regexp.escape(word)}\b/, pos))
          # Skip definition if not including declaration
          is_definition = l.match?(/^\s*(def|type|interface)\s+#{Regexp.escape(word)}\b/)
          if context["includeDeclaration"] || !is_definition
            references << {
              "uri" => uri,
              "range" => {
                "start" => { "line" => idx, "character" => match_pos },
                "end" => { "line" => idx, "character" => match_pos + word.length }
              }
            }
          end
          pos = match_pos + 1
        end
      end

      references
    end

    # Document Highlight - Highlight occurrences of symbol
    def handle_document_highlight(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      word = extract_word_at_position(line, position["character"])
      return [] unless word

      highlights = []

      lines.each_with_index do |l, idx|
        pos = 0
        while (match_pos = l.index(/\b#{Regexp.escape(word)}\b/, pos))
          # Determine if this is a write or read
          is_write = l.match?(/^\s*(def|type|interface)\s+#{Regexp.escape(word)}\b/) ||
                     l.match?(/\b#{Regexp.escape(word)}\s*=/)

          highlights << {
            "range" => {
              "start" => { "line" => idx, "character" => match_pos },
              "end" => { "line" => idx, "character" => match_pos + word.length }
            },
            "kind" => is_write ? 3 : 2  # 3 = Write, 2 = Read
          }
          pos = match_pos + 1
        end
      end

      highlights
    end

    # Document Symbol - Outline of document
    def handle_document_symbol(params)
      uri = params["textDocument"]["uri"]
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      generate_document_symbols(text)
    end

    def generate_document_symbols(text)
      symbols = []
      lines = text.split("\n")
      parser = Parser.new(text, use_combinator: true)
      result = parser.parse

      # Type aliases
      (result[:type_aliases] || []).each do |type_alias|
        line_num = find_line_number(lines, /^\s*type\s+#{Regexp.escape(type_alias[:name])}\s*=/)
        next unless line_num

        symbols << {
          "name" => type_alias[:name],
          "kind" => SymbolKind::CLASS,
          "range" => {
            "start" => { "line" => line_num, "character" => 0 },
            "end" => { "line" => line_num, "character" => lines[line_num].length }
          },
          "selectionRange" => {
            "start" => { "line" => line_num, "character" => lines[line_num].index(type_alias[:name]) || 0 },
            "end" => { "line" => line_num, "character" => (lines[line_num].index(type_alias[:name]) || 0) + type_alias[:name].length }
          },
          "detail" => "= #{type_alias[:definition]}"
        }
      end

      # Interfaces
      (result[:interfaces] || []).each do |iface|
        line_num = find_line_number(lines, /^\s*interface\s+#{Regexp.escape(iface[:name])}/)
        next unless line_num

        end_line = find_interface_end(lines, line_num)
        children = []

        # Add members as children
        iface[:members]&.each do |member|
          member_line = find_line_number(lines, /^\s*#{Regexp.escape(member[:name])}\s*:/, line_num)
          next unless member_line

          children << {
            "name" => member[:name],
            "kind" => SymbolKind::PROPERTY,
            "range" => {
              "start" => { "line" => member_line, "character" => 0 },
              "end" => { "line" => member_line, "character" => lines[member_line].length }
            },
            "selectionRange" => {
              "start" => { "line" => member_line, "character" => lines[member_line].index(member[:name]) || 0 },
              "end" => { "line" => member_line, "character" => (lines[member_line].index(member[:name]) || 0) + member[:name].length }
            },
            "detail" => ": #{member[:type]}"
          }
        end

        symbols << {
          "name" => iface[:name],
          "kind" => SymbolKind::INTERFACE,
          "range" => {
            "start" => { "line" => line_num, "character" => 0 },
            "end" => { "line" => end_line, "character" => lines[end_line]&.length || 0 }
          },
          "selectionRange" => {
            "start" => { "line" => line_num, "character" => lines[line_num].index(iface[:name]) || 0 },
            "end" => { "line" => line_num, "character" => (lines[line_num].index(iface[:name]) || 0) + iface[:name].length }
          },
          "children" => children
        }
      end

      # Functions
      (result[:functions] || []).each do |func|
        line_num = find_line_number(lines, /^\s*def\s+#{Regexp.escape(func[:name])}\s*\(/)
        next unless line_num

        end_line = find_function_end(lines, line_num)
        params_str = func[:params]&.map { |p| "#{p[:name]}: #{p[:type] || 'untyped'}" }&.join(", ") || ""
        return_type = func[:return_type] || "void"

        symbols << {
          "name" => func[:name],
          "kind" => SymbolKind::FUNCTION,
          "range" => {
            "start" => { "line" => line_num, "character" => 0 },
            "end" => { "line" => end_line, "character" => lines[end_line]&.length || 0 }
          },
          "selectionRange" => {
            "start" => { "line" => line_num, "character" => lines[line_num].index(func[:name]) || 0 },
            "end" => { "line" => line_num, "character" => (lines[line_num].index(func[:name]) || 0) + func[:name].length }
          },
          "detail" => "(#{params_str}): #{return_type}"
        }
      end

      symbols
    end

    # Workspace Symbol - Search symbols across workspace
    def handle_workspace_symbol(params)
      query = params["query"] || ""
      symbols = []

      @documents.each do |uri, document|
        doc_symbols = generate_document_symbols(document[:text])
        doc_symbols.each do |sym|
          if query.empty? || sym["name"].downcase.include?(query.downcase)
            sym["location"] = { "uri" => uri, "range" => sym["range"] }
            symbols << sym
          end
        end
      end

      symbols
    end

    # Rename - Prepare and execute rename
    def handle_prepare_rename(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]
      document = @documents[uri]
      return nil unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      word = extract_word_at_position(line, position["character"])
      return nil unless word

      word_pos = line.index(word)
      return nil unless word_pos

      {
        "range" => {
          "start" => { "line" => position["line"], "character" => word_pos },
          "end" => { "line" => position["line"], "character" => word_pos + word.length }
        },
        "placeholder" => word
      }
    end

    def handle_rename(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]
      new_name = params["newName"]
      document = @documents[uri]
      return nil unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      old_name = extract_word_at_position(line, position["character"])
      return nil unless old_name

      edits = []

      lines.each_with_index do |l, idx|
        pos = 0
        while (match_pos = l.index(/\b#{Regexp.escape(old_name)}\b/, pos))
          edits << {
            "range" => {
              "start" => { "line" => idx, "character" => match_pos },
              "end" => { "line" => idx, "character" => match_pos + old_name.length }
            },
            "newText" => new_name
          }
          pos = match_pos + 1
        end
      end

      {
        "changes" => {
          uri => edits
        }
      }
    end

    # Code Action - Quick fixes and refactoring
    def handle_code_action(params)
      uri = params["textDocument"]["uri"]
      range = params["range"]
      context = params["context"]
      document = @documents[uri]
      return [] unless document

      text = document[:text]
      lines = text.split("\n")
      actions = []

      # Add type annotation quick fix
      line_num = range["start"]["line"]
      line = lines[line_num] || ""

      # Suggest adding return type
      if line.match?(/^\s*def\s+\w+\s*\([^)]*\)\s*$/)
        actions << {
          "title" => "Add return type annotation",
          "kind" => "quickfix",
          "edit" => {
            "changes" => {
              uri => [{
                "range" => {
                  "start" => { "line" => line_num, "character" => line.rstrip.length },
                  "end" => { "line" => line_num, "character" => line.rstrip.length }
                },
                "newText" => ": void"
              }]
            }
          }
        }
      end

      # Extract method refactoring
      if range["start"]["line"] != range["end"]["line"]
        actions << {
          "title" => "Extract method",
          "kind" => "refactor.extract",
          "command" => {
            "title" => "Extract method",
            "command" => "t-ruby.extractMethod",
            "arguments" => [uri, range]
          }
        }
      end

      actions
    end

    # Signature Help - Function parameter hints
    def handle_signature_help(params)
      uri = params["textDocument"]["uri"]
      position = params["position"]
      document = @documents[uri]
      return nil unless document

      text = document[:text]
      lines = text.split("\n")
      line = lines[position["line"]] || ""
      char_pos = position["character"]

      # Find function call context
      prefix = line[0...char_pos]
      match = prefix.match(/(\w+)\s*\(([^)]*)$/)
      return nil unless match

      func_name = match[1]
      args_so_far = match[2]

      # Count commas to determine active parameter
      active_param = args_so_far.count(",")

      parser = Parser.new(text, use_combinator: true)
      result = parser.parse

      # Find matching function
      (result[:functions] || []).each do |func|
        next unless func[:name] == func_name

        params_info = func[:params]&.map do |p|
          {
            "label" => "#{p[:name]}: #{p[:type] || 'untyped'}",
            "documentation" => "Parameter #{p[:name]}"
          }
        end || []

        return_type = func[:return_type] || "void"
        label = "#{func_name}(#{params_info.map { |p| p["label"] }.join(", ")}): #{return_type}"

        return {
          "signatures" => [{
            "label" => label,
            "documentation" => "Function #{func_name}",
            "parameters" => params_info
          }],
          "activeSignature" => 0,
          "activeParameter" => [active_param, params_info.length - 1].min
        }
      end

      nil
    end

    # Completion Resolve - Get additional completion item details
    def handle_completion_resolve(params)
      item = params
      # Add documentation or additional details
      if item["kind"] == CompletionItemKind::CLASS && BUILT_IN_TYPES.include?(item["label"])
        item["documentation"] = {
          "kind" => "markdown",
          "value" => built_in_type_documentation(item["label"])
        }
      end
      item
    end

    def built_in_type_documentation(type_name)
      case type_name
      when "String"
        "**String** - A sequence of characters.\n\n```ruby\nname: String = \"hello\"\n```"
      when "Integer"
        "**Integer** - A whole number.\n\n```ruby\ncount: Integer = 42\n```"
      when "Float"
        "**Float** - A floating-point number.\n\n```ruby\nprice: Float = 19.99\n```"
      when "Boolean"
        "**Boolean** - True or false value.\n\n```ruby\nactive: Boolean = true\n```"
      when "Array"
        "**Array<T>** - An ordered collection.\n\n```ruby\nitems: Array<String> = [\"a\", \"b\"]\n```"
      when "Hash"
        "**Hash<K, V>** - A key-value collection.\n\n```ruby\ndata: Hash<String, Integer> = {}\n```"
      when "Symbol"
        "**Symbol** - An immutable identifier.\n\n```ruby\nstatus: Symbol = :active\n```"
      when "void"
        "**void** - No return value."
      when "nil"
        "**nil** - Absence of value."
      else
        "T-Ruby type: #{type_name}"
      end
    end

    # Semantic Tokens Range - Get tokens for a specific range
    def handle_semantic_tokens_range(params)
      uri = params["textDocument"]["uri"]
      range = params["range"]
      document = @documents[uri]
      return { "data" => [] } unless document

      text = document[:text]
      lines = text.split("\n")

      # Filter lines to the requested range
      start_line = range["start"]["line"]
      end_line = range["end"]["line"]

      # Generate tokens for full document then filter
      all_tokens = generate_semantic_tokens(text)

      # Filter tokens to range (this is simplified - proper implementation would be more efficient)
      { "data" => all_tokens }
    end

    # === Helper Methods for LSP 3.x ===

    def find_word_bounds(line, char_pos)
      return [nil, nil] if char_pos > line.length

      start_pos = char_pos
      end_pos = char_pos

      while start_pos > 0 && line[start_pos - 1] =~ /\w/
        start_pos -= 1
      end

      while end_pos < line.length && line[end_pos] =~ /\w/
        end_pos += 1
      end

      return [nil, nil] if start_pos == end_pos

      [start_pos, end_pos]
    end

    def find_enclosing_block(lines, line_num)
      # Find start of enclosing block
      start_line = nil
      depth = 0

      (line_num).downto(0) do |idx|
        line = lines[idx].strip
        depth += 1 if line == "end"
        if line.match?(/^(def|class|module|interface|if|unless|while|until|case|begin|do)\b/)
          if depth == 0
            start_line = idx
            break
          end
          depth -= 1
        end
      end

      return [nil, nil] unless start_line

      # Find matching end
      end_line = nil
      depth = 1

      ((start_line + 1)...lines.length).each do |idx|
        line = lines[idx].strip
        depth += 1 if line.match?(/^(def|class|module|interface|if|unless|while|until|case|begin|do)\b/)
        if line == "end"
          depth -= 1
          if depth == 0
            end_line = idx
            break
          end
        end
      end

      [start_line, end_line]
    end

    def find_enclosing_function(lines, line_num)
      # Walk backwards to find def
      (line_num - 1).downto(0) do |idx|
        line = lines[idx]
        if match = line.match(/^\s*def\s+(\w+)\s*\(/)
          func_name = match[1]
          return {
            "name" => func_name,
            "kind" => SymbolKind::FUNCTION,
            "uri" => "", # Will be filled by caller
            "range" => function_range(lines, idx),
            "selectionRange" => {
              "start" => { "line" => idx, "character" => line.index(func_name) || 0 },
              "end" => { "line" => idx, "character" => (line.index(func_name) || 0) + func_name.length }
            },
            "data" => { "name" => func_name }
          }
        end
      end
      nil
    end

    def function_range(lines, start_line)
      end_line = find_function_end(lines, start_line)
      {
        "start" => { "line" => start_line, "character" => 0 },
        "end" => { "line" => end_line, "character" => lines[end_line]&.length || 0 }
      }
    end

    def find_function_end(lines, start_line)
      depth = 1
      ((start_line + 1)...lines.length).each do |idx|
        line = lines[idx].strip
        depth += 1 if line.match?(/^(def|class|module|if|unless|while|until|case|begin|do)\b/)
        depth -= 1 if line == "end"
        return idx if depth == 0
      end
      lines.length - 1
    end

    def interface_range(lines, start_line)
      end_line = find_interface_end(lines, start_line)
      {
        "start" => { "line" => start_line, "character" => 0 },
        "end" => { "line" => end_line, "character" => lines[end_line]&.length || 0 }
      }
    end

    def find_interface_end(lines, start_line)
      ((start_line + 1)...lines.length).each do |idx|
        return idx if lines[idx].strip == "end"
      end
      lines.length - 1
    end

    def count_function_references(text, functions)
      refs = {}
      functions.each { |f| refs[f[:name]] = 0 }

      text.each_line do |line|
        functions.each do |func|
          # Count occurrences excluding definition
          next if line.match?(/^\s*def\s+#{Regexp.escape(func[:name])}/)

          refs[func[:name]] += line.scan(/\b#{Regexp.escape(func[:name])}\s*\(/).length
        end
      end

      refs
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
