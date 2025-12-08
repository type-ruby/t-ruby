# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "t_ruby"
  spec.version = "0.0.1"
  spec.authors = ["Y. Fred Kim"]
  spec.email = ["yhkks1038@gmail.com"]

  spec.summary = "T-Ruby - A TypeScript-inspired typed layer for Ruby"
  spec.description = "t-ruby compiles .trb files with type annotations to executable Ruby (.rb) and optional type signature files (.rbs)"
  spec.homepage = "https://github.com/type-ruby/t-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*.rb", "bin/*", "LICENSE", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["trc"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "listen", "~> 3.8"
end
