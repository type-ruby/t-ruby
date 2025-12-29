# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::ASTTypeInferrer do
  subject(:inferrer) { described_class.new }

  let(:env) { TRuby::TypeEnv.new }

  describe "#infer_expression" do
    context "with literals" do
      it "infers String from string literal" do
        node = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
        expect(inferrer.infer_expression(node, env)).to eq("String")
      end

      it "infers Integer from integer literal" do
        node = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
        expect(inferrer.infer_expression(node, env)).to eq("Integer")
      end

      it "infers Float from float literal" do
        node = TRuby::IR::Literal.new(value: 3.14, literal_type: :float)
        expect(inferrer.infer_expression(node, env)).to eq("Float")
      end

      it "infers bool from boolean literal" do
        node = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
        expect(inferrer.infer_expression(node, env)).to eq("bool")
      end

      it "infers Symbol from symbol literal" do
        node = TRuby::IR::Literal.new(value: :ok, literal_type: :symbol)
        expect(inferrer.infer_expression(node, env)).to eq("Symbol")
      end

      it "infers nil from nil literal" do
        node = TRuby::IR::Literal.new(value: nil, literal_type: :nil)
        expect(inferrer.infer_expression(node, env)).to eq("nil")
      end
    end

    context "with variable references" do
      it "looks up variable type from environment" do
        env.define("name", "String")
        node = TRuby::IR::VariableRef.new(name: "name", scope: :local)

        expect(inferrer.infer_expression(node, env)).to eq("String")
      end

      it "returns untyped for undefined variable" do
        node = TRuby::IR::VariableRef.new(name: "unknown", scope: :local)
        expect(inferrer.infer_expression(node, env)).to eq("untyped")
      end

      it "looks up instance variable type" do
        env.define_instance_var("@name", "String")
        node = TRuby::IR::VariableRef.new(name: "@name", scope: :instance)

        expect(inferrer.infer_expression(node, env)).to eq("String")
      end
    end

    context "with binary operations" do
      it "infers bool from comparison operators" do
        left = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
        right = TRuby::IR::Literal.new(value: 2, literal_type: :integer)
        node = TRuby::IR::BinaryOp.new(operator: "==", left: left, right: right)

        expect(inferrer.infer_expression(node, env)).to eq("bool")
      end

      it "infers Integer from integer arithmetic" do
        left = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
        right = TRuby::IR::Literal.new(value: 2, literal_type: :integer)
        node = TRuby::IR::BinaryOp.new(operator: "+", left: left, right: right)

        expect(inferrer.infer_expression(node, env)).to eq("Integer")
      end

      it "infers Float when one operand is Float" do
        left = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
        right = TRuby::IR::Literal.new(value: 2.5, literal_type: :float)
        node = TRuby::IR::BinaryOp.new(operator: "+", left: left, right: right)

        expect(inferrer.infer_expression(node, env)).to eq("Float")
      end

      it "infers String from string concatenation" do
        left = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
        right = TRuby::IR::Literal.new(value: " world", literal_type: :string)
        node = TRuby::IR::BinaryOp.new(operator: "+", left: left, right: right)

        expect(inferrer.infer_expression(node, env)).to eq("String")
      end
    end

    context "with method calls" do
      it "infers type from builtin String methods" do
        receiver = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
        node = TRuby::IR::MethodCall.new(
          receiver: receiver,
          method_name: "upcase",
          arguments: []
        )

        expect(inferrer.infer_expression(node, env)).to eq("String")
      end

      it "infers Integer from String#length" do
        receiver = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
        node = TRuby::IR::MethodCall.new(
          receiver: receiver,
          method_name: "length",
          arguments: []
        )

        expect(inferrer.infer_expression(node, env)).to eq("Integer")
      end

      it "infers bool from predicate methods" do
        receiver = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
        node = TRuby::IR::MethodCall.new(
          receiver: receiver,
          method_name: "empty?",
          arguments: []
        )

        expect(inferrer.infer_expression(node, env)).to eq("bool")
      end

      it "infers class instance from new method" do
        receiver = TRuby::IR::VariableRef.new(name: "MyClass", scope: :constant)
        node = TRuby::IR::MethodCall.new(
          receiver: receiver,
          method_name: "new",
          arguments: []
        )

        expect(inferrer.infer_expression(node, env)).to eq("MyClass")
      end
    end

    context "with array literals" do
      it "infers Array[Integer] from integer array" do
        elements = [
          TRuby::IR::Literal.new(value: 1, literal_type: :integer),
          TRuby::IR::Literal.new(value: 2, literal_type: :integer),
        ]
        node = TRuby::IR::ArrayLiteral.new(elements: elements)

        expect(inferrer.infer_expression(node, env)).to eq("Array[Integer]")
      end

      it "infers Array[untyped] from empty array" do
        node = TRuby::IR::ArrayLiteral.new(elements: [])
        expect(inferrer.infer_expression(node, env)).to eq("Array[untyped]")
      end
    end

    context "with assignments" do
      it "registers variable type and returns value type" do
        value = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
        node = TRuby::IR::Assignment.new(target: "name", value: value)

        result = inferrer.infer_expression(node, env)

        expect(result).to eq("String")
        expect(env.lookup("name")).to eq("String")
      end

      it "registers instance variable type" do
        value = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
        node = TRuby::IR::Assignment.new(target: "@count", value: value)

        inferrer.infer_expression(node, env)

        expect(env.lookup_instance_var("@count")).to eq("Integer")
      end
    end

    context "with blocks" do
      it "returns last statement type" do
        stmts = [
          TRuby::IR::Assignment.new(
            target: "x",
            value: TRuby::IR::Literal.new(value: 1, literal_type: :integer)
          ),
          TRuby::IR::Literal.new(value: "done", literal_type: :string),
        ]
        node = TRuby::IR::Block.new(statements: stmts)

        expect(inferrer.infer_expression(node, env)).to eq("String")
      end

      it "returns nil for empty block" do
        node = TRuby::IR::Block.new(statements: [])
        expect(inferrer.infer_expression(node, env)).to eq("nil")
      end
    end
  end

  describe "#infer_method_return_type" do
    it "infers return type from method body" do
      body = TRuby::IR::Block.new(
        statements: [
          TRuby::IR::Literal.new(value: "hello", literal_type: :string),
        ]
      )
      method = TRuby::IR::MethodDef.new(
        name: "greet",
        params: [],
        return_type: nil,
        body: body
      )

      expect(inferrer.infer_method_return_type(method)).to eq("String")
    end

    it "infers type from explicit return" do
      body = TRuby::IR::Block.new(
        statements: [
          TRuby::IR::Return.new(
            value: TRuby::IR::Literal.new(value: 42, literal_type: :integer)
          ),
        ]
      )
      method = TRuby::IR::MethodDef.new(
        name: "number",
        params: [],
        return_type: nil,
        body: body
      )

      expect(inferrer.infer_method_return_type(method)).to eq("Integer")
    end

    it "uses parameter types in body analysis" do
      param = TRuby::IR::Parameter.new(
        name: "text",
        type_annotation: TRuby::IR::SimpleType.new(name: "String")
      )
      body = TRuby::IR::Block.new(
        statements: [
          TRuby::IR::MethodCall.new(
            receiver: TRuby::IR::VariableRef.new(name: "text", scope: :local),
            method_name: "upcase",
            arguments: []
          ),
        ]
      )
      method = TRuby::IR::MethodDef.new(
        name: "shout",
        params: [param],
        return_type: nil,
        body: body
      )

      expect(inferrer.infer_method_return_type(method)).to eq("String")
    end

    it "returns nil when method has no body" do
      method = TRuby::IR::MethodDef.new(
        name: "empty",
        params: [],
        return_type: nil,
        body: nil
      )

      expect(inferrer.infer_method_return_type(method)).to be_nil
    end
  end

  describe "type caching" do
    it "caches inferred types" do
      node = TRuby::IR::Literal.new(value: "hello", literal_type: :string)

      # First call
      inferrer.infer_expression(node, env)

      # Cache should have the type
      expect(inferrer.type_cache).to have_key(node.object_id)
    end
  end

  describe "unreachable code handling" do
    it "ignores code after unconditional return" do
      # def test
      #   return false
      #   "unreachable"
      # end
      body = TRuby::IR::Block.new(
        statements: [
          TRuby::IR::Return.new(
            value: TRuby::IR::Literal.new(value: false, literal_type: :boolean)
          ),
          TRuby::IR::Literal.new(value: "unreachable", literal_type: :string),
        ]
      )
      method = TRuby::IR::MethodDef.new(
        name: "test",
        params: [],
        return_type: nil,
        body: body
      )

      # Should be bool, not bool | String
      expect(inferrer.infer_method_return_type(method)).to eq("bool")
    end

    it "ignores conditional after unconditional return" do
      # def test
      #   return 42
      #   if condition
      #     "then"
      #   else
      #     "else"
      #   end
      # end
      conditional = TRuby::IR::Conditional.new(
        condition: TRuby::IR::Literal.new(value: true, literal_type: :boolean),
        then_branch: TRuby::IR::Block.new(
          statements: [TRuby::IR::Literal.new(value: "then", literal_type: :string)]
        ),
        else_branch: TRuby::IR::Block.new(
          statements: [TRuby::IR::Literal.new(value: "else", literal_type: :string)]
        ),
        kind: :if
      )
      body = TRuby::IR::Block.new(
        statements: [
          TRuby::IR::Return.new(
            value: TRuby::IR::Literal.new(value: 42, literal_type: :integer)
          ),
          conditional,
        ]
      )
      method = TRuby::IR::MethodDef.new(
        name: "test",
        params: [],
        return_type: nil,
        body: body
      )

      # Should be Integer only
      expect(inferrer.infer_method_return_type(method)).to eq("Integer")
    end

    it "collects returns from all branches when conditional does not fully terminate" do
      # def test
      #   if condition
      #     return "yes"
      #   end
      #   "no"
      # end
      conditional = TRuby::IR::Conditional.new(
        condition: TRuby::IR::Literal.new(value: true, literal_type: :boolean),
        then_branch: TRuby::IR::Block.new(
          statements: [
            TRuby::IR::Return.new(
              value: TRuby::IR::Literal.new(value: "yes", literal_type: :string)
            ),
          ]
        ),
        else_branch: nil,
        kind: :if
      )
      body = TRuby::IR::Block.new(
        statements: [
          conditional,
          TRuby::IR::Literal.new(value: "no", literal_type: :string),
        ]
      )
      method = TRuby::IR::MethodDef.new(
        name: "test",
        params: [],
        return_type: nil,
        body: body
      )

      # Should include both String from return and String from implicit return
      expect(inferrer.infer_method_return_type(method)).to eq("String")
    end
  end

  describe "logical operators" do
    it "infers right type from && operator" do
      left = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
      right = TRuby::IR::Literal.new(value: "success", literal_type: :string)
      node = TRuby::IR::BinaryOp.new(operator: "&&", left: left, right: right)

      expect(inferrer.infer_expression(node, env)).to eq("String")
    end

    it "infers union type from || operator" do
      left = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
      right = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
      node = TRuby::IR::BinaryOp.new(operator: "||", left: left, right: right)

      expect(inferrer.infer_expression(node, env)).to eq("String | Integer")
    end

    it "returns same type when || operands are same type" do
      left = TRuby::IR::Literal.new(value: "a", literal_type: :string)
      right = TRuby::IR::Literal.new(value: "b", literal_type: :string)
      node = TRuby::IR::BinaryOp.new(operator: "||", left: left, right: right)

      expect(inferrer.infer_expression(node, env)).to eq("String")
    end
  end

  describe "unary operators" do
    it "infers bool from ! operator" do
      operand = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
      node = TRuby::IR::UnaryOp.new(operator: "!", operand: operand)

      expect(inferrer.infer_expression(node, env)).to eq("bool")
    end

    it "infers same type from - operator" do
      operand = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
      node = TRuby::IR::UnaryOp.new(operator: "-", operand: operand)

      expect(inferrer.infer_expression(node, env)).to eq("Integer")
    end

    it "returns untyped for unknown operator" do
      operand = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
      node = TRuby::IR::UnaryOp.new(operator: "~", operand: operand)

      expect(inferrer.infer_expression(node, env)).to eq("untyped")
    end
  end

  describe "hash literals" do
    it "infers Hash type from key-value pairs" do
      key = TRuby::IR::Literal.new(value: :name, literal_type: :symbol)
      value = TRuby::IR::Literal.new(value: "John", literal_type: :string)
      pair = TRuby::IR::HashPair.new(key: key, value: value)
      node = TRuby::IR::HashLiteral.new(pairs: [pair])

      expect(inferrer.infer_expression(node, env)).to eq("Hash[Symbol, String]")
    end

    it "infers Hash[untyped, untyped] from empty hash" do
      node = TRuby::IR::HashLiteral.new(pairs: [])
      expect(inferrer.infer_expression(node, env)).to eq("Hash[untyped, untyped]")
    end
  end

  describe "conditional type inference" do
    it "unifies then and else branch types" do
      then_branch = TRuby::IR::Literal.new(value: "yes", literal_type: :string)
      else_branch = TRuby::IR::Literal.new(value: "no", literal_type: :string)
      condition = TRuby::IR::Literal.new(value: true, literal_type: :boolean)

      node = TRuby::IR::Conditional.new(
        condition: condition,
        then_branch: then_branch,
        else_branch: else_branch,
        kind: :if
      )

      expect(inferrer.infer_expression(node, env)).to eq("String")
    end

    it "returns nil when no branches" do
      condition = TRuby::IR::Literal.new(value: true, literal_type: :boolean)
      node = TRuby::IR::Conditional.new(
        condition: condition,
        then_branch: nil,
        else_branch: nil,
        kind: :if
      )

      expect(inferrer.infer_expression(node, env)).to eq("nil")
    end

    it "returns nullable type when else branch missing" do
      then_branch = TRuby::IR::Literal.new(value: "yes", literal_type: :string)
      condition = TRuby::IR::Literal.new(value: true, literal_type: :boolean)

      node = TRuby::IR::Conditional.new(
        condition: condition,
        then_branch: then_branch,
        else_branch: nil,
        kind: :if
      )

      expect(inferrer.infer_expression(node, env)).to eq("String")
    end
  end

  describe "return without value" do
    it "infers nil from return without value" do
      node = TRuby::IR::Return.new(value: nil)
      expect(inferrer.infer_expression(node, env)).to eq("nil")
    end
  end

  describe "constant references" do
    it "returns constant name as type" do
      node = TRuby::IR::VariableRef.new(name: "MyClass", scope: :constant)
      expect(inferrer.infer_expression(node, env)).to eq("MyClass")
    end

    it "treats capitalized names as constants" do
      node = TRuby::IR::VariableRef.new(name: "UserModel", scope: :local)
      expect(inferrer.infer_expression(node, env)).to eq("UserModel")
    end
  end

  describe "class variable assignment" do
    it "registers class variable type" do
      value = TRuby::IR::Literal.new(value: 0, literal_type: :integer)
      node = TRuby::IR::Assignment.new(target: "@@counter", value: value)

      inferrer.infer_expression(node, env)

      expect(env.lookup_class_var("@@counter")).to eq("Integer")
    end
  end

  describe "array concatenation" do
    it "infers array type from + operation on arrays" do
      left_elements = [TRuby::IR::Literal.new(value: 1, literal_type: :integer)]
      left = TRuby::IR::ArrayLiteral.new(elements: left_elements)

      right_elements = [TRuby::IR::Literal.new(value: 2, literal_type: :integer)]
      right = TRuby::IR::ArrayLiteral.new(elements: right_elements)

      node = TRuby::IR::BinaryOp.new(operator: "+", left: left, right: right)

      expect(inferrer.infer_expression(node, env)).to eq("Array[Integer]")
    end
  end

  describe "Object method fallback" do
    it "uses Object methods when receiver method not found" do
      receiver = TRuby::IR::Literal.new(value: 42, literal_type: :integer)
      node = TRuby::IR::MethodCall.new(
        receiver: receiver,
        method_name: "nil?",
        arguments: []
      )

      expect(inferrer.infer_expression(node, env)).to eq("bool")
    end

    it "returns receiver type for self-returning methods" do
      receiver = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
      node = TRuby::IR::MethodCall.new(
        receiver: receiver,
        method_name: "freeze",
        arguments: []
      )

      expect(inferrer.infer_expression(node, env)).to eq("String")
    end
  end

  describe "method call without receiver" do
    it "uses Object as default receiver" do
      node = TRuby::IR::MethodCall.new(
        receiver: nil,
        method_name: "to_s",
        arguments: []
      )

      expect(inferrer.infer_expression(node, env)).to eq("String")
    end
  end

  describe "interpolated strings" do
    it "always infers String type" do
      node = TRuby::IR::InterpolatedString.new(parts: [])
      expect(inferrer.infer_expression(node, env)).to eq("String")
    end
  end

  describe "RawCode nodes" do
    it "returns untyped for raw code" do
      node = TRuby::IR::RawCode.new(code: "some_dynamic_code")
      expect(inferrer.infer_expression(node, env)).to eq("untyped")
    end
  end

  describe "unknown binary operators" do
    it "returns untyped for unknown operators" do
      left = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
      right = TRuby::IR::Literal.new(value: 2, literal_type: :integer)
      node = TRuby::IR::BinaryOp.new(operator: "=~", left: left, right: right)

      expect(inferrer.infer_expression(node, env)).to eq("untyped")
    end
  end

  describe "parameter without type annotation" do
    it "uses untyped for parameter without annotation" do
      param = TRuby::IR::Parameter.new(name: "arg", type_annotation: nil)
      body = TRuby::IR::Block.new(
        statements: [
          TRuby::IR::VariableRef.new(name: "arg", scope: :local),
        ]
      )
      method = TRuby::IR::MethodDef.new(
        name: "test",
        params: [param],
        return_type: nil,
        body: body
      )

      expect(inferrer.infer_method_return_type(method)).to eq("untyped")
    end
  end

  describe "type unification with nil" do
    it "creates nullable type when nil is one of two types" do
      # Test through conditional with nil else
      then_branch = TRuby::IR::Literal.new(value: "hello", literal_type: :string)
      else_branch = TRuby::IR::Literal.new(value: nil, literal_type: :nil)
      condition = TRuby::IR::Literal.new(value: true, literal_type: :boolean)

      node = TRuby::IR::Conditional.new(
        condition: condition,
        then_branch: then_branch,
        else_branch: else_branch,
        kind: :if
      )

      expect(inferrer.infer_expression(node, env)).to eq("String?")
    end
  end

  describe "comparison operators coverage" do
    %w[!= < > <= >= <=>].each do |op|
      it "infers bool from #{op} operator" do
        left = TRuby::IR::Literal.new(value: 1, literal_type: :integer)
        right = TRuby::IR::Literal.new(value: 2, literal_type: :integer)
        node = TRuby::IR::BinaryOp.new(operator: op, left: left, right: right)

        expect(inferrer.infer_expression(node, env)).to eq("bool")
      end
    end
  end

  describe "arithmetic operators coverage" do
    %w[- * / % **].each do |op|
      it "infers Integer from integer #{op} operation" do
        left = TRuby::IR::Literal.new(value: 10, literal_type: :integer)
        right = TRuby::IR::Literal.new(value: 2, literal_type: :integer)
        node = TRuby::IR::BinaryOp.new(operator: op, left: left, right: right)

        expect(inferrer.infer_expression(node, env)).to eq("Integer")
      end
    end
  end
end
