# frozen_string_literal: true

module TRuby
  # Error raised when an unsupported Ruby version is detected
  class UnsupportedRubyVersionError < StandardError; end

  # Value object representing a Ruby version with comparison and feature detection
  #
  # @example
  #   version = RubyVersion.parse("3.4")
  #   version.supports_it_parameter? # => true
  #   version >= RubyVersion.parse("3.0") # => true
  #
  class RubyVersion
    include Comparable

    # Supported version range
    MIN_VERSION = [3, 0].freeze
    MAX_MAJOR = 4

    # Version string pattern: major.minor or major.minor.patch
    VERSION_REGEX = /\A(\d+)\.(\d+)(?:\.(\d+))?\z/

    attr_reader :major, :minor, :patch

    # @param major [Integer] major version number
    # @param minor [Integer] minor version number
    # @param patch [Integer] patch version number (default: 0)
    def initialize(major, minor, patch = 0)
      @major = major
      @minor = minor
      @patch = patch
    end

    # Parse a version string into a RubyVersion object
    #
    # @param version_string [String, Numeric] version string (e.g., "3.4", "3.4.1")
    # @return [RubyVersion] parsed version object
    # @raise [ArgumentError] if version format is invalid
    def self.parse(version_string)
      str = version_string.to_s
      match = VERSION_REGEX.match(str)

      raise ArgumentError, "Invalid version: #{version_string}" unless match

      new(match[1].to_i, match[2].to_i, (match[3] || 0).to_i)
    end

    # Get the current Ruby version from the environment
    #
    # @return [RubyVersion] current Ruby version
    def self.current
      parse(RUBY_VERSION)
    end

    # Compare two versions
    #
    # @param other [RubyVersion] version to compare with
    # @return [Integer] -1, 0, or 1
    def <=>(other)
      [major, minor, patch] <=> [other.major, other.minor, other.patch]
    end

    # Convert to string representation
    #
    # @return [String] version string (e.g., "3.4" or "3.4.1")
    def to_s
      patch.zero? ? "#{major}.#{minor}" : "#{major}.#{minor}.#{patch}"
    end

    # Check if this version is within the supported range (3.0 ~ 4.x)
    #
    # @return [Boolean] true if version is supported
    def supported?
      self >= self.class.parse("#{MIN_VERSION[0]}.#{MIN_VERSION[1]}") && major <= MAX_MAJOR
    end

    # Validate that this version is supported, raising an error if not
    #
    # @return [RubyVersion] self if valid
    # @raise [UnsupportedRubyVersionError] if version is not supported
    def validate!
      unless supported?
        raise UnsupportedRubyVersionError,
              "Ruby #{self}는 지원되지 않습니다. 지원 범위: #{MIN_VERSION.join(".")} ~ #{MAX_MAJOR}.x"
      end

      self
    end

    # Check if this version supports the `it` implicit block parameter (Ruby 3.4+)
    #
    # @return [Boolean] true if `it` parameter is supported
    def supports_it_parameter?
      self >= self.class.parse("3.4")
    end

    # Check if this version supports anonymous block forwarding `def foo(&) ... end` (Ruby 3.1+)
    #
    # @return [Boolean] true if anonymous block forwarding is supported
    def supports_anonymous_block_forwarding?
      self >= self.class.parse("3.1")
    end

    # Check if numbered parameters (_1, _2, etc.) raise NameError (Ruby 4.0+)
    #
    # @return [Boolean] true if numbered parameters cause errors
    def numbered_parameters_raise_error?
      self >= self.class.parse("4.0")
    end
  end
end
