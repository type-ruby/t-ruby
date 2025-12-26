# frozen_string_literal: true

module TRuby
  module IR
    # Base class for all IR nodes
    class Node
      attr_accessor :location, :type_info, :metadata

      def initialize(location: nil)
        @location = location
        @type_info = nil
        @metadata = {}
      end

      def accept(visitor)
        visitor.visit(self)
      end

      def children
        []
      end

      def transform(&block)
        block.call(self)
      end
    end

    # Program - root node containing all top-level declarations
    class Program < Node
      attr_accessor :declarations, :source_file

      def initialize(declarations: [], source_file: nil, **opts)
        super(**opts)
        @declarations = declarations
        @source_file = source_file
      end

      def children
        @declarations
      end
    end

    # Type alias declaration: type Name = Definition
    class TypeAlias < Node
      attr_accessor :name, :definition, :type_params

      def initialize(name:, definition:, type_params: [], **opts)
        super(**opts)
        @name = name
        @definition = definition
        @type_params = type_params
      end
    end

    # Interface declaration
    class Interface < Node
      attr_accessor :name, :members, :extends, :type_params

      def initialize(name:, members: [], extends: [], type_params: [], **opts)
        super(**opts)
        @name = name
        @members = members
        @extends = extends
        @type_params = type_params
      end

      def children
        @members
      end
    end

    # Interface member (method signature)
    class InterfaceMember < Node
      attr_accessor :name, :type_signature, :optional

      def initialize(name:, type_signature:, optional: false, **opts)
        super(**opts)
        @name = name
        @type_signature = type_signature
        @optional = optional
      end
    end

    # Class declaration
    class ClassDecl < Node
      attr_accessor :name, :superclass, :implements, :type_params, :body, :instance_vars

      def initialize(name:, superclass: nil, implements: [], type_params: [], body: [], instance_vars: [], **opts)
        super(**opts)
        @name = name
        @superclass = superclass
        @implements = implements
        @type_params = type_params
        @body = body
        @instance_vars = instance_vars
      end

      def children
        @body
      end
    end

    # Instance variable declaration
    class InstanceVariable < Node
      attr_accessor :name, :type_annotation

      def initialize(name:, type_annotation: nil, **opts)
        super(**opts)
        @name = name
        @type_annotation = type_annotation
      end
    end

    # Module declaration
    class ModuleDecl < Node
      attr_accessor :name, :body

      def initialize(name:, body: [], **opts)
        super(**opts)
        @name = name
        @body = body
      end

      def children
        @body
      end
    end

    # Method definition
    class MethodDef < Node
      attr_accessor :name, :params, :return_type, :body, :visibility, :type_params

      def initialize(name:, params: [], return_type: nil, body: nil, visibility: :public, type_params: [], **opts)
        super(**opts)
        @name = name
        @params = params
        @return_type = return_type
        @body = body
        @visibility = visibility
        @type_params = type_params
      end

      def children
        [@body].compact
      end
    end

    # Method parameter
    class Parameter < Node
      attr_accessor :name, :type_annotation, :default_value, :kind

      # kind: :required, :optional, :rest, :keyrest, :block
      def initialize(name:, type_annotation: nil, default_value: nil, kind: :required, **opts)
        super(**opts)
        @name = name
        @type_annotation = type_annotation
        @default_value = default_value
        @kind = kind
      end
    end

    # Block of statements
    class Block < Node
      attr_accessor :statements

      def initialize(statements: [], **opts)
        super(**opts)
        @statements = statements
      end

      def children
        @statements
      end
    end

    # Variable assignment
    class Assignment < Node
      attr_accessor :target, :value, :type_annotation

      def initialize(target:, value:, type_annotation: nil, **opts)
        super(**opts)
        @target = target
        @value = value
        @type_annotation = type_annotation
      end

      def children
        [@value]
      end
    end

    # Variable reference
    class VariableRef < Node
      attr_accessor :name, :scope

      # scope: :local, :instance, :class, :global
      def initialize(name:, scope: :local, **opts)
        super(**opts)
        @name = name
        @scope = scope
      end
    end

    # Method call
    class MethodCall < Node
      attr_accessor :receiver, :method_name, :arguments, :block, :type_args

      def initialize(method_name:, receiver: nil, arguments: [], block: nil, type_args: [], **opts)
        super(**opts)
        @receiver = receiver
        @method_name = method_name
        @arguments = arguments
        @block = block
        @type_args = type_args
      end

      def children
        ([@receiver, @block] + @arguments).compact
      end
    end

    # Literal values
    class Literal < Node
      attr_accessor :value, :literal_type

      def initialize(value:, literal_type:, **opts)
        super(**opts)
        @value = value
        @literal_type = literal_type
      end
    end

    # Array literal
    class ArrayLiteral < Node
      attr_accessor :elements, :element_type

      def initialize(elements: [], element_type: nil, **opts)
        super(**opts)
        @elements = elements
        @element_type = element_type
      end

      def children
        @elements
      end
    end

    # Hash literal
    class HashLiteral < Node
      attr_accessor :pairs, :key_type, :value_type

      def initialize(pairs: [], key_type: nil, value_type: nil, **opts)
        super(**opts)
        @pairs = pairs
        @key_type = key_type
        @value_type = value_type
      end
    end

    # Hash pair (key => value)
    class HashPair < Node
      attr_accessor :key, :value

      def initialize(key:, value:, **opts)
        super(**opts)
        @key = key
        @value = value
      end

      def children
        [@key, @value]
      end
    end

    # Conditional (if/unless)
    class Conditional < Node
      attr_accessor :condition, :then_branch, :else_branch, :kind

      # kind: :if, :unless, :ternary
      def initialize(condition:, then_branch:, else_branch: nil, kind: :if, **opts)
        super(**opts)
        @condition = condition
        @then_branch = then_branch
        @else_branch = else_branch
        @kind = kind
      end

      def children
        [@condition, @then_branch, @else_branch].compact
      end
    end

    # Case/when expression
    class CaseExpr < Node
      attr_accessor :subject, :when_clauses, :else_clause

      def initialize(subject: nil, when_clauses: [], else_clause: nil, **opts)
        super(**opts)
        @subject = subject
        @when_clauses = when_clauses
        @else_clause = else_clause
      end

      def children
        ([@subject, @else_clause] + @when_clauses).compact
      end
    end

    # When clause
    class WhenClause < Node
      attr_accessor :patterns, :body

      def initialize(patterns:, body:, **opts)
        super(**opts)
        @patterns = patterns
        @body = body
      end

      def children
        [@body] + @patterns
      end
    end

    # Loop constructs
    class Loop < Node
      attr_accessor :kind, :condition, :body

      # kind: :while, :until, :loop
      def initialize(kind:, body:, condition: nil, **opts)
        super(**opts)
        @kind = kind
        @condition = condition
        @body = body
      end

      def children
        [@condition, @body].compact
      end
    end

    # For loop / each iteration
    class ForLoop < Node
      attr_accessor :variable, :iterable, :body

      def initialize(variable:, iterable:, body:, **opts)
        super(**opts)
        @variable = variable
        @iterable = iterable
        @body = body
      end

      def children
        [@iterable, @body]
      end
    end

    # Return statement
    class Return < Node
      attr_accessor :value

      def initialize(value: nil, **opts)
        super(**opts)
        @value = value
      end

      def children
        [@value].compact
      end
    end

    # Binary operation
    class BinaryOp < Node
      attr_accessor :operator, :left, :right

      def initialize(operator:, left:, right:, **opts)
        super(**opts)
        @operator = operator
        @left = left
        @right = right
      end

      def children
        [@left, @right]
      end
    end

    # Unary operation
    class UnaryOp < Node
      attr_accessor :operator, :operand

      def initialize(operator:, operand:, **opts)
        super(**opts)
        @operator = operator
        @operand = operand
      end

      def children
        [@operand]
      end
    end

    # Type cast / assertion
    class TypeCast < Node
      attr_accessor :expression, :target_type, :kind

      # kind: :as, :assert
      def initialize(expression:, target_type:, kind: :as, **opts)
        super(**opts)
        @expression = expression
        @target_type = target_type
        @kind = kind
      end

      def children
        [@expression]
      end
    end

    # Type guard (is_a?, respond_to?)
    class TypeGuard < Node
      attr_accessor :expression, :type_check, :narrowed_type

      def initialize(expression:, type_check:, narrowed_type: nil, **opts)
        super(**opts)
        @expression = expression
        @type_check = type_check
        @narrowed_type = narrowed_type
      end

      def children
        [@expression]
      end
    end

    # Lambda/Proc definition
    class Lambda < Node
      attr_accessor :params, :body, :return_type

      def initialize(body:, params: [], return_type: nil, **opts)
        super(**opts)
        @params = params
        @body = body
        @return_type = return_type
      end

      def children
        [@body]
      end
    end

    # Begin/rescue/ensure block
    class BeginBlock < Node
      attr_accessor :body, :rescue_clauses, :else_clause, :ensure_clause

      def initialize(body:, rescue_clauses: [], else_clause: nil, ensure_clause: nil, **opts)
        super(**opts)
        @body = body
        @rescue_clauses = rescue_clauses
        @else_clause = else_clause
        @ensure_clause = ensure_clause
      end

      def children
        [@body, @else_clause, @ensure_clause].compact + @rescue_clauses
      end
    end

    # Rescue clause
    class RescueClause < Node
      attr_accessor :exception_types, :variable, :body

      def initialize(body:, exception_types: [], variable: nil, **opts)
        super(**opts)
        @exception_types = exception_types
        @variable = variable
        @body = body
      end

      def children
        [@body]
      end
    end

    # Raw Ruby code (for passthrough)
    class RawCode < Node
      attr_accessor :code

      def initialize(code:, **opts)
        super(**opts)
        @code = code
      end
    end

    #==========================================================================
    # Type Representation Nodes
    #==========================================================================

    # Base type node
    class TypeNode < Node
      def to_rbs
        raise NotImplementedError
      end

      def to_trb
        raise NotImplementedError
      end
    end

    # Simple type (String, Integer, etc.)
    class SimpleType < TypeNode
      attr_accessor :name

      def initialize(name:, **opts)
        super(**opts)
        @name = name
      end

      def to_rbs
        @name
      end

      def to_trb
        @name
      end
    end

    # Generic type (Array<String>, Map<K, V>)
    class GenericType < TypeNode
      attr_accessor :base, :type_args

      def initialize(base:, type_args: [], **opts)
        super(**opts)
        @base = base
        @type_args = type_args
      end

      def to_rbs
        "#{@base}[#{@type_args.map(&:to_rbs).join(", ")}]"
      end

      def to_trb
        "#{@base}<#{@type_args.map(&:to_trb).join(", ")}>"
      end
    end

    # Union type (String | Integer | nil)
    class UnionType < TypeNode
      attr_accessor :types

      def initialize(types: [], **opts)
        super(**opts)
        @types = types
      end

      def to_rbs
        @types.map(&:to_rbs).join(" | ")
      end

      def to_trb
        @types.map(&:to_trb).join(" | ")
      end
    end

    # Intersection type (Readable & Writable)
    class IntersectionType < TypeNode
      attr_accessor :types

      def initialize(types: [], **opts)
        super(**opts)
        @types = types
      end

      def to_rbs
        @types.map(&:to_rbs).join(" & ")
      end

      def to_trb
        @types.map(&:to_trb).join(" & ")
      end
    end

    # Function/Proc type ((String, Integer) -> Boolean)
    class FunctionType < TypeNode
      attr_accessor :param_types, :return_type

      def initialize(return_type:, param_types: [], **opts)
        super(**opts)
        @param_types = param_types
        @return_type = return_type
      end

      def to_rbs
        params = @param_types.map(&:to_rbs).join(", ")
        "^(#{params}) -> #{@return_type.to_rbs}"
      end

      def to_trb
        params = @param_types.map(&:to_trb).join(", ")
        "(#{params}) -> #{@return_type.to_trb}"
      end
    end

    # Tuple type ([String, Integer, Boolean])
    class TupleType < TypeNode
      attr_accessor :element_types

      def initialize(element_types: [], **opts)
        super(**opts)
        @element_types = element_types
      end

      def to_rbs
        "[#{@element_types.map(&:to_rbs).join(", ")}]"
      end

      def to_trb
        "[#{@element_types.map(&:to_trb).join(", ")}]"
      end
    end

    # Nullable type (String?)
    class NullableType < TypeNode
      attr_accessor :inner_type

      def initialize(inner_type:, **opts)
        super(**opts)
        @inner_type = inner_type
      end

      def to_rbs
        "#{@inner_type.to_rbs}?"
      end

      def to_trb
        "#{@inner_type.to_trb}?"
      end
    end

    # Literal type (literal value as type)
    class LiteralType < TypeNode
      attr_accessor :value

      def initialize(value:, **opts)
        super(**opts)
        @value = value
      end

      def to_rbs
        @value.inspect
      end

      def to_trb
        @value.inspect
      end
    end

    #==========================================================================
    # Visitor Pattern
    #==========================================================================

    class Visitor
      def visit(node)
        method_name = "visit_#{node.class.name.split("::").last.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, "")}"
        if respond_to?(method_name)
          send(method_name, node)
        else
          visit_default(node)
        end
      end

      def visit_default(node)
        node.children.each { |child| visit(child) }
      end

      def visit_children(node)
        node.children.each { |child| visit(child) }
      end
    end

    #==========================================================================
    # IR Builder - Converts parsed AST to IR
    #==========================================================================

    class Builder
      def initialize
        @type_registry = {}
      end

      # Build IR from parser output
      def build(parse_result, source: nil)
        # Build type aliases
        declarations = (parse_result[:type_aliases] || []).map do |alias_info|
          build_type_alias(alias_info)
        end

        # Build interfaces
        (parse_result[:interfaces] || []).each do |interface_info|
          declarations << build_interface(interface_info)
        end

        # Build classes
        (parse_result[:classes] || []).each do |class_info|
          declarations << build_class(class_info)
        end

        # Build functions/methods
        (parse_result[:functions] || []).each do |func_info|
          declarations << build_method(func_info)
        end

        Program.new(declarations: declarations, source_file: source)
      end

      # Build from source code
      def build_from_source(source)
        parser = Parser.new(source)
        result = parser.parse
        build(result, source: source)
      end

      private

      def build_type_alias(info)
        TypeAlias.new(
          name: info[:name],
          definition: parse_type(info[:definition])
        )
      end

      def build_interface(info)
        members = (info[:members] || []).map do |member|
          InterfaceMember.new(
            name: member[:name],
            type_signature: parse_type(member[:type])
          )
        end

        Interface.new(
          name: info[:name],
          members: members
        )
      end

      def build_class(info)
        # Build methods
        methods = (info[:methods] || []).map do |method_info|
          build_method(method_info)
        end

        # Build instance variables
        instance_vars = (info[:instance_vars] || []).map do |ivar|
          InstanceVariable.new(
            name: ivar[:name],
            type_annotation: ivar[:type] ? parse_type(ivar[:type]) : nil
          )
        end

        ClassDecl.new(
          name: info[:name],
          superclass: info[:superclass],
          body: methods,
          instance_vars: instance_vars
        )
      end

      def build_method(info)
        params = (info[:params] || []).map do |param|
          Parameter.new(
            name: param[:name],
            type_annotation: param[:type] ? parse_type(param[:type]) : nil
          )
        end

        # 본문 IR이 있으면 사용 (BodyParser에서 파싱됨)
        body = info[:body_ir]

        MethodDef.new(
          name: info[:name],
          params: params,
          return_type: info[:return_type] ? parse_type(info[:return_type]) : nil,
          body: body,
          visibility: info[:visibility] || :public
        )
      end

      def parse_type(type_str)
        return nil unless type_str

        type_str = type_str.strip

        # Union type
        if type_str.include?("|")
          types = type_str.split("|").map { |t| parse_type(t.strip) }
          return UnionType.new(types: types)
        end

        # Intersection type
        if type_str.include?("&")
          types = type_str.split("&").map { |t| parse_type(t.strip) }
          return IntersectionType.new(types: types)
        end

        # Nullable type
        if type_str.end_with?("?")
          inner = parse_type(type_str[0..-2])
          return NullableType.new(inner_type: inner)
        end

        # Generic type
        if type_str.include?("<") && type_str.include?(">")
          match = type_str.match(/^(\w+)<(.+)>$/)
          if match
            base = match[1]
            args = parse_generic_args(match[2])
            return GenericType.new(base: base, type_args: args)
          end
        end

        # Function type
        if type_str.include?("->")
          match = type_str.match(/^\((.*)?\)\s*->\s*(.+)$/)
          if match
            param_types = match[1] ? match[1].split(",").map { |t| parse_type(t.strip) } : []
            return_type = parse_type(match[2])
            return FunctionType.new(param_types: param_types, return_type: return_type)
          end
        end

        # Simple type
        SimpleType.new(name: type_str)
      end

      def parse_generic_args(args_str)
        args = []
        current = ""
        depth = 0

        args_str.each_char do |char|
          case char
          when "<"
            depth += 1
            current += char
          when ">"
            depth -= 1
            current += char
          when ","
            if depth.zero?
              args << parse_type(current.strip)
              current = ""
            else
              current += char
            end
          else
            current += char
          end
        end

        args << parse_type(current.strip) unless current.empty?
        args
      end
    end

    #==========================================================================
    # Code Generator - Converts IR to Ruby code
    #==========================================================================

    class CodeGenerator < Visitor
      attr_reader :output

      def initialize
        @output = []
        @indent = 0
      end

      def generate(program)
        @output = []
        visit(program)
        @output.join("\n")
      end

      def visit_program(node)
        node.declarations.each do |decl|
          visit(decl)
          @output << ""
        end
      end

      def visit_type_alias(node)
        # Type aliases are erased in Ruby output
        emit_comment("type #{node.name} = #{node.definition.to_trb}")
      end

      def visit_interface(node)
        # Interfaces are erased in Ruby output
        emit_comment("interface #{node.name}")
        node.members.each do |member|
          emit_comment("  #{member.name}: #{member.type_signature.to_trb}")
        end
        emit_comment("end")
      end

      def visit_method_def(node)
        params_str = node.params.map(&:name).join(", ")
        emit("def #{node.name}(#{params_str})")
        @indent += 1

        if node.body
          visit(node.body)
        end

        @indent -= 1
        emit("end")
      end

      def visit_block(node)
        node.statements.each { |stmt| visit(stmt) }
      end

      def visit_assignment(node)
        emit("#{node.target} = #{generate_expression(node.value)}")
      end

      def visit_return(node)
        if node.value
          emit("return #{generate_expression(node.value)}")
        else
          emit("return")
        end
      end

      def visit_conditional(node)
        keyword = node.kind == :unless ? "unless" : "if"
        emit("#{keyword} #{generate_expression(node.condition)}")
        @indent += 1
        visit(node.then_branch) if node.then_branch
        @indent -= 1

        if node.else_branch
          emit("else")
          @indent += 1
          visit(node.else_branch)
          @indent -= 1
        end

        emit("end")
      end

      def visit_raw_code(node)
        node.code.each_line do |line|
          emit(line.rstrip)
        end
      end

      private

      def emit(text)
        @output << (("  " * @indent) + text)
      end

      def emit_comment(text)
        emit("# #{text}")
      end

      def generate_expression(node)
        case node
        when Literal
          node.value.inspect
        when VariableRef
          node.name
        when MethodCall
          args = node.arguments.map { |a| generate_expression(a) }.join(", ")
          if node.receiver
            "#{generate_expression(node.receiver)}.#{node.method_name}(#{args})"
          else
            "#{node.method_name}(#{args})"
          end
        when BinaryOp
          "(#{generate_expression(node.left)} #{node.operator} #{generate_expression(node.right)})"
        when UnaryOp
          "#{node.operator}#{generate_expression(node.operand)}"
        else
          node.to_s
        end
      end
    end

    #==========================================================================
    # RBS Generator - Converts IR to RBS type definitions
    #==========================================================================

    class RBSGenerator < Visitor
      attr_reader :output

      def initialize(enable_inference: true)
        @output = []
        @indent = 0
        @enable_inference = enable_inference
        @inferrer = TRuby::ASTTypeInferrer.new if enable_inference
        @class_env = nil # 현재 클래스의 타입 환경
      end

      def generate(program)
        @output = []
        visit(program)
        @output.join("\n")
      end

      def visit_program(node)
        node.declarations.each do |decl|
          visit(decl)
          @output << ""
        end
      end

      def visit_type_alias(node)
        emit("type #{node.name} = #{node.definition.to_rbs}")
      end

      def visit_interface(node)
        emit("interface _#{node.name}")
        @indent += 1

        node.members.each do |member|
          visit(member)
        end

        @indent -= 1
        emit("end")
      end

      def visit_interface_member(node)
        emit("def #{node.name}: #{node.type_signature.to_rbs}")
      end

      def visit_method_def(node)
        params = node.params.map do |param|
          type = param.type_annotation&.to_rbs || "untyped"
          "#{param.name}: #{type}"
        end.join(", ")

        # 반환 타입: 명시적 타입 > 추론된 타입 > untyped
        return_type = node.return_type&.to_rbs

        # initialize 메서드는 특별 처리: 명시적 타입이 없으면 void
        # Ruby에서 initialize는 생성자이며, 실제 인스턴스 생성은 Class.new가 담당
        if node.name == "initialize" && return_type.nil?
          return_type = "void"
        elsif return_type.nil? && @enable_inference && @inferrer && node.body
          # 명시적 반환 타입이 없으면 추론 시도
          inferred = @inferrer.infer_method_return_type(node, @class_env)
          return_type = inferred if inferred && inferred != "untyped"
        end

        return_type ||= "untyped"
        visibility_prefix = format_visibility(node.visibility)
        emit("#{visibility_prefix}def #{node.name}: (#{params}) -> #{return_type}")
      end

      def visit_class_decl(node)
        emit("class #{node.name}")
        @indent += 1

        # 클래스 타입 환경 생성
        @class_env = TRuby::TypeEnv.new if @enable_inference

        # 인스턴스 변수 타입 등록
        (node.instance_vars || []).each do |ivar|
          if @class_env && ivar.type_annotation
            @class_env.define_instance_var("@#{ivar.name}", ivar.type_annotation.to_rbs)
          end

          # Emit instance variables first
          visit_instance_variable(ivar)
        end

        # Add blank line between ivars and methods if both exist
        @output << "" if node.instance_vars&.any? && node.body&.any?

        # Emit methods
        node.body.each { |member| visit(member) }

        @class_env = nil
        @indent -= 1
        emit("end")
      end

      def visit_instance_variable(node)
        type = node.type_annotation&.to_rbs || "untyped"
        emit("@#{node.name}: #{type}")
      end

      private

      def emit(text)
        @output << (("  " * @indent) + text)
      end

      def format_visibility(visibility)
        # RBS only supports private visibility, not protected
        # See: https://github.com/ruby/rbs/issues/579
        case visibility
        when :private
          "private "
        else
          ""
        end
      end
    end

    #==========================================================================
    # Optimization Passes
    #==========================================================================

    module Passes
      # Base class for optimization passes
      class Pass
        attr_reader :name, :changes_made

        def initialize(name)
          @name = name
          @changes_made = 0
        end

        def run(program)
          @changes_made = 0
          transform(program)
          { program: program, changes: @changes_made }
        end

        def transform(node)
          raise NotImplementedError
        end
      end

      # Dead code elimination
      class DeadCodeElimination < Pass
        def initialize
          super("dead_code_elimination")
        end

        def transform(node)
          case node
          when Program
            node.declarations = node.declarations.map { |d| transform(d) }.compact
          when Block
            node.statements = eliminate_dead_statements(node.statements)
            node.statements.each { |stmt| transform(stmt) }
          when MethodDef
            transform(node.body) if node.body
          end

          node
        end

        private

        def eliminate_dead_statements(statements)
          result = []
          found_return = false

          statements.each do |stmt|
            if found_return
              @changes_made += 1
              next
            end

            result << stmt
            found_return = true if stmt.is_a?(Return)
          end

          result
        end
      end

      # Constant folding
      class ConstantFolding < Pass
        def initialize
          super("constant_folding")
        end

        def transform(node)
          case node
          when Program
            node.declarations.each { |d| transform(d) }
          when MethodDef
            transform(node.body) if node.body
          when Block
            node.statements = node.statements.map { |s| fold_constants(s) }
          when BinaryOp
            fold_binary_op(node)
          end

          node
        end

        private

        def fold_constants(node)
          case node
          when BinaryOp
            fold_binary_op(node)
          when Assignment
            node.value = fold_constants(node.value)
            node
          when Return
            node.value = fold_constants(node.value) if node.value
            node
          else
            node
          end
        end

        def fold_binary_op(node)
          return node unless node.is_a?(BinaryOp)

          left = fold_constants(node.left)
          right = fold_constants(node.right)

          if left.is_a?(Literal) && right.is_a?(Literal)
            result = evaluate_op(node.operator, left.value, right.value)
            if result
              @changes_made += 1
              return Literal.new(value: result, literal_type: result.class.to_s.downcase.to_sym)
            end
          end

          node.left = left
          node.right = right
          node
        end

        def evaluate_op(op, left, right)
          return nil unless left.is_a?(Numeric) && right.is_a?(Numeric)

          case op
          when "+" then left + right
          when "-" then left - right
          when "*" then left * right
          when "/" then right.zero? ? nil : left / right
          when "%" then right.zero? ? nil : left % right
          when "**" then left**right
          end
        rescue StandardError
          nil
        end
      end

      # Type annotation cleanup
      class TypeAnnotationCleanup < Pass
        def initialize
          super("type_annotation_cleanup")
        end

        def transform(node)
          case node
          when Program
            node.declarations.each { |d| transform(d) }
          when MethodDef
            # Remove redundant type annotations
            node.params.each do |param|
              if param.type_annotation && redundant_annotation?(param)
                param.type_annotation = nil
                @changes_made += 1
              end
            end
          end

          node
        end

        private

        def redundant_annotation?(_param)
          # Consider annotation redundant if it matches the default/inferred type
          false
        end
      end

      # Unused declaration removal
      class UnusedDeclarationRemoval < Pass
        def initialize
          super("unused_declaration_removal")
        end

        def transform(node)
          return node unless node.is_a?(Program)

          used_types = collect_used_types(node)

          node.declarations = node.declarations.select do |decl|
            case decl
            when TypeAlias
              if used_types.include?(decl.name)
                true
              else
                @changes_made += 1
                false
              end
            else
              true
            end
          end

          node
        end

        private

        def collect_used_types(program)
          used = Set.new

          program.declarations.each do |decl|
            case decl
            when MethodDef
              collect_types_from_method(decl, used)
            when Interface
              decl.members.each do |member|
                collect_types_from_type(member.type_signature, used)
              end
            end
          end

          used
        end

        def collect_types_from_method(method, used)
          method.params.each do |param|
            collect_types_from_type(param.type_annotation, used) if param.type_annotation
          end
          collect_types_from_type(method.return_type, used) if method.return_type
        end

        def collect_types_from_type(type_node, used)
          case type_node
          when SimpleType
            used.add(type_node.name)
          when GenericType
            used.add(type_node.base)
            type_node.type_args.each { |arg| collect_types_from_type(arg, used) }
          when UnionType, IntersectionType
            type_node.types.each { |t| collect_types_from_type(t, used) }
          when NullableType
            collect_types_from_type(type_node.inner_type, used)
          when FunctionType
            type_node.param_types.each { |t| collect_types_from_type(t, used) }
            collect_types_from_type(type_node.return_type, used)
          end
        end
      end
    end

    #==========================================================================
    # Optimizer - Runs optimization passes
    #==========================================================================

    class Optimizer
      DEFAULT_PASSES = [
        Passes::DeadCodeElimination,
        Passes::ConstantFolding,
        Passes::TypeAnnotationCleanup,
        Passes::UnusedDeclarationRemoval,
      ].freeze

      attr_reader :passes, :stats

      def initialize(passes: DEFAULT_PASSES)
        @passes = passes.map(&:new)
        @stats = {}
      end

      def optimize(program, max_iterations: 10)
        @stats = { iterations: 0, total_changes: 0, pass_stats: {} }

        max_iterations.times do |i|
          @stats[:iterations] = i + 1
          changes_this_iteration = 0

          @passes.each do |pass|
            result = pass.run(program)
            program = result[:program]
            changes_this_iteration += result[:changes]

            @stats[:pass_stats][pass.name] ||= 0
            @stats[:pass_stats][pass.name] += result[:changes]
          end

          @stats[:total_changes] += changes_this_iteration
          break if changes_this_iteration.zero?
        end

        { program: program, stats: @stats }
      end
    end
  end
end
