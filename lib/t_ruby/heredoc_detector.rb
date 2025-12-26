# frozen_string_literal: true

module TRuby
  # Detects regions that should be skipped during parsing:
  # - Heredoc content
  # - Block comments (=begin/=end)
  class HeredocDetector
    # Heredoc start patterns:
    # <<IDENTIFIER, <<-IDENTIFIER, <<~IDENTIFIER
    # <<'IDENTIFIER', <<"IDENTIFIER"
    HEREDOC_START_PATTERN = /<<([~-])?(['"]?)(\w+)\2/

    # Detect all skippable ranges in lines (heredocs and block comments)
    # @param lines [Array<String>] source lines
    # @return [Array<Range>] content ranges to skip (0-indexed)
    def self.detect(lines)
      ranges = []
      i = 0

      while i < lines.length
        line = lines[i]

        # Check for =begin block comment
        if line.strip == "=begin"
          start_line = i
          i += 1

          # Find =end
          while i < lines.length
            break if lines[i].strip == "=end"

            i += 1
          end

          # Range covers from =begin to =end (inclusive)
          ranges << (start_line..i) if i < lines.length
        # Check for heredoc
        elsif (match = line.match(HEREDOC_START_PATTERN))
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

    # Check if a line index is inside any skippable region
    # @param line_index [Integer] line index to check
    # @param heredoc_ranges [Array<Range>] ranges from detect()
    # @return [Boolean]
    def self.inside_heredoc?(line_index, heredoc_ranges)
      heredoc_ranges.any? { |range| range.include?(line_index) }
    end
  end
end
