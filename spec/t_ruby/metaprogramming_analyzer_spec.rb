# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::MetaprogrammingAnalyzer do
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    it "detects define_method calls with block params" do
      source = <<~RUBY
        class API
          define_method(:get) do |url, params|
            request(:get, url, params)
          end
        end
      RUBY

      result = analyzer.analyze(source)

      expect(result[:define_method_calls]).to include(
        hash_including(name: "get", dynamic: true)
      )
    end

    it "detects define_method with simple syntax" do
      source = <<~RUBY
        class Foo
          define_method :bar do
            "bar"
          end
        end
      RUBY

      result = analyzer.analyze(source)

      expect(result[:define_method_calls]).to include(
        hash_including(name: "bar", dynamic: true)
      )
    end

    it "detects method_missing implementations" do
      source = <<~RUBY
        class Delegator
          def method_missing(name, *args, &block)
            @target.send(name, *args, &block)
          end
        end
      RUBY

      result = analyzer.analyze(source, class_name: "Delegator")

      expect(result[:method_missing_handlers]).not_to be_empty
      expect(result[:method_missing_handlers].first[:method_arg]).to eq("name")
    end

    it "detects class_eval blocks" do
      source = <<~RUBY
        class Builder
          class_eval do
            def build
              new
            end

            attr_reader :name
          end
        end
      RUBY

      result = analyzer.analyze(source)

      expect(result[:class_eval_blocks]).to include(
        hash_including(name: "build", dynamic: true)
      )
    end
  end

  describe "#register_dynamic_pattern" do
    it "registers method_missing patterns" do
      analyzer.register_dynamic_pattern(
        "User",
        pattern: /^find_by_/,
        param_types: ["Any"],
        return_type: "User?"
      )

      info = analyzer.type_for_call("User", "find_by_email")

      expect(info).not_to be_nil
      expect(info[:return_type]).to eq("User?")
    end

    it "handles array patterns" do
      analyzer.register_dynamic_pattern(
        "API",
        pattern: [:get, :post, :put, :delete],
        param_types: ["String"],
        return_type: "Response"
      )

      expect(analyzer.dynamic_method?("API", :get)).to be true
      expect(analyzer.dynamic_method?("API", :post)).to be true
      expect(analyzer.dynamic_method?("API", :patch)).to be false
    end
  end

  describe "#register_model" do
    it "enables ActiveRecord-style dynamic finders" do
      analyzer.register_model("User", {
        "email" => "String",
        "name" => "String",
        "age" => "Integer"
      })

      info = analyzer.type_for_call("User", "find_by_email")

      expect(info).not_to be_nil
      expect(info[:return_type]).to eq("User?")
      expect(info[:params].first[:type]).to eq("String")
    end

    it "handles find_by_attribute! methods" do
      analyzer.register_model("User", { "email" => "String" })

      info = analyzer.type_for_call("User", "find_by_email!")

      expect(info).not_to be_nil
      expect(info[:return_type]).to eq("User")
    end

    it "handles find_all_by_attribute methods" do
      analyzer.register_model("User", { "role" => "String" })

      info = analyzer.type_for_call("User", "find_all_by_role")

      expect(info).not_to be_nil
      expect(info[:return_type]).to eq("Array<User>")
    end
  end

  describe "#parse_annotations" do
    it "parses dynamic_methods annotation" do
      source = <<~RUBY
        class API
          #: dynamic_methods [:get, :post, :put, :delete] -> (String) -> Response

          %w[get post put delete].each do |method|
            define_method(method) { |url| request(method, url) }
          end
        end
      RUBY

      analyzer.parse_annotations(source, "API")

      expect(analyzer.dynamic_method?("API", "get")).to be true
      expect(analyzer.dynamic_method?("API", "post")).to be true

      info = analyzer.type_for_call("API", "get")
      expect(info[:return_type]).to eq("Response")
    end

    it "parses method_missing annotation" do
      source = <<~RUBY
        class Finder
          #: method_missing /^find_by_/ -> (Any) -> Self?

          def method_missing(name, *args)
            # ...
          end
        end
      RUBY

      analyzer.parse_annotations(source, "Finder")

      expect(analyzer.dynamic_method?("Finder", "find_by_name")).to be true
      expect(analyzer.dynamic_method?("Finder", "find_by_email")).to be true
      expect(analyzer.dynamic_method?("Finder", "search")).to be false
    end
  end
