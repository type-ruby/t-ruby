# frozen_string_literal: true

require_relative "lib/t_ruby/version"

Gem::Specification.new do |spec|
  spec.name = "t-ruby"
  spec.version = TRuby::VERSION
  spec.authors = ["Y. Fred Kim"]
  spec.email = ["yhkks1038@gmail.com"]

  spec.summary = "T-Ruby - TypeScript-style types for Ruby"
  spec.description = "t-ruby compiles .trb files with type annotations to executable Ruby (.rb) " \
                     "and optional type signature files (.rbs)"
  spec.homepage = "https://type-ruby.github.io"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "LICENSE", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["trc", "t-ruby"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "benchmark"
  spec.add_dependency "thor", "~> 1.0"

  # Development dependencies are specified in Gemfile, not here
  # (per RuboCop Gemspec/DevelopmentDependencies rule)

  spec.metadata["rubygems_mfa_required"] = "true"
end
