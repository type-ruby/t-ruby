# frozen_string_literal: true

module TRuby
  # Detects heredoc block positions in source code
  # Used to skip parsing inside heredoc content
  class HeredocDetector
    # Heredoc start patterns:
    # <<IDENTIFIER, <<-IDENTIFIER, <<~IDENTIFIER
    # <<'IDENTIFIER', <<"IDENTIFIER"
    HEREDOC_START_PATTERN = /<<([~-])?(['"]?)(\w+)\2/

    # Detect all heredoc ranges in lines
    # @param lines [Array<String>] source lines
    # @return [Array<Range>] heredoc content ranges (0-indexed, excludes start line)
    def self.detect(lines)
      ranges = []
      i = 0

      while i < lines.length
        line = lines[i]

        if (match = line.match(HEREDOC_START_PATTERN))
          delimiter = match[3]
          squiggly = match[1] == "~"
          start_line = i
          i += 1

          # Find closing delimiter
          while i < lines.length
            # For squiggly heredoc or dash heredoc, delimiter can be indented
            # For regular heredoc, delimiter must be at line start
            if squiggly || match[1] == "-"
              break if lines[i].strip == delimiter
            elsif lines[i].chomp == delimiter
              break
            end
            i += 1
          end

          # Range covers content lines (after start, up to and including end delimiter)
          ranges << ((start_line + 1)..i) if i < lines.length
        end

        i += 1
      end

      ranges
    end

    # Check if a line index is inside any heredoc content
    # @param line_index [Integer] line index to check
    # @param heredoc_ranges [Array<Range>] ranges from detect()
    # @return [Boolean]
    def self.inside_heredoc?(line_index, heredoc_ranges)
      heredoc_ranges.any? { |range| range.include?(line_index) }
    end
  end
end
