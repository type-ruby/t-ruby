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

        # Tuple type: [Type, Type, ...]
        tuple_type = (
          lexeme(char("[")) >>
          type_expr.sep_by1(lexeme(char(","))) <<
          lexeme(char("]"))
        ).map { |(_, types)| IR::TupleType.new(element_types: types) }

        # Primary type (before operators)
        primary_type = choice(
          function_type,
          tuple_type,
          paren_type,
          generic_type
        )

        # With optional nullable suffix
        base_type = (primary_type >> nullable_suffix.optional).map do |(type, nullable)|
          nullable ? IR::NullableType.new(inner_type: type) : type
        end

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
