# t-ruby

> Typed Ruby, inspired by TypeScript. Write `.trb`, compile to `.rb` and `.rbs`.

[![Test Coverage](https://img.shields.io/badge/coverage-90%25-brightgreen)](./TESTING.md)
[![RSpec Tests](https://img.shields.io/badge/tests-260%20passing-brightgreen)](./spec)
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

**All milestones completed.** 260 tests passing.

### ✅ Milestone 1 – Basic Type Parsing & Erasure
* Parameter/return type annotations, type erasure, error handling

### ✅ Milestone 2 – Core Type System
* Type aliases, interfaces, union/intersection types, generics, RBS generation

### ✅ Milestone 3 – Ecosystem & Tooling
* LSP server, `.d.trb` declaration files, IDE integration (VS Code, Vim, Neovim), stdlib types

### ✅ Milestone 4 – Advanced Features
* Constraint system, type inference, runtime validation, static type checking, caching, package management

See [ROADMAP.md](./ROADMAP.md) for architecture details.

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

| Component | Purpose |
|-----------|---------|
| **Parser** | Parse type annotations |
| **TypeAliasRegistry** | Manage type aliases |
| **TypeChecker** | Static type checking |
| **TypeInferencer** | Automatic type inference |
| **RuntimeValidator** | Runtime check generation |
| **ConstraintChecker** | Type constraints |
| **TypeErasure** | Remove annotations |
| **RBSGenerator** | Generate `.rbs` files |
| **PackageManager** | Package distribution |

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

See [ROADMAP.md](./ROADMAP.md) for details.

| Milestone | Status |
|-----------|--------|
| 0 – Hello t-ruby | ✅ |
| 1 – Type Parsing & Erasure | ✅ |
| 2 – Core Type System | ✅ |
| 3 – Ecosystem & Tooling | ✅ |
| 4 – Advanced Features | ✅ |

---

## IDE & Editor Integration

t-ruby provides first-class support for popular editors with syntax highlighting, LSP integration, and development tools.

### Supported Editors

| Editor | Syntax Highlighting | LSP Support | Documentation |
|--------|:------------------:|:-----------:|---------------|
| **VS Code** | ✅ | ✅ | [Getting Started](./docs/vscode/en/getting-started.md) |
| **Vim** | ✅ | ❌ | [Getting Started](./docs/vim/en/getting-started.md) |
| **Neovim** | ✅ | ✅ | [Getting Started](./docs/neovim/en/getting-started.md) |

### Quick Install

**VS Code:**
```bash
# From VS Code Marketplace
ext install t-ruby

# Or from source
cd editors/vscode && npm install && npm run compile
code --install-extension .
```

**Vim:**
```vim
" Using vim-plug
Plug 'type-ruby/t-ruby', { 'rtp': 'editors/vim' }
```

**Neovim:**
```lua
-- Using lazy.nvim
{ "type-ruby/t-ruby", ft = { "truby" }, config = function()
    require("t-ruby-lsp").setup()
end }
```

### Documentation by Language

| | English | 한국어 | 日本語 |
|---|---------|--------|--------|
| **VS Code** | [Guide](./docs/vscode/en/getting-started.md) | [가이드](./docs/vscode/ko/getting-started.md) | [ガイド](./docs/vscode/ja/getting-started.md) |
| **Vim** | [Guide](./docs/vim/en/getting-started.md) | [가이드](./docs/vim/ko/getting-started.md) | [ガイド](./docs/vim/ja/getting-started.md) |
| **Neovim** | [Guide](./docs/neovim/en/getting-started.md) | [가이드](./docs/neovim/ko/getting-started.md) | [ガイド](./docs/neovim/ja/getting-started.md) |
| **Syntax Highlighting** | [Guide](./docs/syntax-highlighting/en/guide.md) | [가이드](./docs/syntax-highlighting/ko/guide.md) | [ガイド](./docs/syntax-highlighting/ja/guide.md) |

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
