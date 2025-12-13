# frozen_string_literal: true

require "tmpdir"
require "fileutils"

# SimpleCov configuration for code coverage tracking
if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-lcov"

  SimpleCov::Formatter::LcovFormatter.config do |c|
    c.report_with_single_file = true
    c.single_report_path = "coverage/lcov.info"
  end

  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::LcovFormatter,
    ]
  )

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
