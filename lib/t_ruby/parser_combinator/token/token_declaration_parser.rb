# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Token Declaration Parser - Parse top-level declarations
    class TokenDeclarationParser
      include TokenDSL

      # Parse error with location info
      class ParseError
        attr_reader :message, :line, :column, :token

        def initialize(message, token: nil)
          @message = message
          @token = token
          @line = token&.line || 1
          @column = token&.column || 1
        end

        def to_s
          "Line #{@line}, Column #{@column}: #{@message}"
        end
      end

      attr_reader :errors

      def initialize
        @statement_parser = StatementParser.new
        @expression_parser = ExpressionParser.new
        @errors = []
      end

      def parse_declaration(tokens, position = 0)
        return TokenParseResult.failure("End of input", tokens, position) if position >= tokens.length

        position = skip_newlines(tokens, position)
        return TokenParseResult.failure("End of input", tokens, position) if position >= tokens.length

        token = tokens[position]

        case token.type
        when :def
          parse_method_def(tokens, position)
        when :public, :private, :protected
          parse_visibility_method(tokens, position)
        when :class
          parse_class(tokens, position)
        when :module
          parse_module(tokens, position)
        when :type
          parse_type_alias(tokens, position)
        when :interface
          parse_interface(tokens, position)
        else
          TokenParseResult.failure("Expected declaration, got #{token.type}", tokens, position)
        end
      end

      def parse_program(tokens, position = 0)
        declarations = []
        @errors = []

        loop do
          position = skip_newlines(tokens, position)
          break if position >= tokens.length
          break if tokens[position].type == :eof

          token = tokens[position]

          # Check if this looks like a declaration keyword
          unless declaration_keyword?(token.type)
            # Not a declaration - skip to next line (top-level expression is allowed)
            position = skip_to_next_line(tokens, position)
            next
          end

          result = parse_declaration(tokens, position)

          if result.failure?
            # Collect error and try to recover
            # Use result.position for accurate error location (where the error actually occurred)
            error_pos = result.position
            error_token = tokens[error_pos] if error_pos < tokens.length
            @errors << ParseError.new(result.error, token: error_token)

            # Try to skip to next declaration (find next 'def', 'class', etc.)
            position = skip_to_next_declaration(tokens, position)
            next
          end

          declarations << result.value
          position = result.position
        end

        program = IR::Program.new(declarations: declarations)
        TokenParseResult.success(program, tokens, position)
      end

      # Check if parsing encountered any errors
      def has_errors?
        !@errors.empty?
      end

      private

      def skip_newlines(tokens, position)
        position += 1 while position < tokens.length && %i[newline comment].include?(tokens[position].type)
        position
      end

      # Check if token type is a declaration keyword
      def declaration_keyword?(type)
        %i[def class module type interface public private protected].include?(type)
      end

      # Skip to the next line (for top-level expressions)
      def skip_to_next_line(tokens, position)
        while position < tokens.length
          break if tokens[position].type == :newline

          position += 1
        end
        position += 1 if position < tokens.length # skip the newline itself
        position
      end

      # Skip to the next top-level declaration keyword for error recovery
      def skip_to_next_declaration(tokens, position)
        declaration_keywords = %i[def class module type interface public private protected]

        # First, skip the current token
        position += 1

        while position < tokens.length
          token = tokens[position]

          # Found a declaration keyword at start of line (or after newline)
          if declaration_keywords.include?(token.type)
            # Check if this is at start of a logical line
            prev_token = tokens[position - 1] if position.positive?
            if prev_token.nil? || prev_token.type == :newline
              return position
            end
          end

          # Skip to next line if we hit newline
          if token.type == :newline
            position += 1
            # Skip comments and blank lines
            position = skip_newlines(tokens, position)
            next
          end

          position += 1
        end

        position
      end

      def parse_method_def(tokens, position, visibility: :public)
        # Capture def token's location before consuming
        def_token = tokens[position]
        def_line = def_token.line
        def_column = def_token.column

        position += 1 # consume 'def'

        # Parse method name (identifier or operator)
        return TokenParseResult.failure("Expected method name", tokens, position) if position >= tokens.length

        method_name = tokens[position].value
        position += 1

        # Check for unexpected tokens after method name (indicates space in method name)
        if position < tokens.length
          next_token = tokens[position]
          # After method name, only these are valid: ( : newline end
          # If we see an identifier, it means there was a space in the method name
          if next_token.type == :identifier
            return TokenParseResult.failure(
              "Unexpected token '#{next_token.value}' after method name '#{method_name}' - method names cannot contain spaces",
              tokens,
              position
            )
          end
        end

        # Parse parameters
        params = []
        if position < tokens.length && tokens[position].type == :lparen
          position += 1 # consume (

          # Parse parameter list
          unless tokens[position].type == :rparen
            loop do
              param_result = parse_parameter(tokens, position)
              return param_result if param_result.failure?

              # Handle keyword args group which returns an array
              if param_result.value.is_a?(Array)
                params.concat(param_result.value)
              else
                params << param_result.value
              end
              position = param_result.position

              break unless tokens[position]&.type == :comma

              position += 1
            end
          end

          return TokenParseResult.failure("Expected ')'", tokens, position) unless tokens[position]&.type == :rparen

          position += 1
        end

        # Parse return type
        return_type = nil
        if position < tokens.length && tokens[position].type == :colon
          colon_token = tokens[position]

          # Check: no space allowed before colon (method name or ) must be adjacent to :)
          prev_token = tokens[position - 1]
          if prev_token && prev_token.end_pos < colon_token.start_pos
            return TokenParseResult.failure(
              "No space allowed before ':' for return type annotation",
              tokens,
              position
            )
          end

          position += 1

          # Check: space required after colon before type name
          if position < tokens.length
            type_token = tokens[position]
            if colon_token.end_pos == type_token.start_pos
              return TokenParseResult.failure(
                "Space required after ':' before return type",
                tokens,
                position
              )
            end
          end

          type_result = parse_type(tokens, position)
          return type_result if type_result.failure?

          return_type = type_result.value
          position = type_result.position
        elsif position < tokens.length && tokens[position].type == :symbol
          # Handle case where :TypeName was scanned as a symbol (no space after colon)
          # In method definition context, this is a syntax error
          symbol_token = tokens[position]
          type_name = symbol_token.value[1..] # Remove leading ':'

          # Only if it looks like a type name (starts with uppercase)
          if type_name =~ /^[A-Z]/
            # Check: no space allowed before colon
            prev_token = tokens[position - 1]
            if prev_token && prev_token.end_pos < symbol_token.start_pos
              return TokenParseResult.failure(
                "No space allowed before ':' for return type annotation",
                tokens,
                position
              )
            end

            # Error: space required after colon
            return TokenParseResult.failure(
              "Space required after ':' before return type",
              tokens,
              position
            )
          end
        end

        position = skip_newlines(tokens, position)

        # Parse body
        body_result = @statement_parser.parse_block(tokens, position)
        position = body_result.position
        position = skip_newlines(tokens, position)

        # Expect 'end'
        if position < tokens.length && tokens[position].type == :end
          position += 1
        end

        node = IR::MethodDef.new(
          name: method_name,
          params: params,
          return_type: return_type,
          body: body_result.value,
          visibility: visibility,
          location: "#{def_line}:#{def_column}"
        )
        TokenParseResult.success(node, tokens, position)
      end

      def parse_visibility_method(tokens, position)
        visibility = tokens[position].type
        position += 1

        if position < tokens.length && tokens[position].type == :def
          parse_method_def(tokens, position, visibility: visibility)
        else
          TokenParseResult.failure("Expected 'def' after visibility modifier", tokens, position)
        end
      end

      def parse_parameter(tokens, position)
        return TokenParseResult.failure("Expected parameter", tokens, position) if position >= tokens.length

        # Check for different parameter types
        case tokens[position].type
        when :lbrace
          # Keyword args group: { name: Type, age: Type = default }
          return parse_keyword_args_group(tokens, position)

        when :star
          # Splat parameter *args
          position += 1
          return TokenParseResult.failure("Expected parameter name after *", tokens, position) if position >= tokens.length

          name = tokens[position].value
          position += 1

          # Check for type annotation: *args: Type
          type_annotation = nil
          if position < tokens.length && tokens[position].type == :colon
            position += 1
            type_result = parse_type(tokens, position)
            return type_result if type_result.failure?

            type_annotation = type_result.value
            position = type_result.position
          end

          param = IR::Parameter.new(name: name, kind: :rest, type_annotation: type_annotation)
          return TokenParseResult.success(param, tokens, position)

        when :star_star
          # Double splat **opts or **opts: Type
          position += 1
          return TokenParseResult.failure("Expected parameter name after **", tokens, position) if position >= tokens.length

          name = tokens[position].value
          position += 1

          # Check for type annotation: **opts: Type
          type_annotation = nil
          if position < tokens.length && tokens[position].type == :colon
            position += 1
            type_result = parse_type(tokens, position)
            return type_result if type_result.failure?

            type_annotation = type_result.value
            position = type_result.position
          end

          param = IR::Parameter.new(name: name, kind: :keyrest, type_annotation: type_annotation)
          return TokenParseResult.success(param, tokens, position)

        when :amp
          # Block parameter &block or &block: Type
          position += 1
          return TokenParseResult.failure("Expected parameter name after &", tokens, position) if position >= tokens.length

          name = tokens[position].value
          position += 1

          # Check for type annotation: &block: Type
          type_annotation = nil
          if position < tokens.length && tokens[position].type == :colon
            position += 1
            type_result = parse_type(tokens, position)
            return type_result if type_result.failure?

            type_annotation = type_result.value
            position = type_result.position
          end

          param = IR::Parameter.new(name: name, kind: :block, type_annotation: type_annotation)
          return TokenParseResult.success(param, tokens, position)
        end

        # Regular parameter: name or name: Type or name: Type = default
        name = tokens[position].value
        position += 1

        type_annotation = nil
        default_value = nil

        if position < tokens.length && tokens[position].type == :colon
          position += 1

          # Check if next token is a type (constant/identifier) or a default value
          if position < tokens.length
            type_result = parse_type(tokens, position)
            return type_result if type_result.failure?

            type_annotation = type_result.value
            position = type_result.position
          end
        end

        # Check for default value: = expression
        if position < tokens.length && tokens[position].type == :eq
          position += 1
          # Skip the default value expression (parse until comma, rparen, or newline)
          position = skip_default_value(tokens, position)
          default_value = true # Just mark that there's a default value
        end

        kind = default_value ? :optional : :required
        param = IR::Parameter.new(name: name, type_annotation: type_annotation, default_value: default_value, kind: kind)
        TokenParseResult.success(param, tokens, position)
      end

      # Parse keyword args group: { name: Type, age: Type = default } or { name:, age: default }: InterfaceName
      def parse_keyword_args_group(tokens, position)
        position += 1 # consume '{'

        params = []
        while position < tokens.length && tokens[position].type != :rbrace
          # Skip newlines inside braces
          position = skip_newlines(tokens, position)
          break if position >= tokens.length || tokens[position].type == :rbrace

          # Parse each keyword arg: name: Type or name: Type = default or name: or name: default
          return TokenParseResult.failure("Expected parameter name", tokens, position) unless tokens[position].type == :identifier

          name = tokens[position].value
          position += 1

          type_annotation = nil
          default_value = nil

          if position < tokens.length && tokens[position].type == :colon
            position += 1

            # Check what follows the colon
            if position < tokens.length
              next_token = tokens[position]

              # If it's a type (constant), parse the type
              if next_token.type == :constant
                type_result = parse_type(tokens, position)
                unless type_result.failure?
                  type_annotation = type_result.value
                  position = type_result.position
                end
              elsif next_token.type != :comma && next_token.type != :rbrace && next_token.type != :newline
                # Ruby-style default value (without =): name: default_value
                # e.g., { name:, limit: 10 }: InterfaceName
                position = skip_default_value_in_braces(tokens, position)
                default_value = true
              end
              # If next_token is comma/rbrace/newline, it's shorthand `name:` with no type or default
            end
          end

          # Check for default value: = expression (T-Ruby style with equals sign)
          if position < tokens.length && tokens[position].type == :eq
            position += 1
            position = skip_default_value_in_braces(tokens, position)
            default_value = true
          end

          params << IR::Parameter.new(name: name, type_annotation: type_annotation, default_value: default_value, kind: :keyword)

          # Skip comma
          if position < tokens.length && tokens[position].type == :comma
            position += 1
          end

          position = skip_newlines(tokens, position)
        end

        return TokenParseResult.failure("Expected '}'", tokens, position) unless position < tokens.length && tokens[position].type == :rbrace

        position += 1 # consume '}'

        # Check for interface type annotation: { ... }: InterfaceName
        interface_type = nil
        if position < tokens.length && tokens[position].type == :colon
          position += 1
          type_result = parse_type(tokens, position)
          unless type_result.failure?
            interface_type = type_result.value
            position = type_result.position
          end
        end

        # If there's an interface type, set it as interface_ref for each param
        if interface_type
          params.each { |p| p.interface_ref = interface_type }
        end

        # Return the array of keyword params wrapped in a result
        # We'll handle this specially in parse_method_def
        TokenParseResult.success(params, tokens, position)
      end

      # Skip a default value expression (until comma, rparen, or newline)
      def skip_default_value(tokens, position)
        depth = 0
        while position < tokens.length
          token = tokens[position]
          case token.type
          when :lparen, :lbracket, :lbrace
            depth += 1
          when :rparen
            return position if depth.zero?

            depth -= 1
          when :rbracket, :rbrace
            depth -= 1
          when :comma
            return position if depth.zero?
          when :newline
            return position if depth.zero?
          end
          position += 1
        end
        position
      end

      # Skip a default value expression inside braces (until comma, rbrace, or newline)
      def skip_default_value_in_braces(tokens, position)
        depth = 0
        while position < tokens.length
          token = tokens[position]
          case token.type
          when :lparen, :lbracket
            depth += 1
          when :rparen, :rbracket
            depth -= 1
          when :lbrace
            depth += 1
          when :rbrace
            return position if depth.zero?

            depth -= 1
          when :comma
            return position if depth.zero?
          when :newline
            return position if depth.zero?
          end
          position += 1
        end
        position
      end

      def parse_class(tokens, position)
        position += 1 # consume 'class'

        # Parse class name
        return TokenParseResult.failure("Expected class name", tokens, position) if position >= tokens.length

        class_name = tokens[position].value
        position += 1

        # Check for superclass
        superclass = nil
        if position < tokens.length && tokens[position].type == :lt
          position += 1
          superclass = tokens[position].value
          position += 1
        end

        position = skip_newlines(tokens, position)

        # Parse class body (methods and instance variables)
        body = []
        instance_vars = []

        loop do
          position = skip_newlines(tokens, position)
          break if position >= tokens.length
          break if tokens[position].type == :end

          if tokens[position].type == :ivar && tokens[position + 1]&.type == :colon
            # Instance variable declaration: @name: Type
            ivar_result = parse_instance_var_decl(tokens, position)
            return ivar_result if ivar_result.failure?

            instance_vars << ivar_result.value
            position = ivar_result.position
          elsif %i[def public private protected].include?(tokens[position].type)
            method_result = parse_declaration(tokens, position)
            return method_result if method_result.failure?

            body << method_result.value
            position = method_result.position
          else
            break
          end
        end

        # Expect 'end'
        if position < tokens.length && tokens[position].type == :end
          position += 1
        end

        node = IR::ClassDecl.new(
          name: class_name,
          superclass: superclass,
          body: body,
          instance_vars: instance_vars
        )
        TokenParseResult.success(node, tokens, position)
      end

      def parse_instance_var_decl(tokens, position)
        # @name: Type
        name = tokens[position].value[1..] # remove @ prefix
        position += 2 # skip @name and :

        type_result = parse_type(tokens, position)
        return type_result if type_result.failure?

        node = IR::InstanceVariable.new(name: name, type_annotation: type_result.value)
        TokenParseResult.success(node, tokens, type_result.position)
      end

      def parse_module(tokens, position)
        position += 1 # consume 'module'

        # Parse module name
        return TokenParseResult.failure("Expected module name", tokens, position) if position >= tokens.length

        module_name = tokens[position].value
        position += 1

        position = skip_newlines(tokens, position)

        # Parse module body
        body = []

        loop do
          position = skip_newlines(tokens, position)
          break if position >= tokens.length
          break if tokens[position].type == :end

          break unless %i[def public private protected].include?(tokens[position].type)

          method_result = parse_declaration(tokens, position)
          return method_result if method_result.failure?

          body << method_result.value
          position = method_result.position
        end

        # Expect 'end'
        if position < tokens.length && tokens[position].type == :end
          position += 1
        end

        node = IR::ModuleDecl.new(name: module_name, body: body)
        TokenParseResult.success(node, tokens, position)
      end

      def parse_type_alias(tokens, position)
        position += 1 # consume 'type'

        # Parse type name
        return TokenParseResult.failure("Expected type name", tokens, position) if position >= tokens.length

        type_name = tokens[position].value
        position += 1

        # Expect '='
        return TokenParseResult.failure("Expected '='", tokens, position) unless tokens[position]&.type == :eq

        position += 1

        # Parse type definition
        type_result = parse_type(tokens, position)
        return type_result if type_result.failure?

        node = IR::TypeAlias.new(name: type_name, definition: type_result.value)
        TokenParseResult.success(node, tokens, type_result.position)
      end

      def parse_interface(tokens, position)
        position += 1 # consume 'interface'

        # Parse interface name
        return TokenParseResult.failure("Expected interface name", tokens, position) if position >= tokens.length

        interface_name = tokens[position].value
        position += 1

        position = skip_newlines(tokens, position)

        # Parse interface members
        members = []

        loop do
          position = skip_newlines(tokens, position)
          break if position >= tokens.length
          break if tokens[position].type == :end

          member_result = parse_interface_member(tokens, position)
          break if member_result.failure?

          members << member_result.value
          position = member_result.position
        end

        # Expect 'end'
        if position < tokens.length && tokens[position].type == :end
          position += 1
        end

        node = IR::Interface.new(name: interface_name, members: members)
        TokenParseResult.success(node, tokens, position)
      end

      def parse_interface_member(tokens, position)
        # name: Type
        return TokenParseResult.failure("Expected member name", tokens, position) if position >= tokens.length

        name = tokens[position].value
        position += 1

        return TokenParseResult.failure("Expected ':'", tokens, position) unless tokens[position]&.type == :colon

        position += 1

        type_result = parse_type(tokens, position)
        return type_result if type_result.failure?

        node = IR::InterfaceMember.new(name: name, type_signature: type_result.value)
        TokenParseResult.success(node, tokens, type_result.position)
      end

      def parse_type(tokens, position)
        return TokenParseResult.failure("Expected type", tokens, position) if position >= tokens.length

        # Parse primary type
        result = parse_primary_type(tokens, position)
        return result if result.failure?

        type = result.value
        position = result.position

        # Check for union type
        types = [type]
        while position < tokens.length && tokens[position].type == :pipe
          position += 1
          next_result = parse_primary_type(tokens, position)
          return next_result if next_result.failure?

          types << next_result.value
          position = next_result.position
        end

        if types.length > 1
          node = IR::UnionType.new(types: types)
          TokenParseResult.success(node, tokens, position)
        else
          TokenParseResult.success(type, tokens, position)
        end
      end

      def parse_primary_type(tokens, position)
        return TokenParseResult.failure("Expected type", tokens, position) if position >= tokens.length

        # Check for function type: -> ReturnType
        if tokens[position].type == :arrow
          position += 1
          return_result = parse_primary_type(tokens, position)
          return return_result if return_result.failure?

          node = IR::FunctionType.new(param_types: [], return_type: return_result.value)
          return TokenParseResult.success(node, tokens, return_result.position)
        end

        # Check for tuple type: (Type, Type) -> ReturnType
        if tokens[position].type == :lparen
          position += 1
          param_types = []

          unless tokens[position].type == :rparen
            loop do
              type_result = parse_type(tokens, position)
              return type_result if type_result.failure?

              param_types << type_result.value
              position = type_result.position

              break unless tokens[position]&.type == :comma

              position += 1
            end
          end

          return TokenParseResult.failure("Expected ')'", tokens, position) unless tokens[position]&.type == :rparen

          position += 1

          # Check for function arrow
          if position < tokens.length && tokens[position].type == :arrow
            position += 1
            return_result = parse_primary_type(tokens, position)
            return return_result if return_result.failure?

            node = IR::FunctionType.new(param_types: param_types, return_type: return_result.value)
            return TokenParseResult.success(node, tokens, return_result.position)
          else
            node = IR::TupleType.new(element_types: param_types)
            return TokenParseResult.success(node, tokens, position)
          end
        end

        # Check for hash literal type: { key: Type, key2: Type }
        if tokens[position].type == :lbrace
          return parse_hash_literal_type(tokens, position)
        end

        # Simple type or generic type
        type_name = tokens[position].value
        position += 1

        # Check for generic arguments: Type<Args>
        if position < tokens.length && tokens[position].type == :lt
          position += 1
          type_args = []

          loop do
            arg_result = parse_type(tokens, position)
            return arg_result if arg_result.failure?

            type_args << arg_result.value
            position = arg_result.position

            break unless tokens[position]&.type == :comma

            position += 1
          end

          return TokenParseResult.failure("Expected '>'", tokens, position) unless tokens[position]&.type == :gt

          position += 1

          node = IR::GenericType.new(base: type_name, type_args: type_args)
          TokenParseResult.success(node, tokens, position)
        elsif position < tokens.length && tokens[position].type == :question
          # Check for nullable: Type?
          position += 1
          inner = IR::SimpleType.new(name: type_name)
          node = IR::NullableType.new(inner_type: inner)
          TokenParseResult.success(node, tokens, position)
        else
          node = IR::SimpleType.new(name: type_name)
          TokenParseResult.success(node, tokens, position)
        end
      end

      # Parse hash literal type: { key: Type, key2: Type }
      # Used for typed hash parameters like: def foo(config: { host: String, port: Integer })
      def parse_hash_literal_type(tokens, position)
        return TokenParseResult.failure("Expected '{'", tokens, position) unless tokens[position]&.type == :lbrace

        position += 1 # consume '{'

        fields = []
        while position < tokens.length && tokens[position].type != :rbrace
          # Skip newlines inside braces
          position = skip_newlines(tokens, position)
          break if position >= tokens.length || tokens[position].type == :rbrace

          # Parse field: name: Type
          unless tokens[position].type == :identifier
            return TokenParseResult.failure("Expected field name", tokens, position)
          end

          field_name = tokens[position].value
          position += 1

          unless tokens[position]&.type == :colon
            return TokenParseResult.failure("Expected ':' after field name", tokens, position)
          end

          position += 1

          type_result = parse_type(tokens, position)
          return type_result if type_result.failure?

          fields << { name: field_name, type: type_result.value }
          position = type_result.position

          # Handle optional default value (skip it for type purposes)
          if position < tokens.length && tokens[position].type == :eq
            position += 1
            position = skip_default_value_in_braces(tokens, position)
          end

          # Skip comma if present
          if position < tokens.length && tokens[position].type == :comma
            position += 1
          end
        end

        unless tokens[position]&.type == :rbrace
          return TokenParseResult.failure("Expected '}'", tokens, position)
        end

        position += 1 # consume '}'

        node = IR::HashLiteralType.new(fields: fields)
        TokenParseResult.success(node, tokens, position)
      end
    end
  end
end
