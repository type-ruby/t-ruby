# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Token Declaration Parser - Parse top-level declarations
    class TokenDeclarationParser
      include TokenDSL

      def initialize
        @statement_parser = StatementParser.new
        @expression_parser = ExpressionParser.new
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

        loop do
          position = skip_newlines(tokens, position)
          break if position >= tokens.length
          break if tokens[position].type == :eof

          result = parse_declaration(tokens, position)
          break if result.failure?

          declarations << result.value
          position = result.position
        end

        program = IR::Program.new(declarations: declarations)
        TokenParseResult.success(program, tokens, position)
      end

      private

      def skip_newlines(tokens, position)
        while position < tokens.length && [:newline, :comment].include?(tokens[position].type)
          position += 1
        end
        position
      end

      def parse_method_def(tokens, position, visibility: :public)
        position += 1 # consume 'def'

        # Parse method name (identifier or operator)
        return TokenParseResult.failure("Expected method name", tokens, position) if position >= tokens.length

        method_name = tokens[position].value
        position += 1

        # Parse parameters
        params = []
        if position < tokens.length && tokens[position].type == :lparen
          position += 1 # consume (

          # Parse parameter list
          unless tokens[position].type == :rparen
            loop do
              param_result = parse_parameter(tokens, position)
              return param_result if param_result.failure?
              params << param_result.value
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
          position += 1
          type_result = parse_type(tokens, position)
          return type_result if type_result.failure?
          return_type = type_result.value
          position = type_result.position
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
          visibility: visibility
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
        when :star
          # Splat parameter *args
          position += 1
          name = tokens[position].value
          position += 1
          param = IR::Parameter.new(name: name, kind: :rest)
          return TokenParseResult.success(param, tokens, position)

        when :star_star
          # Double splat **opts
          position += 1
          name = tokens[position].value
          position += 1
          param = IR::Parameter.new(name: name, kind: :keyrest)
          return TokenParseResult.success(param, tokens, position)

        when :amp
          # Block parameter &block
          position += 1
          name = tokens[position].value
          position += 1
          param = IR::Parameter.new(name: name, kind: :block)
          return TokenParseResult.success(param, tokens, position)
        end

        # Regular parameter: name or name: Type
        name = tokens[position].value
        position += 1

        type_annotation = nil
        if position < tokens.length && tokens[position].type == :colon
          position += 1
          type_result = parse_type(tokens, position)
          return type_result if type_result.failure?
          type_annotation = type_result.value
          position = type_result.position
        end

        param = IR::Parameter.new(name: name, type_annotation: type_annotation)
        TokenParseResult.success(param, tokens, position)
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
          elsif [:def, :public, :private, :protected].include?(tokens[position].type)
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

          if [:def, :public, :private, :protected].include?(tokens[position].type)
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
        else
          # Check for nullable: Type?
          if position < tokens.length && tokens[position].type == :question
            position += 1
            inner = IR::SimpleType.new(name: type_name)
            node = IR::NullableType.new(inner_type: inner)
            TokenParseResult.success(node, tokens, position)
          else
            node = IR::SimpleType.new(name: type_name)
            TokenParseResult.success(node, tokens, position)
          end
        end
      end
    end
  end
end
