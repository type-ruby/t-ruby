# frozen_string_literal: true

module TRuby
  # Type-safe Metaprogramming Support
  # Provides type checking for Ruby's dynamic features
  module Metaprogramming
    # Dynamic method pattern declaration
    # Used with #: dynamic_methods annotation
    class DynamicMethodPattern
      attr_reader :pattern, :param_types, :return_type, :method_names

      def initialize(pattern:, param_types: [], return_type: nil, method_names: [])
        @pattern = pattern
        @param_types = param_types
        @return_type = return_type
        @method_names = method_names
      end

      # Check if a method name matches this pattern
      def matches?(method_name)
        case @pattern
        when Regexp
          @pattern.match?(method_name.to_s)
        when Array
          @pattern.include?(method_name.to_s) || @pattern.include?(method_name.to_sym)
        when String
          @pattern == method_name.to_s
        else
          false
        end
      end

      # Get type signature for a matching method
      def signature_for(method_name)
        return nil unless matches?(method_name)

        {
          name: method_name,
          params: @param_types,
          return_type: @return_type
        }
      end
    end

    # Method missing type tracker
    class MethodMissingTracker
      attr_reader :handlers

      def initialize
        @handlers = {}
      end

      # Register a method_missing handler with type information
      def register(class_name, pattern:, param_types: [], return_type: nil)
        @handlers[class_name] ||= []
        @handlers[class_name] << DynamicMethodPattern.new(
          pattern: pattern,
          param_types: param_types,
          return_type: return_type
        )
      end

      # Get type info for a dynamic method call
      def type_for(class_name, method_name)
        patterns = @handlers[class_name] || []
        patterns.each do |pattern|
          sig = pattern.signature_for(method_name)
          return sig if sig
        end
        nil
      end

      # Check if a class has method_missing handling
      def handles?(class_name, method_name)
        !type_for(class_name, method_name).nil?
      end
    end

    # Define method analyzer
    class DefineMethodAnalyzer
      # Analyze define_method calls and extract type information
      def analyze(source)
        methods = []

        # Match define_method :name do |params|
        source.scan(/define_method\s*[\(]?\s*:(\w+)\s*[\)]?\s*do\s*\|([^|]*)\|/m) do |name, params|
          methods << {
            name: name,
            params: parse_params(params),
            dynamic: true
          }
        end

        # Match define_method(:name) { |params| }
        source.scan(/define_method\s*\(\s*:(\w+)\s*\)\s*\{\s*\|([^|]*)\|/m) do |name, params|
          methods << {
            name: name,
            params: parse_params(params),
            dynamic: true
          }
        end

        # Match simple define_method :name
        source.scan(/define_method\s*[\(]?\s*:(\w+)\s*[\)]?\s*(?:do|\{)(?!\s*\|)/m) do |name|
          methods << {
            name: name.first,
            params: [],
            dynamic: true
          }
        end

        methods
      end

      private

      def parse_params(params_str)
        return [] if params_str.nil? || params_str.strip.empty?

        params_str.split(",").map do |param|
          param = param.strip
          # Check for type annotation: param: Type
          if param.include?(":")
            name, type = param.split(":", 2).map(&:strip)
            { name: name, type: type }
          else
            { name: param, type: nil }
          end
        end
      end
    end

    # Send/public_send type analyzer
    class SendAnalyzer
      def initialize(method_registry: {})
        @method_registry = method_registry
      end

      # Analyze a send call and return type info
      def analyze_send(receiver_type, method_name, args)
        # Look up method in registry
        if @method_registry[receiver_type]
          method_info = @method_registry[receiver_type][method_name.to_s]
          return method_info if method_info
        end

        # Return unknown type if method not found
        { return_type: "Any", dynamic: true }
      end

      # Register a method for type lookup
      def register_method(class_name, method_name, param_types: [], return_type: nil)
        @method_registry[class_name] ||= {}
        @method_registry[class_name][method_name.to_s] = {
          name: method_name,
          params: param_types,
          return_type: return_type
        }
      end
    end

    # ActiveRecord-style dynamic finder analyzer
    class DynamicFinderAnalyzer
      FINDER_PATTERNS = [
        { pattern: /^find_by_(\w+)$/, return_type: "Self?" },
        { pattern: /^find_by_(\w+)!$/, return_type: "Self" },
        { pattern: /^find_all_by_(\w+)$/, return_type: "Array<Self>" },
        { pattern: /^find_or_create_by_(\w+)$/, return_type: "Self" },
        { pattern: /^find_or_initialize_by_(\w+)$/, return_type: "Self" }
      ].freeze

      def initialize(model_attributes: {})
        @model_attributes = model_attributes
      end

      # Analyze a dynamic finder method
      def analyze(class_name, method_name)
        FINDER_PATTERNS.each do |finder|
          if match = method_name.to_s.match(finder[:pattern])
            attribute = match[1]

            # Check if this attribute exists on the model
            if valid_attribute?(class_name, attribute)
              attr_type = attribute_type(class_name, attribute)
              return {
                name: method_name,
                params: [{ name: attribute, type: attr_type }],
                return_type: finder[:return_type].gsub("Self", class_name),
                dynamic: true,
                attribute: attribute
              }
            end
          end
        end

        nil
      end

      # Register model attributes
      def register_model(class_name, attributes)
        @model_attributes[class_name] = attributes
      end

      private

      def valid_attribute?(class_name, attribute)
        attrs = @model_attributes[class_name]
        return true if attrs.nil?  # Allow if no attributes registered

        attrs.key?(attribute.to_s) || attrs.key?(attribute.to_sym)
      end

      def attribute_type(class_name, attribute)
        attrs = @model_attributes[class_name]
        return "Any" if attrs.nil?

        attrs[attribute.to_s] || attrs[attribute.to_sym] || "Any"
      end
    end

    # Class eval analyzer
    class ClassEvalAnalyzer
      # Analyze class_eval blocks for type information
      def analyze(source)
        results = []

        # Match class_eval with string
        source.scan(/class_eval\s*\(\s*<<[-~]?(\w+)(.*?)\1\s*\)/m) do |_heredoc, content|
          results.concat(analyze_eval_content(content))
        end

        # Match class_eval with block
        source.scan(/class_eval\s*(?:do|\{)(.*?)(?:end|\})/m) do |content|
          results.concat(analyze_eval_content(content.first))
        end

        results
      end

      private

      def analyze_eval_content(content)
        methods = []

        # Find def statements in eval content
        content.scan(/def\s+(\w+)\s*(?:\(([^)]*)\))?\s*(?::\s*(\w+))?/) do |name, params, return_type|
          methods << {
            name: name,
            params: parse_params(params),
            return_type: return_type,
            dynamic: true,
            source: :class_eval
          }
        end

        # Find attr_* declarations
        content.scan(/attr_(reader|writer|accessor)\s+(.+)/) do |type, attrs|
          attr_names = attrs.scan(/:(\w+)/).flatten
          attr_names.each do |attr_name|
            case type
            when "reader", "accessor"
              methods << { name: attr_name, params: [], return_type: nil, dynamic: true }
            end
            if type == "writer" || type == "accessor"
              methods << { name: "#{attr_name}=", params: [{ name: "value", type: nil }], return_type: nil, dynamic: true }
            end
          end
        end

        methods
      end

      def parse_params(params_str)
        return [] if params_str.nil? || params_str.strip.empty?

        params_str.split(",").map(&:strip).map do |param|
          if param.include?(":")
            name, type = param.split(":", 2).map(&:strip)
            { name: name, type: type }
          else
            { name: param.gsub(/^[*&]/, ""), type: nil }
          end
        end
      end
    end
  end

  # Main metaprogramming analyzer that combines all analyzers
  class MetaprogrammingAnalyzer
    attr_reader :method_missing_tracker, :define_method_analyzer,
                :send_analyzer, :dynamic_finder_analyzer, :class_eval_analyzer

    def initialize
      @method_missing_tracker = Metaprogramming::MethodMissingTracker.new
      @define_method_analyzer = Metaprogramming::DefineMethodAnalyzer.new
      @send_analyzer = Metaprogramming::SendAnalyzer.new
      @dynamic_finder_analyzer = Metaprogramming::DynamicFinderAnalyzer.new
      @class_eval_analyzer = Metaprogramming::ClassEvalAnalyzer.new
      @dynamic_method_registry = {}
      @annotations = {}
    end

    # Analyze source code for metaprogramming patterns
    def analyze(source, class_name: nil)
      results = {
        dynamic_methods: [],
        method_missing_handlers: [],
        define_method_calls: [],
        class_eval_blocks: [],
        warnings: []
      }

      # Parse annotations
      parse_annotations(source, class_name)

      # Analyze define_method calls
      results[:define_method_calls] = @define_method_analyzer.analyze(source)

      # Analyze class_eval blocks
      results[:class_eval_blocks] = @class_eval_analyzer.analyze(source)

      # Find method_missing implementations
      results[:method_missing_handlers] = find_method_missing(source, class_name)

      # Collect all dynamic methods
      results[:dynamic_methods] = collect_dynamic_methods(class_name)

      results
    end

    # Register a dynamic method pattern for a class
    def register_dynamic_pattern(class_name, pattern:, param_types: [], return_type: nil)
      @method_missing_tracker.register(
        class_name,
        pattern: pattern,
        param_types: param_types,
        return_type: return_type
      )
    end

    # Get type information for a dynamic method call
    def type_for_call(class_name, method_name, args = [])
      # Check method_missing handlers
      if info = @method_missing_tracker.type_for(class_name, method_name)
        return info
      end

      # Check dynamic finders
      if info = @dynamic_finder_analyzer.analyze(class_name, method_name)
        return info
      end

      # Check registered dynamic methods
      if @dynamic_method_registry[class_name]
        if info = @dynamic_method_registry[class_name][method_name.to_s]
          return info
        end
      end

      nil
    end

    # Check if a method call is dynamically defined
    def dynamic_method?(class_name, method_name)
      !type_for_call(class_name, method_name).nil?
    end

    # Register model for ActiveRecord-style dynamic finders
    def register_model(class_name, attributes)
      @dynamic_finder_analyzer.register_model(class_name, attributes)
    end

    # Parse #: annotations for metaprogramming
    def parse_annotations(source, class_name = nil)
      # Parse dynamic_methods annotation
      # #: dynamic_methods [:get, :post, :put, :delete] -> (String) -> Response
      source.scan(/#:\s*dynamic_methods\s+\[([^\]]+)\]\s*->\s*\(([^)]*)\)\s*->\s*(\w+)/) do |methods, params, return_type|
        method_names = methods.scan(/:(\w+)/).flatten
        param_types = params.split(",").map(&:strip)

        method_names.each do |name|
          register_dynamic_method(class_name, name, param_types, return_type)
        end
      end

      # Parse method_missing annotation
      # #: method_missing /^find_by_/ -> (Any) -> Self?
      source.scan(/#:\s*method_missing\s+\/([^\/]+)\/\s*->\s*\(([^)]*)\)\s*->\s*(\S+)/) do |pattern, params, return_type|
        param_types = params.split(",").map(&:strip)
        register_dynamic_pattern(
          class_name,
          pattern: Regexp.new("^#{pattern}"),
          param_types: param_types,
          return_type: return_type
        )
      end

      # Parse respond_to_missing annotation
      # #: respond_to_missing /^to_/ -> Boolean
      source.scan(/#:\s*respond_to_missing\s+\/([^\/]+)\//) do |pattern|
        register_dynamic_pattern(
          class_name,
          pattern: Regexp.new("^#{pattern.first}"),
          param_types: [],
          return_type: "Boolean"
        )
      end
    end

    private

    def find_method_missing(source, class_name)
      handlers = []

      # Find method_missing implementations
      source.scan(/def\s+method_missing\s*\(\s*(\w+)(?:\s*,\s*\*(\w+))?(?:\s*,\s*&(\w+))?\s*\)/m) do |method_arg, args_arg, block_arg|
        handlers << {
          class_name: class_name,
          method_arg: method_arg,
          args_arg: args_arg,
          block_arg: block_arg,
          dynamic: true
        }
      end

      handlers
    end

    def register_dynamic_method(class_name, method_name, param_types, return_type)
      @dynamic_method_registry[class_name] ||= {}
      @dynamic_method_registry[class_name][method_name.to_s] = {
        name: method_name,
        params: param_types.map.with_index { |t, i| { name: "arg#{i}", type: t } },
        return_type: return_type,
        dynamic: true
      }
    end

    def collect_dynamic_methods(class_name)
      methods = []

      # From method_missing tracker
      if handlers = @method_missing_tracker.handlers[class_name]
        handlers.each do |pattern|
          methods << {
            pattern: pattern.pattern,
            params: pattern.param_types,
            return_type: pattern.return_type,
            source: :method_missing
          }
        end
      end

      # From dynamic method registry
      if registry = @dynamic_method_registry[class_name]
        registry.each do |name, info|
          methods << info.merge(source: :annotation)
        end
      end

      methods
    end
  end

  # IR extension for metaprogramming support
  module IR
    # Dynamic method declaration node
    class DynamicMethods < Node
      attr_accessor :method_names, :param_types, :return_type

      def initialize(method_names:, param_types: [], return_type: nil, **opts)
        super(**opts)
        @method_names = method_names
        @param_types = param_types
        @return_type = return_type
      end
    end

    # Method missing handler node
    class MethodMissingHandler < Node
      attr_accessor :pattern, :param_types, :return_type

      def initialize(pattern:, param_types: [], return_type: nil, **opts)
        super(**opts)
        @pattern = pattern
        @param_types = param_types
        @return_type = return_type
      end
    end
  end
end
