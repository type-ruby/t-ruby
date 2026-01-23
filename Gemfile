# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "rake", "~> 13.0"
  gem "rbs", "~> 3.0"
  gem "rspec", "~> 3.0"
  gem "rspec_junit_formatter", "~> 0.6.0"
  gem "rubocop", require: false
  gem "simplecov", "~> 0.22.0", require: false
  gem "simplecov-lcov", "~> 0.8.0", require: false

  # listen gem for watch mode
  # Note: May have compatibility issues on Ruby 4.0+ due to ffi
  gem "listen", "~> 3.8"
end
