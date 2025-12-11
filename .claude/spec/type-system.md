<!-- Follows Document Simplification Principle: max 200 lines -->

# Type System Design

> t-ruby type system architecture and static analysis model.

**Back to:** [Specification Overview](./README.md)

---

## 1. RBS-Compatible Subset

### Basic Types

* `Integer`, `String`, `Symbol`
* `Array[T]`, `Hash[K, V]`
* Union and intersection types
* Generic type parameters
* Interfaces and method signatures

---

## 2. t-ruby Advanced Types (RBS Superset)

### Conditional Types

```trb
T extends U ? X : Y
```

### Mapped Types

```trb
type Readonly<T> = { readonly [K in keyof T]: T[K] }
```

### Infer-based Types

```trb
type ReturnType<T> = T extends (...args: any) => infer R ? R : never
```

### Template Literal Types

```trb
type EventName = `on${Capitalize<string>}`
```

### Nested Generic Operations

Complex generic compositions with multiple type parameters.

---

## 3. RBS Projection

When projecting to `.rbs`:

| t-ruby Type | RBS Projection |
|-------------|----------------|
| Simple types | Direct mapping |
| Conditional types | Simplified or `untyped` |
| Mapped types | `untyped` |
| Complex generics | Partially preserved |

---

## 4. Static Analysis Model

### 4.1 Type Checking

Initial versions perform **type erasure only**.

Future versions target:

* Type consistency checks on function calls
* Interface implementation verification
* Generic type parameter validation
* Sophisticated static analysis via `.d.trb`

### 4.2 IDE Support (LSP)

* Go-to-definition
* Hover type information
* Signature help
* Diagnostics (type error reporting)

---

## 5. Error Model

### Compile-time Errors

* Syntax errors
* Type declaration structure errors
* Interface format errors

### Runtime Errors

* Occur in Ruby as-is
* t-ruby has no runtime; depends on Ruby runtime
