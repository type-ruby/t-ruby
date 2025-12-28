# frozen_string_literal: true

require "spec_helper"

RSpec.describe TRuby::CodeEmitter do
  describe ".for_version" do
    it "returns Ruby30 emitter for version 3.0" do
      emitter = described_class.for_version("3.0")
      expect(emitter).to be_a(TRuby::CodeEmitter::Ruby30)
      expect(emitter.version).to eq(TRuby::RubyVersion.parse("3.0"))
    end

    it "returns Ruby31 emitter for version 3.1" do
      emitter = described_class.for_version("3.1")
      expect(emitter).to be_a(TRuby::CodeEmitter::Ruby31)
    end

    it "returns Ruby34 emitter for version 3.4" do
      emitter = described_class.for_version("3.4")
      expect(emitter).to be_a(TRuby::CodeEmitter::Ruby34)
    end

    it "returns Ruby40 emitter for version 4.0" do
      emitter = described_class.for_version("4.0")
      expect(emitter).to be_a(TRuby::CodeEmitter::Ruby40)
    end

    it "returns appropriate emitter for intermediate versions" do
      # 3.2 should use Ruby31 (supports anonymous block forwarding)
      expect(described_class.for_version("3.2")).to be_a(TRuby::CodeEmitter::Ruby31)
      expect(described_class.for_version("3.3")).to be_a(TRuby::CodeEmitter::Ruby31)

      # 3.5 should use Ruby34 (supports it parameter)
      expect(described_class.for_version("3.5")).to be_a(TRuby::CodeEmitter::Ruby34)

      # 4.1 should use Ruby40
      expect(described_class.for_version("4.1")).to be_a(TRuby::CodeEmitter::Ruby40)
    end
  end

  describe TRuby::CodeEmitter::Ruby30 do
    let(:emitter) { described_class.new(TRuby::RubyVersion.parse("3.0")) }

    describe "#transform_numbered_params" do
      it "preserves _1, _2 syntax" do
        source = "items.map { _1 * 2 }"
        expect(emitter.transform_numbered_params(source)).to eq("items.map { _1 * 2 }")
      end

      it "preserves multiple numbered params" do
        source = "hash.map { [_1, _2] }"
        expect(emitter.transform_numbered_params(source)).to eq("hash.map { [_1, _2] }")
      end
    end

    describe "#transform_block_forwarding" do
      it "preserves named block forwarding" do
        source = "def foo(&block)\n  bar(&block)\nend"
        expect(emitter.transform_block_forwarding(source)).to eq("def foo(&block)\n  bar(&block)\nend")
      end
    end
  end

  describe TRuby::CodeEmitter::Ruby31 do
    let(:emitter) { described_class.new(TRuby::RubyVersion.parse("3.1")) }

    describe "#transform_numbered_params" do
      it "preserves _1, _2 syntax" do
        source = "items.map { _1 * 2 }"
        expect(emitter.transform_numbered_params(source)).to eq("items.map { _1 * 2 }")
      end
    end

    describe "#transform_block_forwarding" do
      it "converts named block to anonymous forwarding" do
        source = "def foo(&block)\n  bar(&block)\nend"
        expected = "def foo(&)\n  bar(&)\nend"
        expect(emitter.transform_block_forwarding(source)).to eq(expected)
      end

      it "handles multiple block forwards in same method" do
        source = "def foo(&block)\n  bar(&block)\n  baz(&block)\nend"
        expected = "def foo(&)\n  bar(&)\n  baz(&)\nend"
        expect(emitter.transform_block_forwarding(source)).to eq(expected)
      end

      it "does not transform when block is used for other purposes" do
        # If block is called directly, we can't use anonymous forwarding
        source = "def foo(&block)\n  block.call\nend"
        expect(emitter.transform_block_forwarding(source)).to eq("def foo(&block)\n  block.call\nend")
      end
    end
  end

  describe TRuby::CodeEmitter::Ruby34 do
    let(:emitter) { described_class.new(TRuby::RubyVersion.parse("3.4")) }

    describe "#transform_numbered_params" do
      it "preserves _1, _2 syntax (still valid in 3.4)" do
        source = "items.map { _1 * 2 }"
        expect(emitter.transform_numbered_params(source)).to eq("items.map { _1 * 2 }")
      end
    end

    describe "#transform_block_forwarding" do
      it "converts named block to anonymous forwarding" do
        source = "def foo(&block)\n  bar(&block)\nend"
        expected = "def foo(&)\n  bar(&)\nend"
        expect(emitter.transform_block_forwarding(source)).to eq(expected)
      end
    end

    describe "#supports_it?" do
      it "returns true" do
        expect(emitter.supports_it?).to be true
      end
    end
  end

  describe TRuby::CodeEmitter::Ruby40 do
    let(:emitter) { described_class.new(TRuby::RubyVersion.parse("4.0")) }

    describe "#transform_numbered_params" do
      it "converts single _1 to it" do
        source = "items.map { _1 * 2 }"
        expect(emitter.transform_numbered_params(source)).to eq("items.map { it * 2 }")
      end

      it "preserves explicit block params when multiple numbered params used" do
        # When _2 or higher is used, can't convert to it
        source = "hash.map { [_1, _2] }"
        expect(emitter.transform_numbered_params(source)).to eq("hash.map { |k, v| [k, v] }")
      end

      it "handles nested blocks correctly" do
        source = "outer.map { _1.inner.map { _1 * 2 } }"
        expected = "outer.map { it.inner.map { it * 2 } }"
        expect(emitter.transform_numbered_params(source)).to eq(expected)
      end
    end

    describe "#transform_block_forwarding" do
      it "converts named block to anonymous forwarding" do
        source = "def foo(&block)\n  bar(&block)\nend"
        expected = "def foo(&)\n  bar(&)\nend"
        expect(emitter.transform_block_forwarding(source)).to eq(expected)
      end
    end

    describe "#supports_it?" do
      it "returns true" do
        expect(emitter.supports_it?).to be true
      end
    end

    describe "#numbered_params_error?" do
      it "returns true" do
        expect(emitter.numbered_params_error?).to be true
      end
    end
  end

  describe "transform pipeline" do
    it "applies all transformations for Ruby 4.0" do
      emitter = TRuby::CodeEmitter.for_version("4.0")

      source = <<~RUBY
        def process(&block)
          items.map { _1 * 2 }
          forward(&block)
        end
      RUBY

      result = emitter.transform(source)

      expect(result).to include("{ it * 2 }")
      expect(result).to include("def process(&)")
      expect(result).to include("forward(&)")
    end

    it "preserves Ruby 3.0 syntax for 3.0 target" do
      emitter = TRuby::CodeEmitter.for_version("3.0")

      source = <<~RUBY
        def process(&block)
          items.map { _1 * 2 }
          forward(&block)
        end
      RUBY

      result = emitter.transform(source)

      expect(result).to include("{ _1 * 2 }")
      expect(result).to include("def process(&block)")
      expect(result).to include("forward(&block)")
    end
  end
end
