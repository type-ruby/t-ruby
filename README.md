# t-ruby

> Typed Ruby, inspired by TypeScript. Write `.trb`, compile to `.rb` and `.rbs`.

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

**Early experimental.** APIs, syntax, and behavior may change without notice.

The first milestone aims to:

* Parse a small subset of t-ruby syntax
* Erase type annotations
* Emit valid Ruby `.rb` files
* Optionally generate minimal `.rbs` stubs

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

## Roadmap

### Milestone 0 – "Hello, t-ruby"

* `trc` CLI skeleton
* `.trb.yml` reader
* `.trb` → `.rb` copy
* First working prototype

### Milestone 1 – Basic Syntax & Type Erasure

* Parameter types: `name: String`
* Return types: `): String`
* Remove type annotations
* Minimal syntax error reporting

### Milestone 2 – Core Type System

* `type` aliases
* `interface` definitions
* Generics: `Result<T, E>`
* Union / intersection types
* Projection to `.rbs`

### Milestone 3 – Ecosystem & Tooling

* `.d.trb` declaration files
* Basic LSP support
* Integration with Ruby tools

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
