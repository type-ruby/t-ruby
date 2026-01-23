# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Type Parser - Parse T-Ruby type expressions
    class TypeParser
      include DSL

      def initialize
        build_parsers
      end

      def parse(input)
        result = @type_expr.parse(input.strip)
        if result.success?
          { success: true, type: result.value, remaining: input[result.position..] }
        else
          { success: false, error: result.error, position: result.position }
        end
      end

      private

      def build_parsers
        # Identifier (type name)
        type_name = identifier.label("type name")

        # Simple type
        type_name.map { |name| IR::SimpleType.new(name: name) }

        # Lazy reference for recursive types
        type_expr = lazy { @type_expr }

        # Generic type arguments: <Type, Type, ...>
        generic_args = (
          lexeme(char("<")) >>
          type_expr.sep_by1(lexeme(char(","))) <<
          lexeme(char(">"))
        ).map { |(_, types)| types }

        # Generic type: Base<Args>
        generic_type = (type_name >> generic_args.optional).map do |(name, args)|
          if args && !args.empty?
            IR::GenericType.new(base: name, type_args: args)
          else
            IR::SimpleType.new(name: name)
          end
        end

        # Nullable type: Type?
        nullable_suffix = char("?")

        # Parenthesized type
        paren_type = (lexeme(char("(")) >> type_expr << lexeme(char(")"))).map { |(_, t)| t }

        # Function type: (Params) -> ReturnType
        param_list = (
          lexeme(char("(")) >>
          type_expr.sep_by(lexeme(char(","))) <<
          lexeme(char(")"))
        ).map { |(_, params)| params }

        arrow = lexeme(string("->"))

        function_type = (param_list >> arrow >> type_expr).map do |((params, _arrow), ret)|
          IR::FunctionType.new(param_types: params, return_type: ret)
        end

        # Proc type: Proc(Params) -> ReturnType (Ruby-familiar syntax)
        proc_keyword = lexeme(string("Proc"))
        proc_type = (proc_keyword >> param_list >> arrow >> type_expr).map do |((_proc, params), _arrow), ret|
          IR::FunctionType.new(param_types: params, return_type: ret, callable_kind: :proc)
        end

        # Lambda type: Lambda(Params) -> ReturnType
        lambda_keyword = lexeme(string("Lambda"))
        lambda_type = (lambda_keyword >> param_list >> arrow >> type_expr).map do |((_lambda, params), _arrow), ret|
          IR::FunctionType.new(param_types: params, return_type: ret, callable_kind: :lambda)
        end

        # Tuple type: [Type, Type, ...] or [Type, *Type[]]
        # Note: Uses lazy reference to @tuple_element which is defined after base_type
        tuple_type = (
          lexeme(char("[")) >>
          lazy { @tuple_element }.sep_by1(lexeme(char(","))) <<
          lexeme(char("]"))
        ).map do |(_, types)|
          tuple = IR::TupleType.new(element_types: types)
          tuple.validate! # Validates rest element position
          tuple
        end

        # Primary type (before operators)
        primary_type = choice(
          proc_type,
          lambda_type,
          function_type,
          tuple_type,
          paren_type,
          generic_type
        )

        # Array shorthand suffix: [] (can be repeated for nested arrays)
        array_suffix = string("[]")

        # Postfix operators: ([] | ?)*
        # Handles: String[], Integer[][], String[]?, String?[], etc.
        postfix_op = array_suffix | nullable_suffix

        base_type = (primary_type >> postfix_op.many).map do |(initial_type, ops)|
          ops.reduce(initial_type) do |type, op|
            case op
            when "[]"
              IR::GenericType.new(base: "Array", type_args: [type])
            when "?"
              IR::NullableType.new(inner_type: type)
            else
              type
            end
          end
        end

        # Rest element for tuple: *Type[] or *Array<Type>
        # Defined after base_type so it can reference it
        rest_element = (lexeme(char("*")) >> base_type).map do |(_, inner)|
          IR::TupleRestElement.new(inner_type: inner)
        end

        # Tuple element: Type or *Type (rest element)
        @tuple_element = rest_element | type_expr

        # Union type: Type | Type | ...
        union_op = lexeme(char("|"))
        union_type = base_type.sep_by1(union_op).map do |types|
          types.length == 1 ? types.first : IR::UnionType.new(types: types)
        end

        # Intersection type: Type & Type & ...
        intersection_op = lexeme(char("&"))
        @type_expr = union_type.sep_by1(intersection_op).map do |types|
          types.length == 1 ? types.first : IR::IntersectionType.new(types: types)
        end
      end
    end
  end
end
