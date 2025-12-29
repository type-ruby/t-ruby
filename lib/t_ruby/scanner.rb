# frozen_string_literal: true

module TRuby
  # Scanner - T-Ruby 소스 코드를 토큰 스트림으로 변환
  # TypeScript 컴파일러와 유사한 구조로, 파서와 분리되어 증분 파싱을 지원
  class Scanner
    # 토큰 구조체
    Token = Struct.new(:type, :value, :start_pos, :end_pos, :line, :column)

    # 스캔 에러
    class ScanError < StandardError
      attr_reader :line, :column, :position

      def initialize(message, line:, column:, position:)
        @line = line
        @column = column
        @position = position
        super("#{message} at line #{line}, column #{column}")
      end
    end

    # 키워드 맵
    KEYWORDS = {
      "def" => :def,
      "end" => :end,
      "class" => :class,
      "module" => :module,
      "if" => :if,
      "unless" => :unless,
      "else" => :else,
      "elsif" => :elsif,
      "return" => :return,
      "type" => :type,
      "interface" => :interface,
      "public" => :public,
      "private" => :private,
      "protected" => :protected,
      "true" => true,
      "false" => false,
      "nil" => :nil,
      "while" => :while,
      "until" => :until,
      "for" => :for,
      "do" => :do,
      "begin" => :begin,
      "rescue" => :rescue,
      "ensure" => :ensure,
      "case" => :case,
      "when" => :when,
      "then" => :then,
      "and" => :and,
      "or" => :or,
      "not" => :not,
      "in" => :in,
      "self" => :self,
      "super" => :super,
      "yield" => :yield,
      "break" => :break,
      "next" => :next,
      "redo" => :redo,
      "retry" => :retry,
      "raise" => :raise,
      "alias" => :alias,
      "defined?" => :defined,
      "__FILE__" => :__file__,
      "__LINE__" => :__line__,
      "__ENCODING__" => :__encoding__,
    }.freeze

    def initialize(source)
      @source = source
      @position = 0
      @line = 1
      @column = 1
      @tokens = []
      @token_index = 0
      @scanned = false
    end

    # 전체 토큰화 (캐싱용)
    def scan_all
      return @tokens if @scanned

      @tokens = []
      @position = 0
      @line = 1
      @column = 1

      while @position < @source.length
        token = scan_token
        @tokens << token if token
      end

      @tokens << Token.new(:eof, "", @position, @position, @line, @column)
      @scanned = true
      @tokens
    end

    # 단일 토큰 반환 (스트리밍용)
    def next_token
      scan_all unless @scanned

      token = @tokens[@token_index]
      @token_index += 1 unless token&.type == :eof
      token || @tokens.last
    end

    # lookahead
    def peek(n = 1)
      scan_all unless @scanned

      if n == 1
        @tokens[@token_index] || @tokens.last
      else
        @tokens[@token_index, n] || [@tokens.last]
      end
    end

    # 토큰 인덱스 리셋
    def reset
      @token_index = 0
    end

    private

    def scan_token
      skip_whitespace

      return nil if @position >= @source.length

      start_pos = @position
      start_line = @line
      start_column = @column
      char = current_char

      case char
      when "\n"
        scan_newline
      when "#"
        scan_comment
      when '"'
        scan_double_quoted_string
      when "'"
        scan_single_quoted_string
      when ":"
        scan_colon_or_symbol
      when "@"
        scan_instance_or_class_variable
      when "$"
        scan_global_variable
      when /[a-z_\p{L}]/i
        scan_identifier_or_keyword
      when /[0-9]/
        scan_number
      when "<"
        scan_less_than_or_heredoc
      when ">"
        scan_greater_than
      when "="
        scan_equals
      when "!"
        scan_bang
      when "&"
        scan_ampersand
      when "|"
        scan_pipe
      when "+"
        scan_plus
      when "-"
        scan_minus_or_arrow
      when "*"
        scan_star
      when "/"
        scan_slash
      when "%"
        scan_percent
      when "?"
        advance
        Token.new(:question, "?", start_pos, @position, start_line, start_column)
      when "("
        advance
        Token.new(:lparen, "(", start_pos, @position, start_line, start_column)
      when ")"
        advance
        Token.new(:rparen, ")", start_pos, @position, start_line, start_column)
      when "["
        advance
        Token.new(:lbracket, "[", start_pos, @position, start_line, start_column)
      when "]"
        advance
        Token.new(:rbracket, "]", start_pos, @position, start_line, start_column)
      when "{"
        advance
        Token.new(:lbrace, "{", start_pos, @position, start_line, start_column)
      when "}"
        advance
        Token.new(:rbrace, "}", start_pos, @position, start_line, start_column)
      when ","
        advance
        Token.new(:comma, ",", start_pos, @position, start_line, start_column)
      when "."
        advance
        Token.new(:dot, ".", start_pos, @position, start_line, start_column)
      else
        raise ScanError.new(
          "Unexpected character '#{char}'",
          line: start_line,
          column: start_column,
          position: start_pos
        )
      end
    end

    def scan_newline
      start_pos = @position
      start_line = @line
      start_column = @column

      advance
      @line += 1
      @column = 1

      Token.new(:newline, "\n", start_pos, @position, start_line, start_column)
    end

    def scan_comment
      start_pos = @position
      start_line = @line
      start_column = @column

      value = ""
      while @position < @source.length && current_char != "\n"
        value += current_char
        advance
      end

      Token.new(:comment, value, start_pos, @position, start_line, start_column)
    end

    def scan_double_quoted_string
      start_pos = @position
      start_line = @line
      start_column = @column

      # 보간이 있는지 확인을 위해 먼저 스캔
      advance # skip opening "

      has_interpolation = false
      temp_pos = @position
      while temp_pos < @source.length
        c = @source[temp_pos]
        break if c == '"' && (temp_pos == @position || @source[temp_pos - 1] != "\\")

        if c == "#" && temp_pos + 1 < @source.length && @source[temp_pos + 1] == "{"
          has_interpolation = true
          break
        end
        temp_pos += 1
      end

      @position = start_pos + 1 # reset to after opening "

      if has_interpolation
        scan_interpolated_string(start_pos, start_line, start_column)
      else
        scan_simple_string(start_pos, start_line, start_column, '"')
      end
    end

    def scan_interpolated_string(start_pos, start_line, start_column)
      # string_start 토큰 반환
      @tokens << Token.new(:string_start, '"', start_pos, start_pos + 1, start_line, start_column)

      content = ""
      content_start = @position
      content_line = @line
      content_column = @column

      while @position < @source.length
        char = current_char

        if char == '"'
          # 문자열 끝
          if content.length.positive?
            @tokens << Token.new(:string_content, content, content_start, @position, content_line, content_column)
          end
          advance
          return Token.new(:string_end, '"', @position - 1, @position, @line, @column - 1)
        elsif char == "\\" && peek_char
          # 이스케이프 시퀀스
          content += char
          advance
          content += current_char if @position < @source.length
          advance
        elsif char == "#" && peek_char == "{"
          # 보간 시작
          if content.length.positive?
            @tokens << Token.new(:string_content, content, content_start, @position, content_line, content_column)
            content = ""
          end

          interp_start = @position
          advance # skip #
          advance # skip {
          @tokens << Token.new(:interpolation_start, '#{', interp_start, @position, @line, @column - 2)

          # 보간 내부 토큰 스캔 (중첩된 {} 고려)
          scan_interpolation_content

          content_start = @position
          content_line = @line
          content_column = @column
        else
          content += char
          advance
        end
      end

      raise ScanError.new(
        "Unterminated string",
        line: start_line,
        column: start_column,
        position: start_pos
      )
    end

    def scan_interpolation_content
      depth = 1

      while @position < @source.length && depth.positive?
        skip_whitespace_in_interpolation

        break if @position >= @source.length

        char = current_char

        if char == "}"
          depth -= 1
          if depth.zero?
            interp_end_pos = @position
            advance
            @tokens << Token.new(:interpolation_end, "}", interp_end_pos, @position, @line, @column - 1)
            return
          end
        elsif char == "{"
          depth += 1
        end

        # 보간 내부의 토큰 스캔
        token = scan_token
        @tokens << token if token
      end
    end

    def skip_whitespace_in_interpolation
      advance while @position < @source.length && current_char =~ /[ \t]/
    end

    def scan_simple_string(start_pos, start_line, start_column, quote)
      value = quote

      while @position < @source.length
        char = current_char

        if char == quote
          value += char
          advance
          return Token.new(:string, value, start_pos, @position, start_line, start_column)
        elsif char == "\\" && peek_char
          value += char
          advance
          value += current_char
          advance
        elsif char == "\n"
          raise ScanError.new(
            "Unterminated string",
            line: start_line,
            column: start_column,
            position: start_pos
          )
        else
          value += char
          advance
        end
      end

      raise ScanError.new(
        "Unterminated string",
        line: start_line,
        column: start_column,
        position: start_pos
      )
    end

    def scan_single_quoted_string
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip opening '
      scan_simple_string(start_pos, start_line, start_column, "'")
    end

    def scan_colon_or_symbol
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip :

      # 심볼인지 확인
      if @position < @source.length && current_char =~ /[a-zA-Z_]/
        value = ":"
        while @position < @source.length && current_char =~ /[a-zA-Z0-9_]/
          value += current_char
          advance
        end
        Token.new(:symbol, value, start_pos, @position, start_line, start_column)
      else
        Token.new(:colon, ":", start_pos, @position, start_line, start_column)
      end
    end

    def scan_instance_or_class_variable
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip first @

      if current_char == "@"
        # 클래스 변수
        advance # skip second @
        value = "@@"
        while @position < @source.length && current_char =~ /[a-zA-Z0-9_]/
          value += current_char
          advance
        end
        Token.new(:cvar, value, start_pos, @position, start_line, start_column)
      else
        # 인스턴스 변수
        value = "@"
        while @position < @source.length && current_char =~ /[a-zA-Z0-9_]/
          value += current_char
          advance
        end
        Token.new(:ivar, value, start_pos, @position, start_line, start_column)
      end
    end

    def scan_global_variable
      start_pos = @position
      start_line = @line
      start_column = @column

      value = "$"
      advance # skip $

      while @position < @source.length && current_char =~ /[a-zA-Z0-9_]/
        value += current_char
        advance
      end

      Token.new(:gvar, value, start_pos, @position, start_line, start_column)
    end

    def scan_identifier_or_keyword
      start_pos = @position
      start_line = @line
      start_column = @column

      value = ""
      # Support Unicode letters (\p{L}) and numbers (\p{N}) in identifiers
      while @position < @source.length && current_char =~ /[\p{L}\p{N}_]/
        value += current_char
        advance
      end

      # ? 또는 ! 접미사 처리
      if @position < @source.length && ["?", "!"].include?(current_char)
        value += current_char
        advance
      end

      # 키워드인지 확인
      if KEYWORDS.key?(value)
        Token.new(KEYWORDS[value], value, start_pos, @position, start_line, start_column)
      elsif value[0] =~ /\p{Lu}/ # Unicode uppercase letter
        Token.new(:constant, value, start_pos, @position, start_line, start_column)
      else
        Token.new(:identifier, value, start_pos, @position, start_line, start_column)
      end
    end

    def scan_number
      start_pos = @position
      start_line = @line
      start_column = @column

      value = ""
      while @position < @source.length && current_char =~ /[0-9_]/
        value += current_char
        advance
      end

      # 소수점 확인
      if @position < @source.length && current_char == "." && peek_char =~ /[0-9]/
        value += current_char
        advance
        while @position < @source.length && current_char =~ /[0-9_]/
          value += current_char
          advance
        end
        Token.new(:float, value, start_pos, @position, start_line, start_column)
      else
        Token.new(:integer, value, start_pos, @position, start_line, start_column)
      end
    end

    def scan_less_than_or_heredoc
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip <

      if current_char == "<"
        # heredoc 또는 <<
        advance
        # heredoc: <<EOF, <<-EOF, <<~EOF 형태
        if current_char =~ /[~-]/ || current_char =~ /[A-Z_]/i
          scan_heredoc(start_pos, start_line, start_column)
        else
          # << 연산자? 아니면 다시 되돌리기
          @position = start_pos + 1
          @column = start_column + 1
          Token.new(:lt, "<", start_pos, @position, start_line, start_column)
        end
      elsif current_char == "="
        advance
        if current_char == ">"
          advance
          Token.new(:spaceship, "<=>", start_pos, @position, start_line, start_column)
        else
          Token.new(:lt_eq, "<=", start_pos, @position, start_line, start_column)
        end
      else
        Token.new(:lt, "<", start_pos, @position, start_line, start_column)
      end
    end

    def scan_heredoc(start_pos, start_line, start_column)
      # <<~, <<-, << 형식 처리
      squiggly = false
      dash = false

      if current_char == "~"
        squiggly = true
        advance
      elsif current_char == "-"
        dash = true
        advance
      end

      # 종료 마커 읽기
      delimiter = ""
      while @position < @source.length && current_char =~ /[A-Za-z0-9_]/
        delimiter += current_char
        advance
      end

      # 현재 줄 끝까지 스킵
      advance while @position < @source.length && current_char != "\n"
      advance if @position < @source.length # skip newline
      @line += 1
      @column = 1

      # heredoc 내용 수집
      content = ""

      while @position < @source.length
        line_content = ""

        while @position < @source.length && current_char != "\n"
          line_content += current_char
          advance
        end

        # 종료 마커 확인
        stripped = squiggly || dash ? line_content.lstrip : line_content
        if stripped == delimiter || line_content.strip == delimiter
          # heredoc 끝
          value = "<<#{if squiggly
                         "~"
                       else
                         (dash ? "-" : "")
                       end}#{delimiter}\n#{content}#{delimiter}"
          return Token.new(:heredoc, value, start_pos, @position, start_line, start_column)
        end

        content += line_content
        next unless @position < @source.length

        content += "\n"
        advance # skip newline
        @line += 1
        @column = 1
      end

      # 종료 마커를 찾지 못함
      raise ScanError.new(
        "Unterminated heredoc",
        line: start_line,
        column: start_column,
        position: start_pos
      )
    end

    def scan_greater_than
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip >

      if current_char == "="
        advance
        Token.new(:gt_eq, ">=", start_pos, @position, start_line, start_column)
      else
        Token.new(:gt, ">", start_pos, @position, start_line, start_column)
      end
    end

    def scan_equals
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip =

      case current_char
      when "="
        advance
        Token.new(:eq_eq, "==", start_pos, @position, start_line, start_column)
      when ">"
        advance
        Token.new(:hash_rocket, "=>", start_pos, @position, start_line, start_column)
      else
        Token.new(:eq, "=", start_pos, @position, start_line, start_column)
      end
    end

    def scan_bang
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip !

      if current_char == "="
        advance
        Token.new(:bang_eq, "!=", start_pos, @position, start_line, start_column)
      else
        Token.new(:bang, "!", start_pos, @position, start_line, start_column)
      end
    end

    def scan_ampersand
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip &

      if current_char == "&"
        advance
        Token.new(:and_and, "&&", start_pos, @position, start_line, start_column)
      else
        Token.new(:amp, "&", start_pos, @position, start_line, start_column)
      end
    end

    def scan_pipe
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip |

      if current_char == "|"
        advance
        Token.new(:or_or, "||", start_pos, @position, start_line, start_column)
      else
        Token.new(:pipe, "|", start_pos, @position, start_line, start_column)
      end
    end

    def scan_plus
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip +

      if current_char == "="
        advance
        Token.new(:plus_eq, "+=", start_pos, @position, start_line, start_column)
      else
        Token.new(:plus, "+", start_pos, @position, start_line, start_column)
      end
    end

    def scan_minus_or_arrow
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip -

      case current_char
      when ">"
        advance
        Token.new(:arrow, "->", start_pos, @position, start_line, start_column)
      when "="
        advance
        Token.new(:minus_eq, "-=", start_pos, @position, start_line, start_column)
      else
        Token.new(:minus, "-", start_pos, @position, start_line, start_column)
      end
    end

    def scan_star
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip *

      case current_char
      when "*"
        advance
        Token.new(:star_star, "**", start_pos, @position, start_line, start_column)
      when "="
        advance
        Token.new(:star_eq, "*=", start_pos, @position, start_line, start_column)
      else
        Token.new(:star, "*", start_pos, @position, start_line, start_column)
      end
    end

    def scan_slash
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip /

      if current_char == "="
        advance
        Token.new(:slash_eq, "/=", start_pos, @position, start_line, start_column)
      elsif regex_context?
        # 정규표현식 리터럴 스캔
        scan_regex(start_pos, start_line, start_column)
      else
        Token.new(:slash, "/", start_pos, @position, start_line, start_column)
      end
    end

    def regex_context?
      # Check if / followed by whitespace - always division
      next_char = @source[@position]
      return false if [" ", "\t", "\n"].include?(next_char)

      # Check previous token context
      return true if @tokens.empty?

      last_token = @tokens.last
      return true if last_token.nil?

      # After values/expressions - division operator
      case last_token.type
      when :identifier, :constant, :integer, :float, :string, :symbol,
           :rparen, :rbracket, :rbrace, :ivar, :cvar, :gvar, :regex
        false
      # After binary operators - could be regex in `a * /pattern/` but safer to treat as division
      # unless there's no space after /
      when :plus, :minus, :star, :slash, :percent, :star_star,
           :lt, :gt, :lt_eq, :gt_eq, :eq_eq, :bang_eq, :spaceship,
           :and_and, :or_or, :amp, :pipe, :caret
        # Already checked no whitespace after /, so this could be regex
        true
      # After keywords that expect expression - regex context
      when :kw_if, :kw_unless, :kw_when, :kw_case, :kw_while, :kw_until,
           :kw_and, :kw_or, :kw_not, :kw_return, :kw_yield
        true
      # After opening brackets/parens, comma, equals - regex context
      when :lparen, :lbracket, :lbrace, :comma, :eq, :colon, :semicolon,
           :plus_eq, :minus_eq, :star_eq, :slash_eq, :percent_eq,
           :and_eq, :or_eq, :caret_eq, :arrow
        true
      else
        false
      end
    end

    def scan_regex(start_pos, start_line, start_column)
      value = "/"

      while @position < @source.length
        char = current_char

        case char
        when "/"
          value += char
          advance
          # 플래그 스캔 (i, m, x, o 등)
          while @position < @source.length && current_char =~ /[imxo]/
            value += current_char
            advance
          end
          return Token.new(:regex, value, start_pos, @position, start_line, start_column)
        when "\\"
          # 이스케이프 시퀀스
          value += char
          advance
          if @position < @source.length
            value += current_char
            advance
          end
        when "\n"
          raise ScanError.new(
            "Unterminated regex",
            line: start_line,
            column: start_column,
            position: start_pos
          )
        else
          value += char
          advance
        end
      end

      raise ScanError.new(
        "Unterminated regex",
        line: start_line,
        column: start_column,
        position: start_pos
      )
    end

    def scan_percent
      start_pos = @position
      start_line = @line
      start_column = @column

      advance # skip %

      if current_char == "="
        advance
        Token.new(:percent_eq, "%=", start_pos, @position, start_line, start_column)
      else
        Token.new(:percent, "%", start_pos, @position, start_line, start_column)
      end
    end

    def skip_whitespace
      advance while @position < @source.length && current_char =~ /[ \t\r]/
    end

    def current_char
      @source[@position]
    end

    def peek_char
      @source[@position + 1]
    end

    def advance
      @column += 1
      @position += 1
    end
  end
end
