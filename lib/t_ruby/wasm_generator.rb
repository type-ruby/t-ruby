# frozen_string_literal: true

module TRuby
  # WebAssembly code generator for T-Ruby IR
  # Compiles T-Ruby IR to WebAssembly Text Format (WAT) and binary (.wasm)
  class WASMGenerator < IR::Visitor
    # WASM type mappings from T-Ruby types
    WASM_TYPES = {
      "Integer" => "i64",
      "Float" => "f64",
      "Boolean" => "i32",  # 0 = false, 1 = true
      "String" => "i32",   # pointer to string in memory
      "void" => nil,
      "nil" => nil
    }.freeze

    # WASM operators for binary operations
    WASM_OPS = {
      "+" => { "i64" => "i64.add", "f64" => "f64.add" },
      "-" => { "i64" => "i64.sub", "f64" => "f64.sub" },
      "*" => { "i64" => "i64.mul", "f64" => "f64.mul" },
      "/" => { "i64" => "i64.div_s", "f64" => "f64.div" },
      "%" => { "i64" => "i64.rem_s" },
      "==" => { "i64" => "i64.eq", "f64" => "f64.eq", "i32" => "i32.eq" },
      "!=" => { "i64" => "i64.ne", "f64" => "f64.ne", "i32" => "i32.ne" },
      "<" => { "i64" => "i64.lt_s", "f64" => "f64.lt" },
      "<=" => { "i64" => "i64.le_s", "f64" => "f64.le" },
      ">" => { "i64" => "i64.gt_s", "f64" => "f64.gt" },
      ">=" => { "i64" => "i64.ge_s", "f64" => "f64.ge" },
      "&&" => { "i32" => "i32.and" },
      "||" => { "i32" => "i32.or" },
      "&" => { "i64" => "i64.and", "i32" => "i32.and" },
      "|" => { "i64" => "i64.or", "i32" => "i32.or" },
      "^" => { "i64" => "i64.xor", "i32" => "i32.xor" },
      "<<" => { "i64" => "i64.shl", "i32" => "i32.shl" },
      ">>" => { "i64" => "i64.shr_s", "i32" => "i32.shr_s" }
    }.freeze

    attr_reader :output, :errors, :warnings, :string_table

    def initialize(options = {})
      @output = []
      @indent = 0
      @errors = []
      @warnings = []
      @options = options

      # Runtime components
      @string_table = []      # String constants pool
      @memory_offset = 1024   # Start after reserved space
      @functions = {}         # Function signatures
      @locals = {}            # Current function locals
      @local_index = 0        # Current local variable index
      @export_all = options.fetch(:export_all, true)
      @include_runtime = options.fetch(:include_runtime, true)
    end

    # Generate WASM from IR program
    def generate(program)
      @output = []
      @errors = []
      @warnings = []
      @string_table = []
      @functions = {}

      # First pass: collect function signatures
      collect_function_signatures(program)

      # Generate module
      emit "(module"
      @indent += 1

      # Memory declaration (1 page = 64KB)
      emit ";; Memory: 1 page (64KB) for strings and data"
      emit "(memory (export \"memory\") 1)"
      emit ""

      # Runtime functions (if enabled)
      if @include_runtime
        emit_runtime_functions
      end

      # Visit all declarations
      visit(program)

      # String data section
      emit_string_data if @string_table.any?

      @indent -= 1
      emit ")"

      {
        wat: @output.join("\n"),
        errors: @errors,
        warnings: @warnings,
        string_table: @string_table,
        functions: @functions
      }
    end

    # Generate WAT string only
    def generate_wat(program)
      generate(program)[:wat]
    end

    # Compile to binary WASM using wat2wasm (if available)
    def compile_to_wasm(program, output_path)
      result = generate(program)
      wat_content = result[:wat]

      wat_path = output_path.sub(/\.wasm$/, ".wat")
      File.write(wat_path, wat_content)

      # Try to compile with wat2wasm
      if system("which wat2wasm > /dev/null 2>&1")
        success = system("wat2wasm #{wat_path} -o #{output_path}")
        unless success
          @errors << "Failed to compile WAT to WASM binary"
        end
      else
        @warnings << "wat2wasm not found. Only WAT file generated. Install wabt for binary output."
      end

      result.merge(wat_path: wat_path, wasm_path: output_path)
    end

    #==========================================================================
    # Visitor Methods
    #==========================================================================

    def visit_program(node)
      node.declarations.each do |decl|
        visit(decl)
        emit ""
      end
    end

    def visit_type_alias(node)
      emit ";; type #{node.name} = #{node.definition.to_trb}"
    end

    def visit_interface(node)
      emit ";; interface #{node.name}"
    end

    def visit_method_def(node)
      @locals = {}
      @local_index = 0

      # Build function signature
      params = node.params.map do |param|
        wasm_type = ruby_type_to_wasm(param.type_annotation)
        @locals[param.name] = { index: @local_index, type: wasm_type }
        @local_index += 1
        "(param $#{param.name} #{wasm_type})"
      end.join(" ")

      return_type = ruby_type_to_wasm(node.return_type)
      result = return_type ? "(result #{return_type})" : ""

      # Function definition
      export_clause = @export_all ? "(export \"#{node.name}\")" : ""
      emit "(func $#{node.name} #{export_clause} #{params} #{result}".strip

      @indent += 1

      # Emit local variable declarations
      emit_local_declarations(node)

      # Generate body
      if node.body
        visit(node.body)
      end

      @indent -= 1
      emit ")"
    end

    def visit_block(node)
      node.statements.each { |stmt| visit(stmt) }
    end

    def visit_assignment(node)
      target_name = node.target.to_s.sub(/^@/, "")

      # Check if it's a new local variable
      unless @locals[target_name]
        wasm_type = infer_wasm_type(node.value)
        @locals[target_name] = { index: @local_index, type: wasm_type }
        @local_index += 1
      end

      # Generate value
      visit_expression(node.value)

      # Store to local
      emit "local.set $#{target_name}"
    end

    def visit_return(node)
      if node.value
        visit_expression(node.value)
      end
      emit "return"
    end

    def visit_conditional(node)
      # Generate condition
      visit_expression(node.condition)

      if node.else_branch
        emit "(if"
        @indent += 1
        emit "(then"
        @indent += 1
        visit(node.then_branch)
        @indent -= 1
        emit ")"
        emit "(else"
        @indent += 1
        visit(node.else_branch)
        @indent -= 1
        emit ")"
        @indent -= 1
        emit ")"
      else
        emit "(if"
        @indent += 1
        emit "(then"
        @indent += 1
        visit(node.then_branch)
        @indent -= 1
        emit ")"
        @indent -= 1
        emit ")"
      end
    end

    def visit_loop(node)
      case node.kind
      when :while
        emit "(block $break"
        @indent += 1
        emit "(loop $continue"
        @indent += 1

        # Condition check
        visit_expression(node.condition)
        emit "i32.eqz"
        emit "br_if $break"

        # Body
        visit(node.body)
        emit "br $continue"

        @indent -= 1
        emit ")"
        @indent -= 1
        emit ")"

      when :until
        emit "(block $break"
        @indent += 1
        emit "(loop $continue"
        @indent += 1

        # Condition check (break if true)
        visit_expression(node.condition)
        emit "br_if $break"

        # Body
        visit(node.body)
        emit "br $continue"

        @indent -= 1
        emit ")"
        @indent -= 1
        emit ")"

      when :loop
        emit "(loop $continue"
        @indent += 1
        visit(node.body)
        emit "br $continue"
        @indent -= 1
        emit ")"
      end
    end

    def visit_for_loop(node)
      # For loops are desugared to while loops
      # for item in collection -> iterator pattern
      @warnings << "For loops have limited WASM support. Consider using while loops."
    end

    #==========================================================================
    # Expression Visitors
    #==========================================================================

    def visit_expression(node)
      case node
      when IR::Literal
        visit_literal(node)
      when IR::VariableRef
        visit_variable_ref(node)
      when IR::BinaryOp
        visit_binary_op(node)
      when IR::UnaryOp
        visit_unary_op(node)
      when IR::MethodCall
        visit_method_call(node)
      when IR::Conditional
        visit_conditional_expression(node)
      when IR::ArrayLiteral
        visit_array_literal(node)
      else
        @warnings << "Unsupported expression type: #{node.class}"
        emit "i64.const 0  ;; unsupported expression"
      end
    end

    def visit_literal(node)
      case node.literal_type
      when :integer, :int
        emit "i64.const #{node.value}"
      when :float
        emit "f64.const #{node.value}"
      when :boolean, :bool
        emit "i32.const #{node.value ? 1 : 0}"
      when :string
        # Add to string table and return pointer
        offset = add_string(node.value)
        emit "i32.const #{offset}  ;; string: #{node.value.inspect}"
      when :nil
        emit "i32.const 0  ;; nil"
      else
        emit "i64.const 0  ;; unknown literal type: #{node.literal_type}"
      end
    end

    def visit_variable_ref(node)
      name = node.name.to_s.sub(/^@/, "")
      if @locals[name]
        emit "local.get $#{name}"
      else
        @errors << "Undefined variable: #{name}"
        emit "i64.const 0  ;; undefined: #{name}"
      end
    end

    def visit_binary_op(node)
      left_type = infer_wasm_type(node.left)
      right_type = infer_wasm_type(node.right)
      wasm_type = left_type == "f64" || right_type == "f64" ? "f64" : "i64"

      # Handle comparison operators (return i32 boolean)
      is_comparison = %w[== != < <= > >=].include?(node.operator)
      is_logical = %w[&& ||].include?(node.operator)

      visit_expression(node.left)

      # Type conversion if needed for arithmetic
      if wasm_type == "f64" && left_type == "i64"
        emit "f64.convert_i64_s"
      end

      visit_expression(node.right)

      if wasm_type == "f64" && right_type == "i64"
        emit "f64.convert_i64_s"
      end

      op_type = is_comparison || is_logical ? (is_logical ? "i32" : wasm_type) : wasm_type
      wasm_op = WASM_OPS.dig(node.operator, op_type)

      if wasm_op
        emit wasm_op
      else
        @warnings << "Unsupported operator #{node.operator} for type #{wasm_type}"
        emit ";; unsupported: #{node.operator}"
      end
    end

    def visit_unary_op(node)
      case node.operator
      when "-"
        type = infer_wasm_type(node.operand)
        if type == "f64"
          visit_expression(node.operand)
          emit "f64.neg"
        else
          emit "i64.const 0"
          visit_expression(node.operand)
          emit "i64.sub"
        end
      when "!"
        visit_expression(node.operand)
        emit "i32.eqz"
      when "~"
        emit "i64.const -1"
        visit_expression(node.operand)
        emit "i64.xor"
      else
        @warnings << "Unsupported unary operator: #{node.operator}"
        visit_expression(node.operand)
      end
    end

    def visit_method_call(node)
      # Check if it's a known function
      if @functions[node.method_name]
        # Push arguments
        node.arguments.each do |arg|
          visit_expression(arg)
        end
        emit "call $#{node.method_name}"
      elsif node.receiver
        # Method call on object - limited support
        @warnings << "Object method calls have limited WASM support: #{node.method_name}"
        emit "i64.const 0  ;; method call: #{node.method_name}"
      else
        @errors << "Unknown function: #{node.method_name}"
        emit "i64.const 0  ;; unknown: #{node.method_name}"
      end
    end

    def visit_conditional_expression(node)
      # Ternary expression: condition ? then : else
      visit_expression(node.condition)
      emit "(if (result i64)"
      @indent += 1
      emit "(then"
      @indent += 1
      visit_expression(node.then_branch)
      @indent -= 1
      emit ")"
      emit "(else"
      @indent += 1
      if node.else_branch
        visit_expression(node.else_branch)
      else
        emit "i64.const 0"
      end
      @indent -= 1
      emit ")"
      @indent -= 1
      emit ")"
    end

    def visit_array_literal(node)
      # Arrays need memory allocation - simplified implementation
      @warnings << "Array literals have limited WASM support"
      emit "i32.const 0  ;; array placeholder"
    end

    private

    #==========================================================================
    # Helper Methods
    #==========================================================================

    def emit(text)
      @output << ("  " * @indent + text)
    end

    def ruby_type_to_wasm(type_node)
      return "i64" unless type_node

      case type_node
      when IR::SimpleType
        WASM_TYPES[type_node.name] || "i64"
      when IR::NullableType
        ruby_type_to_wasm(type_node.inner_type)
      when IR::UnionType
        # Use the first non-nil type
        non_nil = type_node.types.find { |t| t.to_trb != "nil" }
        non_nil ? ruby_type_to_wasm(non_nil) : "i32"
      when IR::GenericType
        case type_node.base
        when "Array", "Hash", "Map" then "i32"  # pointer
        else "i64"
        end
      when IR::FunctionType
        "i32"  # function reference
      else
        "i64"
      end
    end

    def infer_wasm_type(node)
      case node
      when IR::Literal
        case node.literal_type
        when :integer, :int then "i64"
        when :float then "f64"
        when :boolean, :bool then "i32"
        when :string then "i32"
        else "i64"
        end
      when IR::VariableRef
        name = node.name.to_s.sub(/^@/, "")
        @locals[name]&.dig(:type) || "i64"
      when IR::BinaryOp
        left = infer_wasm_type(node.left)
        right = infer_wasm_type(node.right)
        return "i32" if %w[== != < <= > >= && ||].include?(node.operator)
        left == "f64" || right == "f64" ? "f64" : "i64"
      when IR::MethodCall
        @functions[node.method_name]&.dig(:return_type) || "i64"
      else
        "i64"
      end
    end

    def collect_function_signatures(program)
      program.declarations.each do |decl|
        if decl.is_a?(IR::MethodDef)
          params = decl.params.map do |p|
            { name: p.name, type: ruby_type_to_wasm(p.type_annotation) }
          end
          @functions[decl.name] = {
            params: params,
            return_type: ruby_type_to_wasm(decl.return_type)
          }
        end
      end
    end

    def emit_local_declarations(method_node)
      # Collect all local variables from the body
      locals_to_declare = []

      if method_node.body
        collect_locals(method_node.body, locals_to_declare)
      end

      # Emit declarations for locals not in params
      param_names = method_node.params.map(&:name)
      locals_to_declare.uniq.each do |name|
        next if param_names.include?(name)
        next if @locals[name]

        wasm_type = "i64"  # default type
        @locals[name] = { index: @local_index, type: wasm_type }
        @local_index += 1
        emit "(local $#{name} #{wasm_type})"
      end
    end

    def collect_locals(node, locals)
      case node
      when IR::Assignment
        target = node.target.to_s.sub(/^@/, "")
        locals << target unless target.start_with?("@")
        collect_locals(node.value, locals)
      when IR::Block
        node.statements.each { |s| collect_locals(s, locals) }
      when IR::Conditional
        collect_locals(node.then_branch, locals) if node.then_branch
        collect_locals(node.else_branch, locals) if node.else_branch
      when IR::Loop
        collect_locals(node.body, locals) if node.body
      end
    end

    def add_string(str)
      offset = @memory_offset
      @string_table << { offset: offset, value: str }
      @memory_offset += str.bytesize + 1  # +1 for null terminator
      offset
    end

    def emit_string_data
      return if @string_table.empty?

      emit ""
      emit ";; String constants"
      @string_table.each do |entry|
        escaped = entry[:value].bytes.map { |b| "\\#{b.to_s(16).rjust(2, '0')}" }.join
        emit "(data (i32.const #{entry[:offset]}) \"#{escaped}\\00\")"
      end
    end

    def emit_runtime_functions
      emit ";; ============================================"
      emit ";; T-Ruby WASM Runtime Functions"
      emit ";; ============================================"
      emit ""

      # Print integer (for debugging)
      emit ";; Import console.log for debugging"
      emit "(import \"console\" \"log\" (func $console_log (param i64)))"
      emit "(import \"console\" \"log_str\" (func $console_log_str (param i32 i32)))"
      emit ""

      # Helper: puts for integer
      emit ";; puts(value: Integer) -> prints to console"
      emit "(func $puts_i64 (export \"puts_i64\") (param $value i64)"
      emit "  local.get $value"
      emit "  call $console_log"
      emit ")"
      emit ""

      # Helper: absolute value
      emit ";; abs(x: Integer) -> Integer"
      emit "(func $abs (export \"abs\") (param $x i64) (result i64)"
      emit "  local.get $x"
      emit "  i64.const 0"
      emit "  i64.lt_s"
      emit "  (if (result i64)"
      emit "    (then"
      emit "      i64.const 0"
      emit "      local.get $x"
      emit "      i64.sub"
      emit "    )"
      emit "    (else"
      emit "      local.get $x"
      emit "    )"
      emit "  )"
      emit ")"
      emit ""

      # Helper: min
      emit ";; min(a: Integer, b: Integer) -> Integer"
      emit "(func $min (export \"min\") (param $a i64) (param $b i64) (result i64)"
      emit "  local.get $a"
      emit "  local.get $b"
      emit "  i64.lt_s"
      emit "  (if (result i64)"
      emit "    (then local.get $a)"
      emit "    (else local.get $b)"
      emit "  )"
      emit ")"
      emit ""

      # Helper: max
      emit ";; max(a: Integer, b: Integer) -> Integer"
      emit "(func $max (export \"max\") (param $a i64) (param $b i64) (result i64)"
      emit "  local.get $a"
      emit "  local.get $b"
      emit "  i64.gt_s"
      emit "  (if (result i64)"
      emit "    (then local.get $a)"
      emit "    (else local.get $b)"
      emit "  )"
      emit ")"
      emit ""

      emit ";; ============================================"
      emit ""
    end
  end

  # WASM Compilation Result
  class WASMResult
    attr_reader :wat, :wasm_path, :wat_path, :errors, :warnings, :functions

    def initialize(result_hash)
      @wat = result_hash[:wat]
      @wasm_path = result_hash[:wasm_path]
      @wat_path = result_hash[:wat_path]
      @errors = result_hash[:errors] || []
      @warnings = result_hash[:warnings] || []
      @functions = result_hash[:functions] || {}
    end

    def success?
      @errors.empty?
    end

    def exported_functions
      @functions.keys
    end
  end
end
