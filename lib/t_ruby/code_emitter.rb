# frozen_string_literal: true

module TRuby
  # Version-specific code transformation strategies
  #
  # @example
  #   emitter = CodeEmitter.for_version("4.0")
  #   result = emitter.transform(source)
  #
  module CodeEmitter
    # Factory method to get appropriate emitter for target Ruby version
    #
    # @param target_ruby [String] target Ruby version (e.g., "3.0", "4.0")
    # @return [Base] appropriate emitter instance
    def self.for_version(target_ruby)
      version = RubyVersion.parse(target_ruby)

      if version.numbered_parameters_raise_error?
        Ruby40.new(version)
      elsif version.supports_it_parameter?
        Ruby34.new(version)
      elsif version.supports_anonymous_block_forwarding?
        Ruby31.new(version)
      else
        Ruby30.new(version)
      end
    end

    # Base class for version-specific code emitters
    class Base
      attr_reader :version

      def initialize(version)
        @version = version
      end

      # Apply all transformations for this version
      #
      # @param source [String] source code to transform
      # @return [String] transformed source code
      def transform(source)
        result = source.dup
        result = transform_numbered_params(result)
        transform_block_forwarding(result)
      end

      # Transform numbered block parameters (_1, _2, etc.)
      # Default: no transformation
      #
      # @param source [String] source code
      # @return [String] transformed source code
      def transform_numbered_params(source)
        source
      end

      # Transform block forwarding syntax
      # Default: no transformation
      #
      # @param source [String] source code
      # @return [String] transformed source code
      def transform_block_forwarding(source)
        source
      end

      # Check if this version supports the `it` implicit block parameter
      #
      # @return [Boolean]
      def supports_it?
        false
      end

      # Check if numbered parameters raise NameError in this version
      #
      # @return [Boolean]
      def numbered_params_error?
        false
      end
    end

    # Ruby 3.0 emitter - baseline, no transformations
    class Ruby30 < Base
      # Ruby 3.0 uses standard syntax, no transformations needed
    end

    # Ruby 3.1+ emitter - supports anonymous block forwarding
    class Ruby31 < Base
      # Transform `def foo(&block) ... bar(&block)` to `def foo(&) ... bar(&)`
      #
      # Only transforms when the block parameter is ONLY used for forwarding,
      # not when it's called directly (e.g., block.call)
      def transform_block_forwarding(source)
        result = source.dup

        # Find method definitions with block parameters
        # Pattern: def method_name(&block_name)
        result.gsub!(/def\s+(\w+[?!=]?)\s*\(([^)]*?)&(\w+)\s*\)/) do |_match|
          method_name = ::Regexp.last_match(1)
          other_params = ::Regexp.last_match(2)
          block_name = ::Regexp.last_match(3)

          # Find the method body to check block usage
          method_start = ::Regexp.last_match.begin(0)
          remaining = result[method_start..]

          # Check if block is only used for forwarding (not called directly)
          if block_only_forwarded?(remaining, block_name)
            "def #{method_name}(#{other_params}&)"
          else
            "def #{method_name}(#{other_params}&#{block_name})"
          end
        end

        # Replace block forwarding calls with anonymous forwarding
        # This is a simplified approach - in practice we'd need proper scope tracking
        result.gsub!(/(\w+)\s*\(\s*&(\w+)\s*\)/) do |match|
          call_name = ::Regexp.last_match(1)
          ::Regexp.last_match(2)

          # Check if this block name was converted to anonymous
          if result.include?("def ") && result.include?("(&)")
            "#{call_name}(&)"
          else
            match
          end
        end

        result
      end

      private

      # Check if a block parameter is only used for forwarding
      def block_only_forwarded?(method_body, block_name)
        # Simple heuristic: if block_name appears with .call or without &, it's not just forwarding
        # Look for patterns like: block_name.call, block_name.(), yield

        # Extract method body (until next def or end of class)
        lines = method_body.lines
        depth = 0
        body_lines = []

        lines.each do |line|
          depth += 1 if line.match?(/\b(def|class|module|do|begin|case|if|unless|while|until)\b/)
          depth -= 1 if line.match?(/\bend\b/)
          body_lines << line
          break if depth <= 0 && body_lines.length > 1
        end

        body = body_lines.join

        # Check for direct block usage
        return false if body.match?(/\b#{block_name}\s*\./)     # block.call, block.(), etc.
        return false if body.match?(/\b#{block_name}\s*\[/)     # block[args]
        return false if body.match?(/\byield\b/)                # yield instead of forwarding

        # Only &block_name patterns - this is forwarding
        true
      end
    end

    # Ruby 3.4+ emitter - supports `it` implicit block parameter
    class Ruby34 < Ruby31
      def supports_it?
        true
      end

      # Ruby 3.4 still supports _1 syntax, so no transformation needed by default
      # Users can opt-in to using `it` style if they want
    end

    # Ruby 4.0+ emitter - _1 raises NameError, must use `it`
    class Ruby40 < Ruby34
      def numbered_params_error?
        true
      end

      # Transform numbered parameters to appropriate syntax
      #
      # - Single _1 → it
      # - Multiple (_1, _2) → explicit |k, v| params
      def transform_numbered_params(source)
        result = source.dup

        # Simple approach: replace all _1 with it when it's the only numbered param in scope
        # For complex cases with _2+, we'd need proper parsing
        # For now, do a global replacement if _2 etc are not present
        if result.match?(/\b_[2-9]\b/)
          # Has multiple numbered params - need to convert to explicit params
          # This is a complex case that requires proper block parsing
          transform_multi_numbered_params(result)
        else
          # Only _1 is used - simple replacement
          result.gsub(/\b_1\b/, "it")
        end
      end

      private

      def transform_multi_numbered_params(source)
        result = source.dup

        # Find blocks and transform them
        # Use a recursive approach with placeholder replacement

        # Replace innermost blocks first
        loop do
          changed = false
          result = result.gsub(/\{([^{}]*)\}/) do |block|
            content = ::Regexp.last_match(1)
            max_param = find_max_numbered_param(content)

            if max_param > 1
              # Multiple params - convert to explicit
              param_names = generate_param_names(max_param)
              new_content = content.dup
              (1..max_param).each do |i|
                new_content.gsub!(/\b_#{i}\b/, param_names[i - 1])
              end
              changed = true
              "{ |#{param_names.join(", ")}| #{new_content.strip} }"
            elsif max_param == 1
              # Single _1 - convert to it
              changed = true
              "{ #{content.gsub(/\b_1\b/, "it").strip} }"
            else
              block
            end
          end
          break unless changed
        end

        result
      end

      def find_max_numbered_param(content)
        max = 0
        content.scan(/\b_(\d+)\b/) do |match|
          num = match[0].to_i
          max = num if num > max
        end
        max
      end

      def generate_param_names(count)
        # Generate simple parameter names: a, b, c, ... or k, v for 2
        if count == 2
          %w[k v]
        else
          ("a".."z").take(count)
        end
      end
    end
  end
end
