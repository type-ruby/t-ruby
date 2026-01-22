# frozen_string_literal: true

require "spec_helper"

RSpec.describe "TokenDeclarationParser TypeSlot integration" do
  include TRuby::ParserCombinator::TokenDSL

  let(:parser) { TRuby::ParserCombinator::TokenDeclarationParser.new }
  let(:scanner) { TRuby::Scanner.new(source) }
  let(:tokens) { scanner.scan_all }

  describe "parameter type slots" do
    context "with typed parameter" do
      let(:source) do
        <<~RUBY
          def greet(name: String)
            name
          end
        RUBY
      end

      it "creates type_slot for parameter" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.success?).to be true
        param = result.value.params[0]
        expect(param.type_slot).to be_a(TRuby::IR::TypeSlot)
      end

      it "sets type_slot kind to :parameter" do
        result = parser.parse_declaration(tokens, 0)

        param = result.value.params[0]
        expect(param.type_slot.kind).to eq(:parameter)
      end

      it "sets explicit_type on type_slot when type annotation present" do
        result = parser.parse_declaration(tokens, 0)

        param = result.value.params[0]
        expect(param.type_slot.explicit_type).to be_a(TRuby::IR::SimpleType)
        expect(param.type_slot.explicit_type.name).to eq("String")
      end

      it "sets type_slot context with method and param info" do
        result = parser.parse_declaration(tokens, 0)

        param = result.value.params[0]
        expect(param.type_slot.context[:method_name]).to eq("greet")
        expect(param.type_slot.context[:param_name]).to eq("name")
      end

      it "sets type_slot location" do
        result = parser.parse_declaration(tokens, 0)

        param = result.value.params[0]
        expect(param.type_slot.location).to have_key(:line)
        expect(param.type_slot.location).to have_key(:column)
      end
    end

    context "with untyped parameter" do
      let(:source) do
        <<~RUBY
          def greet(name)
            name
          end
        RUBY
      end

      it "creates type_slot for untyped parameter" do
        result = parser.parse_declaration(tokens, 0)

        param = result.value.params[0]
        expect(param.type_slot).to be_a(TRuby::IR::TypeSlot)
      end

      it "leaves explicit_type nil for untyped parameter" do
        result = parser.parse_declaration(tokens, 0)

        param = result.value.params[0]
        expect(param.type_slot.explicit_type).to be_nil
      end

      it "needs_inference? returns true for untyped parameter" do
        result = parser.parse_declaration(tokens, 0)

        param = result.value.params[0]
        expect(param.type_slot.needs_inference?).to be true
      end
    end

    context "with multiple parameters" do
      let(:source) do
        <<~RUBY
          def greet(name: String, age)
            name
          end
        RUBY
      end

      it "creates type_slot for each parameter" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.params[0].type_slot).to be_a(TRuby::IR::TypeSlot)
        expect(result.value.params[1].type_slot).to be_a(TRuby::IR::TypeSlot)
      end

      it "typed parameter has explicit_type set" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.params[0].type_slot.explicit_type).not_to be_nil
      end

      it "untyped parameter has explicit_type nil" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.params[1].type_slot.explicit_type).to be_nil
      end
    end

    context "with special parameter kinds" do
      describe "rest parameter (*args)" do
        let(:source) do
          <<~RUBY
            def collect(*items: Array<String>)
            end
          RUBY
        end

        it "creates type_slot for rest parameter" do
          result = parser.parse_declaration(tokens, 0)

          param = result.value.params[0]
          expect(param.type_slot).to be_a(TRuby::IR::TypeSlot)
          expect(param.type_slot.kind).to eq(:parameter)
        end
      end

      describe "keyrest parameter (**opts)" do
        let(:source) do
          <<~RUBY
            def configure(**opts)
            end
          RUBY
        end

        it "creates type_slot for keyrest parameter" do
          result = parser.parse_declaration(tokens, 0)

          param = result.value.params[0]
          expect(param.type_slot).to be_a(TRuby::IR::TypeSlot)
        end
      end

      describe "block parameter (&block)" do
        let(:source) do
          <<~RUBY
            def execute(&block)
            end
          RUBY
        end

        it "creates type_slot for block parameter" do
          result = parser.parse_declaration(tokens, 0)

          param = result.value.params[0]
          expect(param.type_slot).to be_a(TRuby::IR::TypeSlot)
        end
      end
    end
  end

  describe "return type slots" do
    context "with return type annotation" do
      let(:source) do
        <<~RUBY
          def greet(name: String): String
            name
          end
        RUBY
      end

      it "creates return_type_slot for method" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.return_type_slot).to be_a(TRuby::IR::TypeSlot)
      end

      it "sets return_type_slot kind to :return" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.return_type_slot.kind).to eq(:return)
      end

      it "sets explicit_type on return_type_slot" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.return_type_slot.explicit_type).to be_a(TRuby::IR::SimpleType)
        expect(result.value.return_type_slot.explicit_type.name).to eq("String")
      end

      it "sets return_type_slot context with method info" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.return_type_slot.context[:method_name]).to eq("greet")
      end
    end

    context "without return type annotation" do
      let(:source) do
        <<~RUBY
          def greet(name: String)
            name
          end
        RUBY
      end

      it "creates return_type_slot even without annotation" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.return_type_slot).to be_a(TRuby::IR::TypeSlot)
      end

      it "leaves explicit_type nil without annotation" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.return_type_slot.explicit_type).to be_nil
      end

      it "needs_inference? returns true without annotation" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.return_type_slot.needs_inference?).to be true
      end
    end

    context "with union return type" do
      let(:source) do
        <<~RUBY
          def find(id: Integer): String | nil
            "found"
          end
        RUBY
      end

      it "sets union type as explicit_type" do
        result = parser.parse_declaration(tokens, 0)

        expect(result.value.return_type_slot.explicit_type).to be_a(TRuby::IR::UnionType)
      end
    end
  end

  describe "backward compatibility" do
    let(:source) do
      <<~RUBY
        def greet(name: String): String
          name
        end
      RUBY
    end

    it "still sets type_annotation on parameter" do
      result = parser.parse_declaration(tokens, 0)

      param = result.value.params[0]
      expect(param.type_annotation).to be_a(TRuby::IR::SimpleType)
    end

    it "still sets return_type on method" do
      result = parser.parse_declaration(tokens, 0)

      expect(result.value.return_type).to be_a(TRuby::IR::SimpleType)
    end
  end
end
