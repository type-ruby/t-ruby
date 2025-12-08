# t-ruby

> Typed Ruby, inspired by TypeScript. Write `.trb`, compile to `.rb` and `.rbs`.

[![Test Coverage](https://img.shields.io/badge/coverage-85.35%25-brightgreen)](./TESTING.md)
[![RSpec Tests](https://img.shields.io/badge/tests-112%20passing-brightgreen)](./spec)
[![Ruby 3.0+](https://img.shields.io/badge/ruby-3.0+-red.svg)](https://www.ruby-lang.org/)

`t-ruby` is an experimental typed layer for Ruby.

* Source files: `.trb`
* Compiler: `trc`
* Config: `.trb.yml`
* Emit targets:

  * Ruby code: `.rb`
  * Ruby signature files: `.rbs` (optional)
  * t-ruby declaration files: `.d.trb` (optional, more expressive than `.rbs`)

The goal of t-ruby is to bring a TypeScript-like developer experience to Ruby, while respecting the existing Ruby ecosystem and its conventions.

---

## Status

**Active development.** Current implementation covers Milestones 1 and 2.

### ✅ Completed

**Milestone 1 – Basic Type Parsing & Erasure**
* Parameter and return type annotations
* Type erasure to produce valid Ruby code
* Comprehensive error handling and validation
* 100% test coverage

**Milestone 2 – Core Type System**
* `type` aliases with circular reference detection
* `interface` definitions with multi-line support
* Union types: `String | Integer | nil`
* Generic types: `Array<String>`, `Map<K, V>` with nested support
* Intersection types: `Readable & Writable`
* RBS file generation with full type projection
* **Test Coverage**: 112 tests, 85.35% coverage

### 🚀 In Progress / Planned

See [ROADMAP.md](./ROADMAP.md) for details on:
* Milestone 3: Ecosystem & Tooling (LSP, IDE integration, stdlib types)
* Milestone 4: Advanced Features (constraints, inference, runtime validation, type checking)

---

## Concept

### 1. Write `.trb`

```ruby
# hello.trb

def greet(name: String): void
  puts "Hello, #{name} from t-ruby!"
end

greet("world")
```

### 2. Compile with `trc`

```bash
trc hello.trb
```

Outputs to `build/hello.rb` (and optionally `.rbs` or `.d.trb`).

### 3. Run with Ruby

```bash
ruby build/hello.rb
```

---

## Design Goals

1. **TypeScript-like DX for Ruby developers**

   * Optional types, gradual typing
   * Familiar concepts: `type`, `interface`, generics, unions, intersections
   * A single compiler CLI: `trc`

2. **Interop with the existing Ruby ecosystem**

   * Emit `.rb` that runs on standard Ruby implementations
   * Emit `.rbs` for Steep, Ruby LSP, etc.
   * Emit `.d.trb` for richer type declarations

3. **RBS as a baseline, not a constraint**

   * t-ruby’s type system is a superset of RBS
   * Advanced types may be simplified when projected to `.rbs`
   * Existing `.rbs` files should remain valid

4. **Ruby-friendly configuration**

   * Project config stored in `.trb.yml`
   * YAML is used to match Ruby conventions

---

## Architecture

### Compiler Pipeline

```
.trb source
    ↓
[Parser] → Parse type annotations, interfaces, type aliases
    ↓
[Error Handler] → Validate types, detect circular references
    ↓
[Type Erasure] → Remove annotations, produce valid Ruby
    ↓
[RBS Generator] → Generate .rbs signatures (optional)
    ↓
.rb + .rbs output
```

### Type System Components

| Component | Purpose | Example |
|-----------|---------|---------|
| **Parser** | Parse function definitions and type annotations | `def foo(x: String): Integer` |
| **TypeAliasRegistry** | Manage and validate type aliases | `type UserId = String` |
| **UnionTypeParser** | Parse union types | `String \| Integer \| nil` |
| **GenericTypeParser** | Parse generic types with nesting | `Array<String>`, `Map<K, V>` |
| **IntersectionTypeParser** | Parse intersection types | `Readable & Writable` |
| **InterfaceParser** | Parse interface definitions | `interface Readable ... end` |
| **TypeErasure** | Remove type annotations from source | Converts `.trb` to valid `.rb` |
| **RBSGenerator** | Generate Ruby signature files | Produces `.rbs` format |
| **ErrorHandler** | Validate types and report errors | Type checking, duplicate detection |

### Parser Architecture

The parser uses a **modular, recursive design**:

1. **Main Parser** (`Parser`): Line-by-line tokenization
   - Detects function definitions
   - Extracts parameter and return type annotations
   - Handles multi-line constructs (interfaces)

2. **Type Parsers** (specialized classes):
   - `UnionTypeParser`: Parses `A | B | C` syntax
   - `GenericTypeParser`: Parses `Base<Params>` with bracket depth tracking
   - `IntersectionTypeParser`: Parses `A & B & C` syntax

3. **Registry System**:
   - `TypeAliasRegistry`: Tracks type aliases with circular reference detection
   - Validates custom types in type annotations

### Error Detection & Validation

The `ErrorHandler` validates:
- ✅ Type existence (built-in vs. custom types)
- ✅ Circular type alias references
- ✅ Duplicate type alias definitions
- ✅ Duplicate interface definitions
- ✅ Duplicate types in unions/intersections
- ✅ Function definition syntax

---

## Supported Type System

### Basic Types

```ruby
def process(name: String, count: Integer, active: Boolean): String
end
```

### Type Aliases

```ruby
type UserId = Integer
type Status = String

def get_user(id: UserId): String
end
```

### Union Types

```ruby
def convert(value: String | Integer): String
end

def maybe_null(): String | nil
end
```

### Generic Types

```ruby
def first(items: Array<String>): String
end

def map_values(data: Map<String, Integer>): Array<String>
end

# Nested generics
def nested(matrix: Array<Array<String>>): Integer
end
```

### Intersection Types

```ruby
interface Readable
  def read(): String
end

interface Writable
  def write(data: String): void
end

def process(obj: Readable & Writable): void
end
```

### Interface Definitions

```ruby
interface Repository
  def find(id: Integer): User
  def save(user: User): void
  def delete(id: Integer): Boolean
end
```

---

## `.trb.yml` Example

```yaml
emit:
  rb: true
  rbs: true
  dtrb: false

paths:
  src: ./src
  out: ./build
  stdlib_rbs: ./rbs/stdlib

strict:
  rbs_compat: true
  null_safety: true
  inference: basic
```

---

## Testing

t-ruby uses **RSpec** for comprehensive test coverage. All production code is tested with a focus on:

- **Complete coverage**: 100% code coverage across all modules
- **Multiple scenarios**: Tests cover happy paths, edge cases, and error conditions
- **Test integrity**: All tests either pass legitimately or are documented for future resolution

### Running Tests

```bash
bundle install
bundle exec rspec
# or
ruby -Ilib -rrspec -e 'RSpec::Core::Runner.run(["spec"])'
```

### Test Structure

- **Version**: Constants and versioning
- **Config**: Configuration loading, parsing, and validation
- **Compiler**: File compilation, path handling, and error cases
- **CLI**: Command-line interface, arguments, and user feedback

For detailed testing principles and guidelines, see [TESTING.md](./TESTING.md).

---

## Roadmap

For a detailed roadmap including Milestone 3 and 4 phases, see [ROADMAP.md](./ROADMAP.md).

### ✅ Milestone 0 – "Hello, t-ruby"

* ✓ `trc` CLI skeleton
* ✓ `.trb.yml` reader
* ✓ `.trb` → `.rb` copy
* ✓ First working prototype

### ✅ Milestone 1 – Basic Syntax & Type Erasure

* ✓ Parameter types: `name: String`
* ✓ Return types: `): String`
* ✓ Remove type annotations
* ✓ Comprehensive error reporting

### ✅ Milestone 2 – Core Type System

* ✓ `type` aliases with circular reference detection
* ✓ `interface` definitions with multi-line support
* ✓ Generics: `Array<T>`, `Map<K, V>` with nesting
* ✓ Union types: `String | Integer | nil`
* ✓ Intersection types: `A & B`
* ✓ RBS file generation and projection

### 🚀 Milestone 3 – Ecosystem & Tooling

* `.d.trb` declaration files
* Language Server Protocol (LSP) support
* IDE integration (VS Code, Vim, JetBrains)
* Standard library type definitions

### 🚀 Milestone 4 – Advanced Features

* Type constraints system
* Type inference system
* Runtime type validation
* Static type checking
* Performance optimization
* Package management

---

## Philosophy

t-ruby does not aim to replace Ruby.

* Ruby remains the runtime and host language
* t-ruby is an optional typed layer on top
* Gradual adoption in existing Ruby projects is a priority

`t-ruby` respects RBS:

* RBS remains the official Ruby signature format
* t-ruby extends RBS where useful
* Advanced types are projected conservatively into `.rbs`

---

## Multi-language Documentation

* English (this file)
* 日本語: [README.ja.md](./README.ja.md)
* 한국어: [README.ko.md](./README.ko.md)

---

## License

TBD.
