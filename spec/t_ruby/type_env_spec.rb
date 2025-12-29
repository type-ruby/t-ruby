# frozen_string_literal: true

require "spec_helper"

describe TRuby::TypeEnv do
  let(:env) { described_class.new }

  describe "#initialize" do
    it "creates env without parent" do
      expect(env.parent).to be_nil
    end

    it "creates env with parent" do
      child = described_class.new(env)
      expect(child.parent).to eq(env)
    end

    it "initializes with empty bindings" do
      expect(env.bindings).to eq({})
    end

    it "initializes with empty instance_vars" do
      expect(env.instance_vars).to eq({})
    end
  end

  describe "#define" do
    it "defines a local variable" do
      env.define("x", "Integer")
      expect(env.bindings["x"]).to eq("Integer")
    end
  end

  describe "#lookup" do
    it "returns defined variable type" do
      env.define("x", "Integer")
      expect(env.lookup("x")).to eq("Integer")
    end

    it "returns nil for undefined variable" do
      expect(env.lookup("unknown")).to be_nil
    end

    it "looks up in parent scope" do
      env.define("x", "Integer")
      child = described_class.new(env)
      expect(child.lookup("x")).to eq("Integer")
    end

    it "prefers child scope binding" do
      env.define("x", "Integer")
      child = described_class.new(env)
      child.define("x", "String")
      expect(child.lookup("x")).to eq("String")
    end

    it "delegates instance var lookup" do
      env.define_instance_var("@name", "String")
      expect(env.lookup("@name")).to eq("String")
    end

    it "delegates class var lookup" do
      env.define_class_var("@@count", "Integer")
      expect(env.lookup("@@count")).to eq("Integer")
    end
  end

  describe "#define_instance_var" do
    it "defines instance variable" do
      env.define_instance_var("@name", "String")
      expect(env.instance_vars["@name"]).to eq("String")
    end

    it "normalizes name without @" do
      env.define_instance_var("name", "String")
      expect(env.instance_vars["@name"]).to eq("String")
    end
  end

  describe "#lookup_instance_var" do
    it "returns instance variable type" do
      env.define_instance_var("@name", "String")
      expect(env.lookup_instance_var("@name")).to eq("String")
    end

    it "normalizes name without @" do
      env.define_instance_var("@name", "String")
      expect(env.lookup_instance_var("name")).to eq("String")
    end

    it "looks up in parent scope" do
      env.define_instance_var("@name", "String")
      child = described_class.new(env)
      expect(child.lookup_instance_var("@name")).to eq("String")
    end
  end

  describe "#define_class_var" do
    it "defines class variable" do
      env.define_class_var("@@count", "Integer")
      result = env.lookup_class_var("@@count")
      expect(result).to eq("Integer")
    end

    it "normalizes name without @@" do
      env.define_class_var("count", "Integer")
      expect(env.lookup_class_var("@@count")).to eq("Integer")
    end
  end

  describe "#lookup_class_var" do
    it "looks up in parent scope" do
      env.define_class_var("@@count", "Integer")
      child = described_class.new(env)
      expect(child.lookup_class_var("@@count")).to eq("Integer")
    end
  end

  describe "#child_scope" do
    it "creates child with self as parent" do
      child = env.child_scope
      expect(child.parent).to eq(env)
    end
  end

  describe "#local_names" do
    it "returns local variable names" do
      env.define("x", "Integer")
      env.define("y", "String")
      expect(env.local_names).to contain_exactly("x", "y")
    end
  end

  describe "#instance_var_names" do
    it "returns instance variable names" do
      env.define_instance_var("@x", "Integer")
      env.define_instance_var("@y", "String")
      expect(env.instance_var_names).to contain_exactly("@x", "@y")
    end
  end

  describe "#defined_locally?" do
    it "returns true for locally defined variable" do
      env.define("x", "Integer")
      expect(env.defined_locally?("x")).to be true
    end

    it "returns false for undefined variable" do
      expect(env.defined_locally?("x")).to be false
    end

    it "returns false for parent-defined variable" do
      env.define("x", "Integer")
      child = described_class.new(env)
      expect(child.defined_locally?("x")).to be false
    end
  end

  describe "#depth" do
    it "returns 0 for root env" do
      expect(env.depth).to eq(0)
    end

    it "returns correct depth for nested envs" do
      child = described_class.new(env)
      grandchild = described_class.new(child)
      expect(child.depth).to eq(1)
      expect(grandchild.depth).to eq(2)
    end
  end

  describe "#all_bindings" do
    it "merges parent bindings" do
      env.define("x", "Integer")
      child = described_class.new(env)
      child.define("y", "String")

      expect(child.all_bindings).to eq({ "x" => "Integer", "y" => "String" })
    end

    it "child bindings override parent" do
      env.define("x", "Integer")
      child = described_class.new(env)
      child.define("x", "String")

      expect(child.all_bindings["x"]).to eq("String")
    end
  end

  describe "#to_s" do
    it "includes depth" do
      expect(env.to_s).to include("depth=0")
    end

    it "includes locals when present" do
      env.define("x", "Integer")
      expect(env.to_s).to include("locals:")
    end

    it "includes ivars when present" do
      env.define_instance_var("@x", "Integer")
      expect(env.to_s).to include("ivars:")
    end
  end
end
