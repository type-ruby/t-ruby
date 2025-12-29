# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe "Colon Spacing Validation E2E" do
  let(:tmpdir) { Dir.mktmpdir("trb_colon_spacing") }
  let(:config) do
    config = TRuby::Config.new
    allow(config).to receive(:out_dir).and_return(tmpdir)
    allow(config).to receive(:ruby_dir).and_return(tmpdir)
    allow(config).to receive(:rbs_dir).and_return(tmpdir)
    allow(config).to receive(:source_include).and_return([tmpdir])
    config
  end
  let(:compiler) { TRuby::Compiler.new(config) }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "Return type colon spacing" do
    context "valid syntax" do
      it "accepts colon directly after method name without parens" do
        # def method_name: Type (colon attached to method name)
        source = <<~TRB
          def t1: Integer
            1
          end
        TRB
        input_file = File.join(tmpdir, "valid1.trb")
        File.write(input_file, source)

        result = compiler.compile_with_diagnostics(input_file)
        colon_errors = result[:diagnostics].select { |d| d.message.include?("colon") || d.message.include?("':'") }
        expect(colon_errors).to be_empty
      end

      it "accepts colon directly after closing paren" do
        # def method_name(): Type (colon attached to closing paren)
        source = <<~TRB
          def greet(name: String): String
            "Hello, \#{name}!"
          end
        TRB
        input_file = File.join(tmpdir, "valid2.trb")
        File.write(input_file, source)

        result = compiler.compile_with_diagnostics(input_file)
        colon_errors = result[:diagnostics].select { |d| d.message.include?("colon") || d.message.include?("':'") }
        expect(colon_errors).to be_empty
      end

      it "accepts space after colon before type" do
        source = <<~TRB
          def add(a: Integer, b: Integer): Integer
            a + b
          end
        TRB
        input_file = File.join(tmpdir, "valid3.trb")
        File.write(input_file, source)

        result = compiler.compile_with_diagnostics(input_file)
        colon_errors = result[:diagnostics].select { |d| d.message.include?("colon") || d.message.include?("':'") }
        expect(colon_errors).to be_empty
      end
    end

    context "invalid syntax - space before colon" do
      it "rejects space between method name and colon (no parens)" do
        # def method_name : Type (space before colon - INVALID)
        source = <<~TRB
          def t1_space_before_colon : Integer
            1
          end
        TRB
        input_file = File.join(tmpdir, "invalid1.trb")
        File.write(input_file, source)

        result = compiler.compile_with_diagnostics(input_file)
        expect(result[:success]).to be false
        expect(result[:diagnostics].any? { |d| d.message.include?("No space allowed before ':'") }).to be true
      end

      it "rejects space between closing paren and colon (empty parens)" do
        # def method_name() : Type (space before colon - INVALID)
        source = <<~TRB
          def t1_space_before_colon_with_parens() : Integer
            1
          end
        TRB
        input_file = File.join(tmpdir, "invalid2.trb")
        File.write(input_file, source)

        result = compiler.compile_with_diagnostics(input_file)
        expect(result[:success]).to be false
        expect(result[:diagnostics].any? { |d| d.message.include?("No space allowed before ':'") }).to be true
      end

      it "rejects space between closing paren and colon (with params)" do
        # def method_name(params) : Type (space before colon - INVALID)
        source = <<~TRB
          def greet_with_space_before_colon(n: Integer, s: String) : Integer
            n
          end
        TRB
        input_file = File.join(tmpdir, "invalid3.trb")
        File.write(input_file, source)

        result = compiler.compile_with_diagnostics(input_file)
        expect(result[:success]).to be false
        expect(result[:diagnostics].any? { |d| d.message.include?("No space allowed before ':'") }).to be true
      end
    end

    context "invalid syntax - no space after colon" do
      it "rejects colon directly attached to type name" do
        # def method_name():Type (no space after colon - INVALID)
        source = <<~TRB
          def t1_no_space_after_colon():Integer
            1
          end
        TRB
        input_file = File.join(tmpdir, "invalid4.trb")
        File.write(input_file, source)

        result = compiler.compile_with_diagnostics(input_file)
        expect(result[:success]).to be false
        expect(result[:diagnostics].any? { |d| d.message.include?("Space required after ':'") }).to be true
      end

      it "rejects colon directly attached to type name (no parens)" do
        # def method_name:Type (no space after colon - INVALID)
        source = <<~TRB
          def t1_no_space_after_colon_no_parens:Integer
            1
          end
        TRB
        input_file = File.join(tmpdir, "invalid5.trb")
        File.write(input_file, source)

        result = compiler.compile_with_diagnostics(input_file)
        expect(result[:success]).to be false
        expect(result[:diagnostics].any? { |d| d.message.include?("Space required after ':'") }).to be true
      end
    end
  end

  describe "Unicode method names" do
    it "validates colon spacing for Korean method names" do
      source = <<~TRB
        def 한글_메서드(): String
          "안녕하세요"
        end
      TRB
      input_file = File.join(tmpdir, "korean.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      colon_errors = result[:diagnostics].select { |d| d.message.include?("colon") || d.message.include?("':'") }
      expect(colon_errors).to be_empty
    end

    it "rejects space before colon for Korean method names" do
      source = <<~TRB
        def 한글_메서드_에러() : String
          "안녕하세요"
        end
      TRB
      input_file = File.join(tmpdir, "korean_error.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      expect(result[:success]).to be false
      expect(result[:diagnostics].any? { |d| d.message.include?("No space allowed before ':'") }).to be true
    end
  end

  describe "Complex signatures" do
    it "validates colon spacing for generic return types" do
      source = <<~TRB
        def get_array(): Array<String>
          []
        end
      TRB
      input_file = File.join(tmpdir, "generic.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      colon_errors = result[:diagnostics].select { |d| d.message.include?("colon") || d.message.include?("':'") }
      expect(colon_errors).to be_empty
    end

    it "validates colon spacing for union return types" do
      source = <<~TRB
        def maybe_string(): String | nil
          nil
        end
      TRB
      input_file = File.join(tmpdir, "union.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      colon_errors = result[:diagnostics].select { |d| d.message.include?("colon") || d.message.include?("':'") }
      expect(colon_errors).to be_empty
    end

    it "validates colon spacing for nullable return types" do
      source = <<~TRB
        def find_user(id: Integer): String?
          nil
        end
      TRB
      input_file = File.join(tmpdir, "nullable.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      colon_errors = result[:diagnostics].select { |d| d.message.include?("colon") || d.message.include?("':'") }
      expect(colon_errors).to be_empty
    end

    it "validates colon spacing with visibility modifiers" do
      source = <<~TRB
        private def secret_method(): Integer
          42
        end
      TRB
      input_file = File.join(tmpdir, "visibility.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      colon_errors = result[:diagnostics].select { |d| d.message.include?("colon") || d.message.include?("':'") }
      expect(colon_errors).to be_empty
    end
  end

  describe "Error message format" do
    it "includes error code TR1003 for colon spacing errors" do
      source = <<~TRB
        def bad_spacing() : Integer
          1
        end
      TRB
      input_file = File.join(tmpdir, "error_code.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      colon_error = result[:diagnostics].find { |d| d.message.include?("No space allowed before ':'") }
      expect(colon_error).not_to be_nil
      expect(colon_error.code).to eq("TR1003")
    end

    it "includes line number in diagnostic" do
      source = <<~TRB
        def valid_method(): Integer
          1
        end

        def bad_spacing() : Integer
          2
        end
      TRB
      input_file = File.join(tmpdir, "line_number.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      colon_error = result[:diagnostics].find { |d| d.message.include?("No space allowed before ':'") }
      expect(colon_error).not_to be_nil
      expect(colon_error.line).to eq(5)
    end
  end

  describe "Multiple errors" do
    it "reports all colon spacing errors in a file" do
      source = <<~TRB
        def error1() : Integer
          1
        end

        def error2():Integer
          2
        end

        def valid(): Integer
          3
        end
      TRB
      input_file = File.join(tmpdir, "multiple.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      colon_errors = result[:diagnostics].select { |d| d.code == "TR1003" }
      expect(colon_errors.length).to eq(2)
    end
  end

  describe "Hash literal type parsing" do
    it "parses hash literal type in parameter" do
      source = <<~TRB
        def process_config(config: { host: String, port: Integer }): String
          config[:host]
        end
      TRB
      input_file = File.join(tmpdir, "hash_literal1.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      expect(result[:diagnostics]).to be_empty
      expect(result[:success]).to be true
    end

    it "parses hash literal type with default values" do
      source = <<~TRB
        def with_defaults(opts: { name: String, age: Integer = 0 }): String
          opts[:name]
        end
      TRB
      input_file = File.join(tmpdir, "hash_literal2.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      expect(result[:diagnostics]).to be_empty
      expect(result[:success]).to be true
    end

    it "parses keyword arguments with braces" do
      source = <<~TRB
        def greet({ name: String, prefix: String = "Hello" }): String
          "\#{prefix}, \#{name}!"
        end
      TRB
      input_file = File.join(tmpdir, "keyword_args1.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      expect(result[:diagnostics]).to be_empty
      expect(result[:success]).to be true
    end

    it "parses mixed positional and keyword arguments" do
      source = <<~TRB
        def mixed(id: Integer, { name: String, age: Integer = 0 }): String
          "\#{id}: \#{name}"
        end
      TRB
      input_file = File.join(tmpdir, "mixed_args.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      expect(result[:diagnostics]).to be_empty
      expect(result[:success]).to be true
    end

    it "parses interface reference style keyword arguments" do
      source = <<~TRB
        interface Options
          name: String
          limit?: Integer
        end

        def fetch({ name:, limit: 10 }: Options): String
          name
        end
      TRB
      input_file = File.join(tmpdir, "interface_ref.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      expect(result[:diagnostics]).to be_empty
      expect(result[:success]).to be true
    end

    it "parses double splat keyword arguments" do
      source = <<~TRB
        def forward(**opts: Hash): String
          opts.to_s
        end
      TRB
      input_file = File.join(tmpdir, "double_splat.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      expect(result[:diagnostics]).to be_empty
      expect(result[:success]).to be true
    end
  end

  describe "Unicode identifier support" do
    it "parses Korean function names" do
      source = <<~TRB
        def 인사하기(이름: String): String
          "안녕, \#{이름}!"
        end
      TRB
      input_file = File.join(tmpdir, "korean.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      expect(result[:diagnostics]).to be_empty
      expect(result[:success]).to be true
    end

    it "parses Korean function names with return type validation" do
      source = <<~TRB
        def 계산하기(값: Integer): Integer
          값 * 2
        end
      TRB
      input_file = File.join(tmpdir, "korean2.trb")
      File.write(input_file, source)

      result = compiler.compile_with_diagnostics(input_file)
      expect(result[:diagnostics]).to be_empty
      expect(result[:success]).to be true
    end
  end
end
