# frozen_string_literal: true

module TRuby
  module ParserCombinator
    # Declaration Parser - Parse T-Ruby declarations
    class DeclarationParser
      include DSL

      def initialize
        @type_parser = TypeParser.new
        build_parsers
      end

      def parse(input)
        result = @declaration.parse(input.strip)
        if result.success?
          { success: true, declarations: result.value }
        else
          { success: false, error: result.error, position: result.position }
        end
      end

      def parse_file(input)
        result = @program.parse(input)
        if result.success?
          { success: true, declarations: result.value.compact }
        else
          { success: false, error: result.error, position: result.position }
        end
      end

      private

      def build_parsers
        # Type expression (delegate to TypeParser)
        lazy { parse_type_inline }

        # Keywords
        kw_type = lexeme(string("type"))
        kw_interface = lexeme(string("interface"))
        kw_def = lexeme(string("def"))
        kw_end = lexeme(string("end"))
        lexeme(string("class"))
        lexeme(string("module"))

        # Type alias: type Name = Definition
        type_alias = (
          kw_type >>
          lexeme(identifier) <<
          lexeme(char("=")) >>
          regex(/[^\n]+/).map(&:strip)
        ).map do |((_, name), definition)|
          type_result = @type_parser.parse(definition)
          if type_result[:success]
            IR::TypeAlias.new(name: name, definition: type_result[:type])
          end
        end

        # Interface member: name: Type
        interface_member = (
          lexeme(identifier) <<
          lexeme(char(":")) >>
          regex(/[^\n]+/).map(&:strip)
        ).map do |(name, type_str)|
          type_result = @type_parser.parse(type_str)
          if type_result[:success]
            IR::InterfaceMember.new(name: name, type_signature: type_result[:type])
          end
        end

        # Interface: interface Name ... end
        interface_body = (interface_member << (newline | spaces)).many

        interface_decl = (
          kw_interface >>
          lexeme(identifier) <<
          (newline | spaces) >>
          interface_body <<
          kw_end
        ).map do |((_, name), members)|
          IR::Interface.new(name: name, members: members.compact)
        end

        # Parameter: name: Type or name
        param = (
          identifier >>
          (lexeme(char(":")) >> regex(/[^,)]+/).map(&:strip)).optional
        ).map do |(name, type_str)|
          type_node = if type_str
                        type_str_val = type_str.is_a?(Array) ? type_str.last : type_str
                        result = @type_parser.parse(type_str_val)
                        result[:success] ? result[:type] : nil
                      end
          IR::Parameter.new(name: name, type_annotation: type_node)
        end

        # Parameters list
        params_list = (
          lexeme(char("(")) >>
          param.sep_by(lexeme(char(","))) <<
          lexeme(char(")"))
        ).map { |(_, params)| params }

        # Return type annotation
        return_type = (
          lexeme(char(":")) >>
          regex(/[^\n]+/).map(&:strip)
        ).map { |(_, type_str)| type_str }.optional

        # Method definition: def name(params): ReturnType
        method_def = (
          kw_def >>
          identifier >>
          params_list.optional >>
          return_type
        ).map do |(((_, name), params), ret_str)|
          ret_type = if ret_str
                       result = @type_parser.parse(ret_str)
                       result[:success] ? result[:type] : nil
                     end
          IR::MethodDef.new(
            name: name,
            params: params || [],
            return_type: ret_type
          )
        end

        # Any declaration
        @declaration = choice(
          type_alias,
          interface_decl,
          method_def
        )

        # Line (declaration or empty)
        line = (@declaration << (newline | eof)) | (spaces >> newline).map { nil }

        # Program (multiple declarations)
        @program = line.many
      end

      def parse_type_inline
        Lazy.new { @type_parser.instance_variable_get(:@type_expr) }
      end
    end
  end
end
