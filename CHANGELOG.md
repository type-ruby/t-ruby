# Changelog

All notable changes to T-Ruby will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.44] - 2026-01-17

### Added
- Direct `.trb` file execution with `trc run` command without intermediate files (#37)

## [0.0.43] - 2026-01-10

### Added
- TypeScript-style array shorthand syntax `T[]` as alternative to `Array<T>`
- Nested arrays support (`Integer[][]` for `Array<Array<Integer>>`)
- Nullable arrays (`String[]?` for `(Array<String> | nil)`)
- Arrays of nullable elements (`String?[]` for `Array<String?>`)
- Union type arrays (`(String | Integer)[]` for `Array<(String | Integer)>`)

## [0.0.39] - 2025-12-24

### Added
- TypeScript-style type inference engine
- BodyParser for method body IR node generation
- TypeEnv for scope chain management
- ASTTypeInferrer with lazy evaluation and caching
- Literal type inference (`"hello"` -> `String`, `42` -> `Integer`)
- Method call tracking (`str.upcase` -> `String`)
- Implicit return handling (Ruby's last expression as return type)
- Conditional type inference (union types from `if`/`else` branches)
- 200+ built-in method types for common Ruby methods
- Special `initialize` method handling (always returns `void`)
- Unreachable code detection

## [0.1.0-alpha] - 2025-12-09

### Added
- Initial alpha release
- Basic types: `String`, `Integer`, `Float`, `Boolean`, `Symbol`, `nil`
- Special types: `Any`, `void`, `never`, `self`
- Union types with `|` operator
- Optional types shorthand `T?` for `T | nil`
- Array generics `Array<T>`
- Hash generics `Hash<K, V>`
- Type inference for variables and returns
- Type narrowing with `is_a?` and `nil?`
- Literal types (string, number, symbol, boolean)
- Type aliases with `type` keyword
- Generic type aliases
- Intersection types with `&` operator
- Proc types `Proc<Args, Return>`
- Parameter, return, and block type annotations
- Generic functions and classes
- Interface definitions and structural typing
- `.trb` to `.rb` compilation with type erasure
- `.rbs` file generation
- Source maps for debugging
- File watching with `--watch`
- Type checking mode with `--check`
- Standard library type definitions
