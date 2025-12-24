# frozen_string_literal: true

module TRuby
  # BodyParser - T-Ruby 메서드 본문을 IR 노드로 변환
  # Prism은 순수 Ruby만 파싱하므로, T-Ruby 타입 어노테이션을 포함한
  # 메서드 본문을 파싱하기 위해 자체 구현
  class BodyParser
    # 메서드 본문을 IR::Block으로 변환
    # @param lines [Array<String>] 전체 소스 라인 배열
    # @param start_line [Integer] 메서드 본문 시작 라인 (0-indexed)
    # @param end_line [Integer] 메서드 본문 끝 라인 (exclusive)
    # @return [IR::Block] 본문을 표현하는 IR 블록
    def parse(lines, start_line, end_line)
      statements = []
      i = start_line

      while i < end_line
        line = lines[i]
        stripped = line.strip

        # 빈 줄이나 주석은 건너뛰기
        if stripped.empty? || stripped.start_with?("#")
          i += 1
          next
        end

        # if/unless 조건문 처리
        if stripped.match?(/^(if|unless)\s+/)
          node, next_i = parse_conditional(lines, i, end_line)
          if node
            statements << node
            i = next_i
            next
          end
        end

        node = parse_statement(stripped, i)
        statements << node if node
        i += 1
      end

      IR::Block.new(statements: statements)
    end

    # if/unless/elsif 조건문 파싱
    # @return [Array(IR::Conditional, Integer)] 조건문 노드와 다음 라인 인덱스
    def parse_conditional(lines, start_line, block_end)
      line = lines[start_line].strip
      match = line.match(/^(if|unless|elsif)\s+(.+)$/)
      return [nil, start_line] unless match

      # elsif는 내부적으로 if처럼 처리
      kind = match[1] == "elsif" ? :if : match[1].to_sym
      condition = parse_expression(match[2])

      # then/elsif/else/end 블록 찾기
      then_statements = []
      else_statements = []
      current_branch = :then
      depth = 1
      i = start_line + 1

      while i < block_end && depth.positive?
        current_line = lines[i].strip

        if current_line.match?(/^(if|unless|case|while|until|for|begin)\b/)
          depth += 1
          if current_branch == :then
            then_statements << IR::RawCode.new(code: current_line)
          else
            else_statements << IR::RawCode.new(code: current_line)
          end
        elsif current_line == "end"
          depth -= 1
          break if depth.zero?
        elsif depth == 1 && current_line.match?(/^elsif\s+/)
          # elsif는 중첩된 if로 처리
          nested_cond, next_i = parse_conditional(lines, i, block_end)
          else_statements << nested_cond if nested_cond
          i = next_i
          break
        elsif depth == 1 && current_line == "else"
          current_branch = :else
        elsif !current_line.empty? && !current_line.start_with?("#")
          node = parse_statement(current_line, i)
          next unless node

          if current_branch == :then
            then_statements << node
          else
            else_statements << node
          end
        end

        i += 1
      end

      then_block = IR::Block.new(statements: then_statements)
      else_block = else_statements.empty? ? nil : IR::Block.new(statements: else_statements)

      conditional = IR::Conditional.new(
        condition: condition,
        then_branch: then_block,
        else_branch: else_block,
        kind: kind,
        location: start_line
      )

      [conditional, i + 1]
    end

    private

    # 단일 문장 파싱
    def parse_statement(line, line_num)
      case line
      # return 문
      when /^return\s+(.+)$/
        IR::Return.new(
          value: parse_expression(::Regexp.last_match(1).strip),
          location: line_num
        )
      when /^return\s*$/
        IR::Return.new(value: nil, location: line_num)

      # 인스턴스 변수 할당: @name = value (== 제외)
      when /^@(\w+)\s*=(?!=)\s*(.+)$/
        IR::Assignment.new(
          target: "@#{::Regexp.last_match(1)}",
          value: parse_expression(::Regexp.last_match(2).strip),
          location: line_num
        )

      # 지역 변수 할당: name = value (==, != 제외)
      when /^(\w+)\s*=(?!=)\s*(.+)$/
        IR::Assignment.new(
          target: ::Regexp.last_match(1),
          value: parse_expression(::Regexp.last_match(2).strip),
          location: line_num
        )

      # 그 외는 표현식 (암묵적 반환값 가능)
      else
        parse_expression(line)
      end
    end

    # 표현식 파싱
    def parse_expression(expr)
      return nil if expr.nil? || expr.empty?

      expr = expr.strip

      # 리터럴 파싱 시도
      result = parse_literal(expr)
      return result if result

      # 복합 표현식 파싱 시도
      result = parse_compound_expression(expr)
      return result if result

      # 연산자 파싱 시도
      result = parse_operators(expr)
      return result if result

      # 변수 참조 파싱 시도
      result = parse_variable_ref(expr)
      return result if result

      # 파싱할 수 없는 경우 RawCode로 래핑
      IR::RawCode.new(code: expr)
    end

    # 리터럴 파싱 (문자열, 숫자, 심볼, 부울, nil)
    def parse_literal(expr)
      # 문자열 리터럴 (쌍따옴표)
      return parse_string_literal(expr) if expr.match?(/^".*"$/)

      # 문자열 리터럴 (홑따옴표)
      if expr.match?(/^'.*'$/)
        return IR::Literal.new(value: expr[1..-2], literal_type: :string)
      end

      # 심볼 리터럴
      if (match = expr.match(/^:(\w+)$/))
        return IR::Literal.new(value: match[1].to_sym, literal_type: :symbol)
      end

      # nil/부울 리터럴
      return IR::Literal.new(value: nil, literal_type: :nil) if expr == "nil"
      return IR::Literal.new(value: true, literal_type: :boolean) if expr == "true"
      return IR::Literal.new(value: false, literal_type: :boolean) if expr == "false"

      # 부동소수점 리터럴
      if (match = expr.match(/^(-?\d+\.\d+)$/))
        return IR::Literal.new(value: match[1].to_f, literal_type: :float)
      end

      # 정수 리터럴
      if (match = expr.match(/^(-?\d+)$/))
        return IR::Literal.new(value: match[1].to_i, literal_type: :integer)
      end

      nil
    end

    # 복합 표현식 파싱 (배열, 해시, 괄호, 메서드 호출)
    def parse_compound_expression(expr)
      # 배열 리터럴
      return parse_array_literal(expr) if expr.start_with?("[") && expr.end_with?("]")

      # 해시 리터럴
      return parse_hash_literal(expr) if expr.start_with?("{") && expr.end_with?("}")

      # 괄호로 감싼 표현식
      return parse_expression(expr[1..-2]) if expr.start_with?("(") && expr.end_with?(")")

      # 메서드 호출
      parse_method_call(expr)
    end

    # 연산자 파싱 (이항, 단항)
    def parse_operators(expr)
      # 논리 연산자 (낮은 우선순위)
      result = parse_binary_op(expr, ["||", "&&"])
      return result if result

      # 비교 연산자
      result = parse_binary_op(expr, ["==", "!=", "<=", ">=", "<=>", "<", ">"])
      return result if result

      # 산술 연산자 (낮은 우선순위부터)
      result = parse_binary_op(expr, ["+", "-"])
      return result if result

      result = parse_binary_op(expr, ["*", "/", "%"])
      return result if result

      result = parse_binary_op(expr, ["**"])
      return result if result

      # 단항 연산자
      parse_unary_op(expr)
    end

    # 단항 연산자 파싱
    def parse_unary_op(expr)
      if expr.start_with?("!")
        return IR::UnaryOp.new(operator: "!", operand: parse_expression(expr[1..]))
      end

      if expr.start_with?("-") && !expr.match?(/^-\d/)
        return IR::UnaryOp.new(operator: "-", operand: parse_expression(expr[1..]))
      end

      nil
    end

    # 변수 참조 파싱 (인스턴스, 클래스, 전역, 지역, 상수)
    def parse_variable_ref(expr)
      # 인스턴스 변수 참조
      if (match = expr.match(/^@(\w+)$/))
        return IR::VariableRef.new(name: "@#{match[1]}", scope: :instance)
      end

      # 클래스 변수 참조
      if (match = expr.match(/^@@(\w+)$/))
        return IR::VariableRef.new(name: "@@#{match[1]}", scope: :class)
      end

      # 전역 변수 참조
      if (match = expr.match(/^\$(\w+)$/))
        return IR::VariableRef.new(name: "$#{match[1]}", scope: :global)
      end

      # 지역 변수 또는 상수
      if (match = expr.match(/^(\w+)$/))
        name = match[1]
        scope = name.match?(/^[A-Z]/) ? :constant : :local
        return IR::VariableRef.new(name: name, scope: scope)
      end

      nil
    end

    # 문자열 보간 처리
    def parse_string_literal(expr)
      content = expr[1..-2] # 따옴표 제거

      # 보간이 있는지 확인
      if content.include?('#{')
        # 보간이 있으면 보간 표현식들을 추출
        parts = []
        remaining = content

        while (match = remaining.match(/#\{([^}]+)\}/))
          # 보간 이전의 문자열 부분
          unless match.pre_match.empty?
            parts << IR::Literal.new(value: match.pre_match, literal_type: :string)
          end

          # 보간 표현식
          interpolated_expr = parse_expression(match[1])
          parts << IR::MethodCall.new(
            receiver: interpolated_expr,
            method_name: "to_s",
            arguments: []
          )

          remaining = match.post_match
        end

        # 남은 문자열 부분
        unless remaining.empty?
          parts << IR::Literal.new(value: remaining, literal_type: :string)
        end

        # 여러 부분이면 + 연산으로 연결
        if parts.length == 1
          parts.first
        else
          result = parts.first
          parts[1..].each do |part|
            result = IR::BinaryOp.new(operator: "+", left: result, right: part)
          end
          result
        end
      else
        # 보간 없음
        IR::Literal.new(value: content, literal_type: :string)
      end
    end

    # 배열 리터럴 파싱
    def parse_array_literal(expr)
      content = expr[1..-2].strip # 괄호 제거
      return IR::ArrayLiteral.new(elements: []) if content.empty?

      elements = split_by_comma(content).map { |e| parse_expression(e.strip) }
      IR::ArrayLiteral.new(elements: elements)
    end

    # 해시 리터럴 파싱
    def parse_hash_literal(expr)
      content = expr[1..-2].strip # 중괄호 제거
      return IR::HashLiteral.new(pairs: []) if content.empty?

      pairs = []
      items = split_by_comma(content)

      items.each do |item|
        item = item.strip

        # symbol: value 형태
        if (match = item.match(/^(\w+):\s*(.+)$/))
          key = IR::Literal.new(value: match[1].to_sym, literal_type: :symbol)
          value = parse_expression(match[2].strip)
          pairs << IR::HashPair.new(key: key, value: value)

        # key => value 형태
        elsif (match = item.match(/^(.+?)\s*=>\s*(.+)$/))
          key = parse_expression(match[1].strip)
          value = parse_expression(match[2].strip)
          pairs << IR::HashPair.new(key: key, value: value)
        end
      end

      IR::HashLiteral.new(pairs: pairs)
    end

    # 이항 연산자 파싱 (우선순위 고려)
    def parse_binary_op(expr, operators)
      # 연산자를 찾되, 괄호/배열/해시/문자열 내부는 제외
      depth = 0
      in_string = false
      string_char = nil
      i = expr.length - 1

      # 오른쪽에서 왼쪽으로 검색 (왼쪽 결합)
      while i >= 0
        char = expr[i]

        # 문자열 처리
        if !in_string && ['"', "'"].include?(char)
          in_string = true
          string_char = char
        elsif in_string && char == string_char && (i.zero? || expr[i - 1] != "\\")
          in_string = false
          string_char = nil
        end

        unless in_string
          case char
          when ")", "]", "}"
            depth += 1
          when "(", "[", "{"
            depth -= 1
          end

          if depth.zero?
            operators.each do |op|
              op_start = i - op.length + 1
              next if op_start.negative?

              next unless expr[op_start, op.length] == op

              # 연산자 앞뒤에 피연산자가 있는지 확인
              left_part = expr[0...op_start].strip
              right_part = expr[(i + 1)..].strip

              next if left_part.empty? || right_part.empty?

              # 음수 처리: - 앞에 연산자가 있으면 단항 연산자
              if op == "-"
                prev_char = left_part[-1]
                next if prev_char && ["+", "-", "*", "/", "%", "(", ",", "=", "<", ">", "!"].include?(prev_char)
              end

              return IR::BinaryOp.new(
                operator: op,
                left: parse_expression(left_part),
                right: parse_expression(right_part)
              )
            end
          end
        end

        i -= 1
      end

      nil
    end

    # 메서드 호출 파싱
    def parse_method_call(expr)
      # receiver.method(args) 패턴
      # 또는 method(args) 패턴
      # 또는 receiver.method 패턴

      depth = 0
      in_string = false
      string_char = nil
      last_dot = nil

      # 마지막 점 위치 찾기 (문자열/괄호 밖에서)
      i = expr.length - 1
      while i >= 0
        char = expr[i]

        if !in_string && ['"', "'"].include?(char)
          in_string = true
          string_char = char
        elsif in_string && char == string_char && (i.zero? || expr[i - 1] != "\\")
          in_string = false
          string_char = nil
        end

        unless in_string
          case char
          when ")", "]", "}"
            depth += 1
          when "(", "[", "{"
            depth -= 1
          when "."
            if depth.zero?
              last_dot = i
              break
            end
          end
        end

        i -= 1
      end

      if last_dot
        receiver_str = expr[0...last_dot]
        method_part = expr[(last_dot + 1)..]

        # method_part에서 메서드 이름과 인자 분리
        if (match = method_part.match(/^([\w?!]+)\s*\((.*)?\)$/))
          method_name = match[1]
          args_str = match[2] || ""
          arguments = args_str.empty? ? [] : split_by_comma(args_str).map { |a| parse_expression(a.strip) }

          return IR::MethodCall.new(
            receiver: parse_expression(receiver_str),
            method_name: method_name,
            arguments: arguments
          )
        elsif (match = method_part.match(/^([\w?!]+)$/))
          # 인자 없는 메서드 호출
          return IR::MethodCall.new(
            receiver: parse_expression(receiver_str),
            method_name: match[1],
            arguments: []
          )
        end
      elsif (match = expr.match(/^([\w?!]+)\s*\((.*)?\)$/))
        # receiver 없는 메서드 호출: method(args)
        method_name = match[1]
        args_str = match[2] || ""

        # 내장 메서드가 아니면 nil
        # (puts, print, p 등 최상위 메서드)
        arguments = args_str.empty? ? [] : split_by_comma(args_str).map { |a| parse_expression(a.strip) }

        return IR::MethodCall.new(
          receiver: nil,
          method_name: method_name,
          arguments: arguments
        )
      end

      nil
    end

    # 쉼표로 분리 (괄호/배열/해시/문자열 내부는 제외)
    def split_by_comma(str)
      result = []
      current = ""
      depth = 0
      in_string = false
      string_char = nil

      str.each_char do |char|
        if !in_string && ['"', "'"].include?(char)
          in_string = true
          string_char = char
          current += char
        elsif in_string && char == string_char
          in_string = false
          string_char = nil
          current += char
        elsif in_string
          current += char
        else
          case char
          when "(", "[", "{"
            depth += 1
            current += char
          when ")", "]", "}"
            depth -= 1
            current += char
          when ","
            if depth.zero?
              result << current.strip
              current = ""
            else
              current += char
            end
          else
            current += char
          end
        end
      end

      result << current.strip unless current.strip.empty?
      result
    end
  end
end
