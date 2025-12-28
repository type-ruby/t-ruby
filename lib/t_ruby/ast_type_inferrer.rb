# frozen_string_literal: true

module TRuby
  # ASTTypeInferrer - TypeScript 스타일 정적 타입 추론 엔진
  # IR 노드를 순회하면서 타입을 추론하고 캐싱
  class ASTTypeInferrer
    # 리터럴 타입 매핑
    LITERAL_TYPE_MAP = {
      string: "String",
      integer: "Integer",
      float: "Float",
      boolean: "bool",
      symbol: "Symbol",
      nil: "nil",
      array: "Array[untyped]",
      hash: "Hash[untyped, untyped]",
    }.freeze

    # 산술 연산자 규칙 (피연산자 타입 → 결과 타입)
    ARITHMETIC_OPS = %w[+ - * / % **].freeze
    COMPARISON_OPS = %w[== != < > <= >= <=>].freeze
    LOGICAL_OPS = %w[&& ||].freeze

    # 내장 메서드 반환 타입
    BUILTIN_METHODS = {
      # String 메서드
      %w[String upcase] => "String",
      %w[String downcase] => "String",
      %w[String capitalize] => "String",
      %w[String reverse] => "String",
      %w[String strip] => "String",
      %w[String chomp] => "String",
      %w[String chop] => "String",
      %w[String gsub] => "String",
      %w[String sub] => "String",
      %w[String tr] => "String",
      %w[String to_s] => "String",
      %w[String to_str] => "String",
      %w[String to_sym] => "Symbol",
      %w[String to_i] => "Integer",
      %w[String to_f] => "Float",
      %w[String length] => "Integer",
      %w[String size] => "Integer",
      %w[String bytesize] => "Integer",
      %w[String empty?] => "bool",
      %w[String include?] => "bool",
      %w[String start_with?] => "bool",
      %w[String end_with?] => "bool",
      %w[String match?] => "bool",
      %w[String split] => "Array[String]",
      %w[String chars] => "Array[String]",
      %w[String bytes] => "Array[Integer]",
      %w[String lines] => "Array[String]",

      # Integer 메서드
      %w[Integer to_s] => "String",
      %w[Integer to_i] => "Integer",
      %w[Integer to_f] => "Float",
      %w[Integer abs] => "Integer",
      %w[Integer even?] => "bool",
      %w[Integer odd?] => "bool",
      %w[Integer zero?] => "bool",
      %w[Integer positive?] => "bool",
      %w[Integer negative?] => "bool",
      %w[Integer times] => "Integer",
      %w[Integer upto] => "Enumerator[Integer]",
      %w[Integer downto] => "Enumerator[Integer]",

      # Float 메서드
      %w[Float to_s] => "String",
      %w[Float to_i] => "Integer",
      %w[Float to_f] => "Float",
      %w[Float abs] => "Float",
      %w[Float ceil] => "Integer",
      %w[Float floor] => "Integer",
      %w[Float round] => "Integer",
      %w[Float truncate] => "Integer",
      %w[Float nan?] => "bool",
      %w[Float infinite?] => "Integer?",
      %w[Float finite?] => "bool",
      %w[Float zero?] => "bool",
      %w[Float positive?] => "bool",
      %w[Float negative?] => "bool",

      # Array 메서드
      %w[Array length] => "Integer",
      %w[Array size] => "Integer",
      %w[Array count] => "Integer",
      %w[Array empty?] => "bool",
      %w[Array any?] => "bool",
      %w[Array all?] => "bool",
      %w[Array none?] => "bool",
      %w[Array include?] => "bool",
      %w[Array reverse] => "Array[untyped]",
      %w[Array sort] => "Array[untyped]",
      %w[Array uniq] => "Array[untyped]",
      %w[Array compact] => "Array[untyped]",
      %w[Array flatten] => "Array[untyped]",
      %w[Array join] => "String",
      %w[Array to_s] => "String",
      %w[Array to_a] => "Array[untyped]",

      # Hash 메서드
      %w[Hash length] => "Integer",
      %w[Hash size] => "Integer",
      %w[Hash empty?] => "bool",
      %w[Hash key?] => "bool",
      %w[Hash has_key?] => "bool",
      %w[Hash value?] => "bool",
      %w[Hash has_value?] => "bool",
      %w[Hash include?] => "bool",
      %w[Hash keys] => "Array[untyped]",
      %w[Hash values] => "Array[untyped]",
      %w[Hash to_s] => "String",
      %w[Hash to_a] => "Array[untyped]",
      %w[Hash to_h] => "Hash[untyped, untyped]",

      # Object 메서드 (모든 타입에 적용)
      %w[Object to_s] => "String",
      %w[Object inspect] => "String",
      %w[Object class] => "Class",
      %w[Object is_a?] => "bool",
      %w[Object kind_of?] => "bool",
      %w[Object instance_of?] => "bool",
      %w[Object respond_to?] => "bool",
      %w[Object nil?] => "bool",
      %w[Object frozen?] => "bool",
      %w[Object dup] => "untyped",
      %w[Object clone] => "untyped",
      %w[Object freeze] => "self",
      %w[Object tap] => "self",
      %w[Object then] => "untyped",
      %w[Object yield_self] => "untyped",

      # Symbol 메서드
      %w[Symbol to_s] => "String",
      %w[Symbol to_sym] => "Symbol",
      %w[Symbol length] => "Integer",
      %w[Symbol size] => "Integer",
      %w[Symbol empty?] => "bool",
    }.freeze

    attr_reader :type_cache

    def initialize
      @type_cache = {} # 노드 → 타입 캐시 (TypeScript의 지연 평가)
    end

    # 표현식 타입 추론
    # @param node [IR::Node] IR 노드
    # @param env [TypeEnv] 타입 환경
    # @return [String, IR::TypeNode, nil] 추론된 타입
    def infer_expression(node, env)
      # 캐시 확인 (지연 평가)
      cache_key = node.object_id
      return @type_cache[cache_key] if @type_cache.key?(cache_key)

      type = case node
             when IR::Literal
               infer_literal(node)
             when IR::InterpolatedString
               "String" # Interpolated strings always produce String
             when IR::VariableRef
               infer_variable_ref(node, env)
             when IR::BinaryOp
               infer_binary_op(node, env)
             when IR::UnaryOp
               infer_unary_op(node, env)
             when IR::MethodCall
               infer_method_call(node, env)
             when IR::ArrayLiteral
               infer_array_literal(node, env)
             when IR::HashLiteral
               infer_hash_literal(node, env)
             when IR::Assignment
               infer_assignment(node, env)
             when IR::Conditional
               infer_conditional(node, env)
             when IR::Block
               infer_block(node, env)
             when IR::Return
               infer_return(node, env)
             when IR::RawCode
               "untyped"
             else
               "untyped"
             end

      @type_cache[cache_key] = type
      type
    end

    # 메서드 반환 타입 추론
    # @param method_node [IR::MethodDef] 메서드 정의 IR
    # @param class_env [TypeEnv, nil] 클래스 타입 환경
    # @return [String, IR::TypeNode, nil] 추론된 반환 타입
    def infer_method_return_type(method_node, class_env = nil)
      return nil unless method_node.body

      # 메서드 스코프 생성
      env = TypeEnv.new(class_env)

      # 파라미터 타입 등록
      method_node.params.each do |param|
        param_type = param.type_annotation&.to_rbs || "untyped"
        env.define(param.name, param_type)
      end

      # 본문에서 반환 타입 수집
      return_types, terminated = collect_return_types(method_node.body, env)

      # 암묵적 반환값 추론 (마지막 표현식) - 종료되지 않은 경우만
      unless terminated
        implicit_return = infer_implicit_return(method_node.body, env)
        return_types << implicit_return if implicit_return
      end

      # 타입 통합
      unify_types(return_types)
    end

    private

    # 리터럴 타입 추론
    def infer_literal(node)
      LITERAL_TYPE_MAP[node.literal_type] || "untyped"
    end

    # 변수 참조 타입 추론
    def infer_variable_ref(node, env)
      # 상수(클래스명)는 그 자체가 타입 (예: MyClass.new 호출 시)
      if node.scope == :constant || node.name.match?(/^[A-Z]/)
        return node.name
      end

      env.lookup(node.name) || "untyped"
    end

    # 이항 연산자 타입 추론
    def infer_binary_op(node, env)
      left_type = infer_expression(node.left, env)
      right_type = infer_expression(node.right, env)
      op = node.operator

      # 비교 연산자는 항상 bool
      return "bool" if COMPARISON_OPS.include?(op)

      # 논리 연산자
      if op == "&&"
        # && 는 falsy면 왼쪽, truthy면 오른쪽 반환
        return right_type # 단순화: 오른쪽 타입 반환
      end

      if op == "||"
        # || 는 truthy면 왼쪽, falsy면 오른쪽 반환
        return union_type(left_type, right_type)
      end

      # 산술 연산자
      if ARITHMETIC_OPS.include?(op)
        return infer_arithmetic_result(left_type, right_type, op)
      end

      "untyped"
    end

    # 산술 연산 결과 타입 추론
    def infer_arithmetic_result(left_type, right_type, op)
      left_base = base_type(left_type)
      right_base = base_type(right_type)

      # 문자열 연결
      if op == "+" && (left_base == "String" || right_base == "String")
        return "String"
      end

      # 숫자 연산
      if numeric_type?(left_base) && numeric_type?(right_base)
        # Float가 하나라도 있으면 Float
        return "Float" if left_base == "Float" || right_base == "Float"

        return "Integer"
      end

      # 배열 연결
      if op == "+" && left_base.start_with?("Array")
        return left_type
      end

      "untyped"
    end

    # 단항 연산자 타입 추론
    def infer_unary_op(node, env)
      operand_type = infer_expression(node.operand, env)

      case node.operator
      when "!"
        "bool"
      when "-"
        operand_type
      else
        "untyped"
      end
    end

    # 메서드 호출 타입 추론
    def infer_method_call(node, env)
      # receiver 타입 추론
      receiver_type = if node.receiver
                        infer_expression(node.receiver, env)
                      else
                        "Object"
                      end

      receiver_base = base_type(receiver_type)

      # 내장 메서드 조회
      method_key = [receiver_base, node.method_name]
      if BUILTIN_METHODS.key?(method_key)
        result = BUILTIN_METHODS[method_key]

        # self 반환인 경우 receiver 타입 반환
        return receiver_type if result == "self"

        return result
      end

      # Object 메서드 fallback
      object_key = ["Object", node.method_name]
      if BUILTIN_METHODS.key?(object_key)
        result = BUILTIN_METHODS[object_key]
        return receiver_type if result == "self"

        return result
      end

      # new 메서드는 클래스 인스턴스 반환
      if node.method_name == "new" && receiver_base.match?(/^[A-Z]/)
        return receiver_base
      end

      "untyped"
    end

    # 배열 리터럴 타입 추론
    def infer_array_literal(node, env)
      return "Array[untyped]" if node.elements.empty?

      element_types = node.elements.map { |e| infer_expression(e, env) }
      unified = unify_types(element_types)

      "Array[#{unified}]"
    end

    # 해시 리터럴 타입 추론
    def infer_hash_literal(node, env)
      return "Hash[untyped, untyped]" if node.pairs.empty?

      key_types = node.pairs.map { |p| infer_expression(p.key, env) }
      value_types = node.pairs.map { |p| infer_expression(p.value, env) }

      key_type = unify_types(key_types)
      value_type = unify_types(value_types)

      "Hash[#{key_type}, #{value_type}]"
    end

    # 대입 타입 추론 (변수 타입 업데이트 및 우변 타입 반환)
    def infer_assignment(node, env)
      value_type = infer_expression(node.value, env)

      # 변수 타입 등록
      target = node.target
      if target.start_with?("@") && !target.start_with?("@@")
        env.define_instance_var(target, value_type)
      elsif target.start_with?("@@")
        env.define_class_var(target, value_type)
      else
        env.define(target, value_type)
      end

      value_type
    end

    # 조건문 타입 추론 (then/else 브랜치 통합)
    def infer_conditional(node, env)
      then_type = infer_expression(node.then_branch, env) if node.then_branch
      else_type = infer_expression(node.else_branch, env) if node.else_branch

      types = [then_type, else_type].compact
      return "nil" if types.empty?

      unify_types(types)
    end

    # 블록 타입 추론 (마지막 문장의 타입)
    def infer_block(node, env)
      return "nil" if node.statements.empty?

      # 마지막 문장 타입 반환 (Ruby의 암묵적 반환)
      last_stmt = node.statements.last
      infer_expression(last_stmt, env)
    end

    # return 문 타입 추론
    def infer_return(node, env)
      return "nil" unless node.value

      infer_expression(node.value, env)
    end

    # 본문에서 모든 return 타입 수집
    # @return [Array<(Array<String>, Boolean)>] [수집된 타입들, 종료 여부]
    def collect_return_types(body, env)
      types = []

      terminated = collect_returns_recursive(body, env, types)

      [types, terminated]
    end

    # @return [Boolean] true if this node terminates (contains unconditional return)
    def collect_returns_recursive(node, env, types)
      case node
      when IR::Return
        type = node.value ? infer_expression(node.value, env) : "nil"
        types << type
        true # return은 항상 실행 흐름 종료
      when IR::Block
        node.statements.each do |stmt|
          terminated = collect_returns_recursive(stmt, env, types)
          return true if terminated # return 이후 코드는 unreachable
        end
        false
      when IR::Conditional
        then_terminated = node.then_branch ? collect_returns_recursive(node.then_branch, env, types) : false
        else_terminated = node.else_branch ? collect_returns_recursive(node.else_branch, env, types) : false
        # 모든 분기가 종료되어야 조건문 전체가 종료됨
        then_terminated && else_terminated
      else
        false
      end
    end

    # 암묵적 반환값 추론 (마지막 표현식)
    def infer_implicit_return(body, env)
      case body
      when IR::Block
        return nil if body.statements.empty?

        last_stmt = body.statements.last

        # return 문이면 이미 수집됨
        return nil if last_stmt.is_a?(IR::Return)

        infer_expression(last_stmt, env)
      else
        infer_expression(body, env)
      end
    end

    # 타입 통합 (여러 타입을 하나로)
    def unify_types(types)
      types = types.compact.uniq

      return "nil" if types.empty?
      return types.first if types.length == 1

      # nil과 다른 타입이 있으면 nullable
      if types.include?("nil") && types.length == 2
        other = types.find { |t| t != "nil" }
        return "#{other}?" if other
      end

      # 동일 기본 타입은 통합
      base_types = types.map { |t| base_type(t) }.uniq
      return types.first if base_types.length == 1

      # Union 타입 생성
      types.join(" | ")
    end

    # Union 타입 생성
    def union_type(type1, type2)
      return type2 if type1 == type2
      return type2 if type1 == "nil"
      return type1 if type2 == "nil"

      "#{type1} | #{type2}"
    end

    # 기본 타입 추출 (Generic에서)
    def base_type(type)
      return "untyped" if type.nil?

      type_str = type.is_a?(String) ? type : type.to_rbs

      # Array[X] → Array
      return ::Regexp.last_match(1) if type_str =~ /^(\w+)\[/

      # Nullable X? → X
      return type_str[0..-2] if type_str.end_with?("?")

      type_str
    end

    # 숫자 타입인지 확인
    def numeric_type?(type)
      %w[Integer Float Numeric].include?(type)
    end
  end
end
