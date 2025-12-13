# frozen_string_literal: true

require "tmpdir"
require "fileutils"

# SimpleCov configuration for code coverage tracking
if ENV["COVERAGE"]
  require "simplecov"

  formatters = [SimpleCov::Formatter::HTMLFormatter]

  # Only add Cobertura formatter if it loads successfully
  begin
    require "simplecov-cobertura"
    formatters << SimpleCov::Formatter::CoberturaFormatter
  rescue LoadError
    # simplecov-cobertura not available
  end

  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(formatters)

  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/bin/"

    add_group "Libraries", "/lib/"
    add_group "CLI", "/lib/t_ruby/cli"
    add_group "Compiler", "/lib/t_ruby/compiler"
    add_group "Config", "/lib/t_ruby/config"
    add_group "Version", "/lib/t_ruby/version"
  end
end

# Load the t-ruby library
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "t_ruby"

# RSpec configuration
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Run specs in random order
  config.order = :random

  # Optional: set seed for reproducible test order
  Kernel.srand config.seed
end
