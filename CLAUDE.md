# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

t-ruby is an experimental typed layer for Ruby, inspired by TypeScript. It compiles `.trb` source files to executable Ruby code (`.rb`) and optionally Ruby signature files (`.rbs`) or t-ruby declaration files (`.d.trb`).

**Current Status:** Production ready (Milestone 6 completed). See [ROADMAP.md](ROADMAP.md) for details.

## Core Compilation Workflow

```
*.trb (t-ruby source) → trc (compiler) → *.rb + *.rbs (optional) + *.d.trb (optional)
```

## Key Concepts

- **Source files:** `.trb` - t-ruby source code with type annotations
- **Compiler:** `trc` - CLI tool that compiles t-ruby to Ruby
- **Config:** `.trb.yml` - YAML-based project configuration
- **Type erasure:** Type annotations are removed when compiling to `.rb`
- **RBS compatibility:** t-ruby's type system is a superset of RBS; advanced types are simplified when projected to `.rbs`

## t-ruby Syntax Examples

```ruby
# Function with typed parameters and return type
def add(a: Integer, b: Integer): Integer
  a + b
end

# Type alias
type UserID = Integer

# Interface
interface Printable
  def print(): void
end

# Generics
type Result<T, E> = Success<T> | Failure<E>

# Union/Intersection types
type ID = Integer | String
type Complex = Readable & Printable
```

## Documentation

- **Documentation Guidelines:** [.claude/docs/DOCUMENTATION.md](.claude/docs/DOCUMENTATION.md)
- **Language Specification:** [.claude/spec/README.md](.claude/spec/README.md)
- README available in English, Japanese ([README.ja.md](README.ja.md)), and Korean ([README.ko.md](README.ko.md))

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full project roadmap and current status.
