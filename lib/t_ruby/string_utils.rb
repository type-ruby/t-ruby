# frozen_string_literal: true

module TRuby
  # 문자열 파싱을 위한 공통 유틸리티 모듈
  # 파서와 컴파일러에서 공유하는 중첩 괄호 처리 로직
  module StringUtils
    module_function

    # 중첩된 괄호를 고려하여 콤마로 문자열 분리
    # @param content [String] 분리할 문자열
    # @return [Array<String>] 분리된 문자열 배열
    def split_by_comma(content)
      result = []
      current = ""
      depth = 0

      content.each_char do |char|
        case char
        when "<", "[", "(", "{"
          depth += 1
          current += char
        when ">", "]", ")", "}"
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

      result << current.strip unless current.empty?
      result
    end

    # 타입과 기본값 분리: "String = 0" -> ["String", "0"]
    # 중첩된 괄호 내부의 = 는 무시
    # @param type_and_default [String] "Type = default" 형태의 문자열
    # @return [Array] [type_str, default_value] 또는 [type_str, nil]
    def split_type_and_default(type_and_default)
      depth = 0
      equals_pos = nil

      type_and_default.each_char.with_index do |char, i|
        case char
        when "<", "[", "(", "{"
          depth += 1
        when ">", "]", ")", "}"
          depth -= 1
        when "="
          if depth.zero?
            equals_pos = i
            break
          end
        end
      end

      if equals_pos
        type_str = type_and_default[0...equals_pos].strip
        default_value = type_and_default[(equals_pos + 1)..].strip
        [type_str, default_value]
      else
        [type_and_default, nil]
      end
    end

    # 기본값만 추출 (타입은 버림)
    # @param type_and_default [String] "Type = default" 형태의 문자열
    # @return [String, nil] 기본값 또는 nil
    def extract_default_value(type_and_default)
      _, default_value = split_type_and_default(type_and_default)
      default_value
    end
  end
end
