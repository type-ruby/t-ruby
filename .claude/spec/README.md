<!-- Follows Document Simplification Principle: max 200 lines -->

# t-ruby Language Specification (Draft)

> **This is an early draft specification for the t-ruby language.**
> It describes the structure and design direction of t-ruby, which provides an optional static type system on top of Ruby by combining the philosophies of TypeScript and Ruby.

**Translations:** [日本語](./README.ja.md) | [한국어](./README.ko.md)

---

## 1. Overview

t-ruby is an **optional/gradual type layer** that runs on top of Ruby.
The `trc` compiler transforms `.trb` source files into:

* Executable Ruby code (`.rb`)
* Ruby signature files (`.rbs`)
* t-ruby advanced declaration files (`.d.trb`)

The language maintains Ruby's syntax and spirit while introducing TypeScript's developer experience (DX) for "optional static typing."

---

## 2. Language Philosophy

1. **Does not replace Ruby** — t-ruby is a separate type layer, not a superset; Ruby remains the runtime.
2. **Gradual adoption** — Partial `.trb` adoption → full project migration is possible.
3. **TypeScript-level DX** — Supports type system, interfaces, generics, unions/intersections, inference; IDE-friendly.
4. **RBS compatibility** — t-ruby aims for RBS superset; types are simplified to RBS scope when projected.
5. **Respects Ruby culture** — YAML-based config (`trbconfig.yml`); syntax feels natural to Ruby developers.

---

## 3. File Structure & Extensions

| Extension | Meaning | Description |
|-----------|---------|-------------|
| `.trb` | t-ruby source | Primary unit written by developers |
| `.rb` | Compiled Ruby | Executable output for Ruby runtime |
| `.rbs` | Ruby signature | RBS ecosystem integration, conservative type projection |
| `.d.trb` | t-ruby declaration | Full t-ruby advanced types preserved |
| `trbconfig.yml` | Config file | t-ruby compilation settings |

---

## 4. Compilation Pipeline

```
           (Developer writes)
               *.trb
                   │
                   ▼
            trc (t-ruby compiler)
                   │
      ┌────────────┴────────────────┐
      ▼                             ▼
   *.rb                         *.rbs (optional)
 (executable)            (RBS-scoped type projection)

      ▼
 *.d.trb (optional)
(t-ruby advanced types)
```

### 4.1 `.rb` Output Rules

* All type-related elements are **completely removed**.
* Transform without breaking Ruby syntax.
* Target Ruby 3.x syntax.

### 4.2 `.rbs` Output Rules

* Project types conservatively to RBS format.
* Advanced types (conditional, mapped) may be simplified or downgraded to `untyped`.

### 4.3 `.d.trb` Output Rules

* Contains the **complete form** of t-ruby's advanced type system.
* Refined declarations reconstructed from `.trb` files.
* Enables sophisticated analysis via IDE/LSP/static analyzers.

---

## 5. Detailed Specifications

For detailed specifications, see the following documents:

| Document | Content |
|----------|---------|
| [Syntax Specification](./syntax.md) | Functions, type annotations, type aliases, interfaces, generics |
| [Type System](./type-system.md) | RBS subset, advanced types, static analysis, error model |
| [AST Model](./ast.md) | AST structure and node types |

---

## 6. Standard Library Types (Draft)

Provides minimal type definitions for Ruby core objects:

```trb
type String = builtin
interface Enumerable[T]
  def map(): Array[T]
end
```

Standard type declarations can be auto-converted from RBS or manually defined.

---

## 7. Future Extensions

* Module/class type support
* Trait-like mixin type model
* Macro-based type generators
* Advanced inference engine
* Static type integration with Ruby 3 pattern matching

---

## 8. Versioning & Spec Conventions

* `v0.x`: Experimental stage, syntax/types may change
* `v1.0`: Stable language specification release
* Official spec documents provided in English, Korean, and Japanese

---

## 9. License

License for this specification document is TBD.