end

RSpec.describe TRuby::Metaprogramming::DefineMethodAnalyzer do
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    it "parses define_method with params" do
      source = <<~RUBY
        define_method(:greet) do |name: String|
          "Hello, \#{name}"
        end
      RUBY

      methods = analyzer.analyze(source)

      expect(methods.length).to eq(1)
      expect(methods.first[:name]).to eq("greet")
      expect(methods.first[:params]).to include(
        hash_including(name: "name", type: "String")
      )
    end

    it "handles curly brace syntax" do
      source = 'define_method(:foo) { |x, y| x + y }'

      methods = analyzer.analyze(source)

      expect(methods.length).to eq(1)
      expect(methods.first[:params].length).to eq(2)
    end
  end
end

RSpec.describe TRuby::Metaprogramming::DynamicFinderAnalyzer do
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    before do
      analyzer.register_model("User", {
        "email" => "String",
        "name" => "String",
        "age" => "Integer",
        "active" => "Boolean"
      })
    end

    it "analyzes find_by_* methods" do
      result = analyzer.analyze("User", "find_by_email")

      expect(result).not_to be_nil
      expect(result[:name]).to eq("find_by_email")
      expect(result[:return_type]).to eq("User?")
      expect(result[:attribute]).to eq("email")
    end

    it "analyzes find_by_*! methods" do
      result = analyzer.analyze("User", "find_by_name!")

      expect(result).not_to be_nil
      expect(result[:return_type]).to eq("User")
    end

    it "analyzes find_all_by_* methods" do
      result = analyzer.analyze("User", "find_all_by_active")

      expect(result).not_to be_nil
      expect(result[:return_type]).to eq("Array<User>")
    end

    it "analyzes find_or_create_by_* methods" do
      result = analyzer.analyze("User", "find_or_create_by_email")

      expect(result).not_to be_nil
      expect(result[:return_type]).to eq("User")
    end

    it "returns nil for non-matching methods" do
      result = analyzer.analyze("User", "save")

      expect(result).to be_nil
    end
  end
end

RSpec.describe TRuby::Metaprogramming::ClassEvalAnalyzer do
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    it "finds method definitions in class_eval" do
      source = <<~RUBY
        class_eval do
          def foo(x)
            x.to_s
          end
        end
      RUBY

      results = analyzer.analyze(source)

      expect(results).not_to be_empty
      expect(results.first[:name]).to eq("foo")
      expect(results.first[:dynamic]).to be true
    end

    it "finds attr_* declarations" do
      source = <<~RUBY
        class_eval do
          attr_reader :name, :email
          attr_writer :age
          attr_accessor :active
        end
      RUBY

      results = analyzer.analyze(source)
      names = results.map { |r| r[:name] }

      expect(names).to include("name", "email")
      expect(names).to include("age=")
      expect(names).to include("active", "active=")
    end
  end
end

RSpec.describe TRuby::Metaprogramming::SendAnalyzer do
  let(:analyzer) { described_class.new }

  describe "#analyze_send" do
    it "returns type info for registered methods" do
      analyzer.register_method("String", "upcase", param_types: [], return_type: "String")

      result = analyzer.analyze_send("String", "upcase", [])

      expect(result[:return_type]).to eq("String")
    end

    it "returns Any for unknown methods" do
      result = analyzer.analyze_send("UnknownClass", "unknown_method", [])

      expect(result[:return_type]).to eq("Any")
      expect(result[:dynamic]).to be true
    end
  end
end
