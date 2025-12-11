<!-- Follows Document Simplification Principle: max 200 lines -->

# Syntax Specification

> Detailed syntax specification for t-ruby language constructs.

**Back to:** [Specification Overview](./README.md)

---

## 1. Function Declaration

### Format

```ruby
def identifier(parameters...): return_type
  body
end
```

### Example

```ruby
def add(a: Integer, b: Integer): Integer
  a + b
end
```

### Ruby Output

```ruby
def add(a, b)
  a + b
end
```

---

## 2. Type Annotations

### Variable Types (reserved for future versions)

```ruby
x: String = "hello"
```

### Parameter Types

```ruby
def greet(name: String)
```

### Return Types

```ruby
def greet(name: String): void
```

### Type Erasure Rules

* `name: String` → `name`
* `): String` → `)`

---

## 3. Type Alias

```ruby
type UserID = Integer
```

**.rbs projection:**
```rbs
type user_id = Integer
```

**.d.trb projection:**
```trb
type UserID = Integer
```

---

## 4. Interface

### Declaration

```ruby
interface Printable
  def print(): void
end
```

**.rbs projection:**
```rbs
interface _Printable
  def print: () -> void
end
```

**.d.trb projection:**
```trb
interface Printable
  def print(): void
end
```

---

## 5. Generics

```ruby
type Result<T, E> = Success<T> | Failure<E>
```

### RBS Projection Constraints

* Generics map 1:1, but conditional types are simplified.

---

## 6. Union / Intersection Types

```ruby
type ID = Integer | String
type Complex = Readable & Printable
```

Not projected to Ruby runtime; only reflected in `.rbs` and `.d.trb`.
