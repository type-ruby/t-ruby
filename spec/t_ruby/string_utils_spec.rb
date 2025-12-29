# frozen_string_literal: true

require "spec_helper"

describe TRuby::StringUtils do
  describe ".split_by_comma" do
    it "splits simple comma-separated values" do
      result = described_class.split_by_comma("a, b, c")
      expect(result).to eq(%w[a b c])
    end

    it "handles nested angle brackets" do
      result = described_class.split_by_comma("Array<String>, Hash<String, Integer>")
      expect(result).to eq(["Array<String>", "Hash<String, Integer>"])
    end

    it "handles nested angle brackets with parentheses inside" do
      # split_by_comma tracks <> [] () {} for nesting
      result = described_class.split_by_comma("Hash<String, Integer>, Array<String>")
      expect(result).to eq(["Hash<String, Integer>", "Array<String>"])
    end

    it "handles nested square brackets" do
      result = described_class.split_by_comma("Array[String], Tuple[Integer, String]")
      expect(result).to eq(["Array[String]", "Tuple[Integer, String]"])
    end

    it "handles nested curly braces" do
      result = described_class.split_by_comma("{a: String}, {b: Integer}")
      expect(result).to eq(["{a: String}", "{b: Integer}"])
    end

    it "handles deeply nested structures" do
      result = described_class.split_by_comma("Hash<String, Array<Hash<Symbol, Integer>>>")
      expect(result).to eq(["Hash<String, Array<Hash<Symbol, Integer>>>"])
    end

    it "handles empty string" do
      result = described_class.split_by_comma("")
      expect(result).to eq([])
    end

    it "handles single value" do
      result = described_class.split_by_comma("String")
      expect(result).to eq(["String"])
    end

    it "strips whitespace" do
      result = described_class.split_by_comma("  a  ,  b  ,  c  ")
      expect(result).to eq(%w[a b c])
    end
  end

  describe ".split_type_and_default" do
    it "splits type and default value" do
      type, default = described_class.split_type_and_default("String = 'hello'")
      expect(type).to eq("String")
      expect(default).to eq("'hello'")
    end

    it "returns nil default when no = present" do
      type, default = described_class.split_type_and_default("String")
      expect(type).to eq("String")
      expect(default).to be_nil
    end

    it "ignores = inside angle brackets" do
      type, default = described_class.split_type_and_default("Hash<K = String, V> = {}")
      expect(type).to eq("Hash<K = String, V>")
      expect(default).to eq("{}")
    end

    it "handles simple type with default" do
      type, default = described_class.split_type_and_default("Integer = 42")
      expect(type).to eq("Integer")
      expect(default).to eq("42")
    end

    it "ignores = inside square brackets" do
      type, default = described_class.split_type_and_default("Array[x = 1] = []")
      expect(type).to eq("Array[x = 1]")
      expect(default).to eq("[]")
    end

    it "ignores = inside curly braces" do
      type, default = described_class.split_type_and_default("{x: y = 1} = {}")
      expect(type).to eq("{x: y = 1}")
      expect(default).to eq("{}")
    end

    it "strips whitespace from both parts" do
      type, default = described_class.split_type_and_default("  String  =  'test'  ")
      expect(type).to eq("String")
      expect(default).to eq("'test'")
    end
  end

  describe ".extract_default_value" do
    it "extracts default value" do
      result = described_class.extract_default_value("String = 'hello'")
      expect(result).to eq("'hello'")
    end

    it "returns nil when no default" do
      result = described_class.extract_default_value("String")
      expect(result).to be_nil
    end
  end
end
