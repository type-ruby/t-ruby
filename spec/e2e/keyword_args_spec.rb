# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe "Keyword Arguments E2E" do
  let(:tmpdir) { Dir.mktmpdir("trb_keyword_args") }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  def create_config(lib_dir)
    File.write(File.join(tmpdir, "trbconfig.yml"), <<~YAML)
      emit:
        rb: true
        rbs: true
        dtrb: false
      paths:
        src: "#{lib_dir}"
        out: "#{lib_dir}"
        rbs: "#{lib_dir}"
    YAML

    config = TRuby::Config.new(File.join(tmpdir, "trbconfig.yml"))
    allow(config).to receive(:type_check?).and_return(false)
    config
  end

  def compile_and_read(lib_dir, filename, source)
    trb_path = File.join(lib_dir, "#{filename}.trb")
    rb_path = File.join(lib_dir, "#{filename}.rb")

    File.write(trb_path, source)

    config = create_config(lib_dir)
    compiler = TRuby::Compiler.new(config)
    compiler.compile(trb_path)

    File.read(rb_path)
  end

  describe "키워드 인자 (구조분해) - 인라인 타입" do
    it "필수 키워드 인자를 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        def greet({ name: String }): String
          "Hello, \#{name}!"
        end
      TRB

      result = compile_and_read(lib_dir, "greet", source)

      expect(result).to include("def greet(name:)")
      expect(result).not_to include("String")
      expect(result).to include('"Hello, #{name}!"')
    end

    it "여러 필수 키워드 인자를 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        def create_point({ x: Integer, y: Integer }): String
          "(\#{x}, \#{y})"
        end
      TRB

      result = compile_and_read(lib_dir, "point", source)

      expect(result).to include("def create_point(x:, y:)")
      expect(result).not_to include("Integer")
    end

    it "기본값이 있는 키워드 인자를 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        def greet_with_prefix({ name: String, prefix: String = "Hello" }): String
          "\#{prefix}, \#{name}!"
        end
      TRB

      result = compile_and_read(lib_dir, "greet_prefix", source)

      expect(result).to include('def greet_with_prefix(name:, prefix: "Hello")')
      expect(result).not_to include("String")
    end

    it "복잡한 타입과 기본값을 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        def process_data({ items: Array = [], options: Hash = {} }): Integer
          items.length
        end
      TRB

      result = compile_and_read(lib_dir, "process", source)

      expect(result).to include("def process_data(items: [], options: {})")
    end
  end

  describe "키워드 인자 (구조분해) - interface 참조" do
    it "interface 참조 키워드 인자를 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        interface UserParams
          name: String
          age: Integer
        end

        def create_user({ name:, age: }: UserParams): String
          "\#{name} (\#{age})"
        end
      TRB

      result = compile_and_read(lib_dir, "user", source)

      expect(result).to include("def create_user(name:, age:)")
      expect(result).not_to include("UserParams")
      expect(result).not_to include("interface")
    end

    it "기본값이 있는 interface 참조를 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        interface ConnectionOptions
          host: String
          port?: Integer
          timeout?: Integer
        end

        def connect({ host:, port: 8080, timeout: 30 }: ConnectionOptions): String
          "\#{host}:\#{port}"
        end
      TRB

      result = compile_and_read(lib_dir, "connect", source)

      expect(result).to include("def connect(host:, port: 8080, timeout: 30)")
    end
  end

  describe "더블 스플랫 (**opts: Type)" do
    it "더블 스플랫 인자를 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        interface LogOptions
          message: String
          level?: Symbol
        end

        def log(**kwargs: LogOptions): String
          kwargs[:message]
        end
      TRB

      result = compile_and_read(lib_dir, "log", source)

      expect(result).to include("def log(**kwargs)")
      expect(result).not_to include("LogOptions")
    end
  end

  describe "Hash 리터럴 (config: { ... })" do
    it "Hash 리터럴 파라미터를 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        def process_config(config: { host: String, port: Integer }): String
          "\#{config[:host]}:\#{config[:port]}"
        end
      TRB

      result = compile_and_read(lib_dir, "config", source)

      expect(result).to include("def process_config(config)")
      expect(result).not_to include("String")
      expect(result).not_to include("Integer")
    end
  end

  describe "위치 인자 + 키워드 인자 혼합" do
    it "위치 인자와 키워드 인자 혼합을 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        def format_name(name: String, { uppercase: Boolean = false }): String
          uppercase ? name.upcase : name
        end
      TRB

      result = compile_and_read(lib_dir, "format", source)

      expect(result).to include("def format_name(name, uppercase: false)")
      expect(result).not_to include("String")
      expect(result).not_to include("Boolean")
    end

    it "여러 위치 인자와 키워드 인자를 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        def calculate(a: Integer, b: Integer, { round: Boolean = false }): Integer
          result = a + b
          round ? result.round : result
        end
      TRB

      result = compile_and_read(lib_dir, "calc", source)

      expect(result).to include("def calculate(a, b, round: false)")
    end
  end

  describe "클래스 내부 메서드" do
    it "클래스 내 키워드 인자 메서드를 올바르게 컴파일" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        class ApiClient
          def initialize({ base_url: String, timeout: Integer = 30 })
            @base_url = base_url
            @timeout = timeout
          end

          def get({ path: String }): String
            "\#{@base_url}\#{path}"
          end
        end
      TRB

      result = compile_and_read(lib_dir, "api_client", source)

      expect(result).to include("def initialize(base_url:, timeout: 30)")
      expect(result).to include("def get(path:)")
      expect(result).not_to include("String")
      expect(result).not_to include("Integer")
    end
  end

  describe "기존 위치 인자 호환성" do
    it "기존 위치 인자 문법이 여전히 작동" do
      lib_dir = File.join(tmpdir, "lib")
      FileUtils.mkdir_p(lib_dir)

      source = <<~TRB
        def positional_args(name: String, age: Integer = 0): String
          "\#{name} (\#{age})"
        end
      TRB

      result = compile_and_read(lib_dir, "positional", source)

      expect(result).to include("def positional_args(name, age = 0)")
      expect(result).not_to include("String")
      expect(result).not_to include("Integer")
    end
  end
end
