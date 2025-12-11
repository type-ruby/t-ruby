# frozen_string_literal: true

module TRuby
  # Extracts code examples from Markdown documentation files.
  #
  # Supports extracting:
  # - T-Ruby code blocks (```trb, ```t-ruby, ```ruby with type annotations)
  # - Ruby code blocks for comparison
  # - RBS type definitions
  #
  # @example
  #   extractor = DocsExampleExtractor.new
  #   examples = extractor.extract_from_file("docs/getting-started.md")
  #   examples.each { |ex| puts ex.code }
  #
  class DocsExampleExtractor
    # Represents an extracted code example
    CodeExample = Struct.new(
      :code,           # The code content
      :language,       # Language identifier (trb, ruby, rbs)
      :file_path,      # Source file path
      :line_number,    # Starting line number
      :metadata,       # Optional metadata from code fence
      keyword_init: true
    ) do
      def trb?
        %w[trb t-ruby].include?(language)
      end

      def ruby?
        language == "ruby"
      end

      def rbs?
        language == "rbs"
      end

      def should_verify?
        !metadata&.include?("skip-verify")
      end

      def should_compile?
        !metadata&.include?("no-compile")
      end

      def should_typecheck?
        !metadata&.include?("no-typecheck")
      end
    end

    # Code fence pattern: ```language{metadata}
    CODE_FENCE_PATTERN = /^```(\w+)?(?:\{([^}]*)\})?$/

    # Extract all code examples from a file
    #
    # @param file_path [String] Path to the markdown file
    # @return [Array<CodeExample>] Extracted code examples
    def extract_from_file(file_path)
      content = File.read(file_path, encoding: "UTF-8")
      extract_from_content(content, file_path)
    end

    # Extract all code examples from content
    #
    # @param content [String] Markdown content
    # @param file_path [String] Source file path (for reference)
    # @return [Array<CodeExample>] Extracted code examples
    def extract_from_content(content, file_path = "<string>")
      examples = []
      lines = content.lines
      in_code_block = false
      current_block = nil
      block_start_line = 0

      lines.each_with_index do |line, index|
        line_number = index + 1

        if !in_code_block && (match = line.match(CODE_FENCE_PATTERN))
          in_code_block = true
          block_start_line = line_number
          current_block = {
            language: match[1] || "text",
            metadata: match[2],
            lines: [],
          }
        elsif in_code_block && line.match(/^```\s*$/)
          in_code_block = false

          # Only include relevant languages
          if relevant_language?(current_block[:language])
            examples << CodeExample.new(
              code: current_block[:lines].join,
              language: normalize_language(current_block[:language]),
              file_path: file_path,
              line_number: block_start_line,
              metadata: current_block[:metadata]
            )
          end

          current_block = nil
        elsif in_code_block
          current_block[:lines] << line
        end
      end

      examples
    end

    # Extract from multiple files using glob pattern
    #
    # @param pattern [String] Glob pattern (e.g., "docs/**/*.md")
    # @return [Array<CodeExample>] All extracted examples
    def extract_from_glob(pattern)
      Dir.glob(pattern).flat_map { |file| extract_from_file(file) }
    end

    # Get statistics about extracted examples
    #
    # @param examples [Array<CodeExample>] Code examples
    # @return [Hash] Statistics
    def statistics(examples)
      {
        total: examples.size,
        trb: examples.count(&:trb?),
        ruby: examples.count(&:ruby?),
        rbs: examples.count(&:rbs?),
        verifiable: examples.count(&:should_verify?),
        files: examples.map(&:file_path).uniq.size,
      }
    end

    private

    def relevant_language?(lang)
      %w[trb t-ruby ruby rbs].include?(lang&.downcase)
    end

    def normalize_language(lang)
      case lang&.downcase
      when "t-ruby" then "trb"
      else lang&.downcase || "text"
      end
    end
  end
end
