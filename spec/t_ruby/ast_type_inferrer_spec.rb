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
end
