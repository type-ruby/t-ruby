<!-- Follows Document Simplification Principle: max 200 lines -->

# AST Model (Draft)

> Abstract Syntax Tree structure for t-ruby compiler.

**Back to:** [Specification Overview](./README.md)

---

## 1. Top-level Structure

```text
Program
 ├── TypeDeclarations[]
 ├── FunctionDeclarations[]
 └── Statements[]
```

---

## 2. Node Types

### Type Declaration Nodes

| Node | Description |
|------|-------------|
| `TypeAliasNode` | Type alias declarations (`type X = Y`) |
| `InterfaceNode` | Interface definitions |
| `GenericTypeNode` | Generic type parameters |

### Function Nodes

| Node | Description |
|------|-------------|
| `FunctionNode` | Function declarations |
| `ParameterNode` | Function parameters with type annotations |

### Type Annotation Nodes

| Node | Description |
|------|-------------|
| `TypeAnnotationNode` | Base type annotation |
| `UnionTypeNode` | Union types (`A | B`) |
| `IntersectionTypeNode` | Intersection types (`A & B`) |

---

## 3. Node Relationships

```text
FunctionNode
 ├── name: String
 ├── parameters: ParameterNode[]
 │    └── ParameterNode
 │         ├── name: String
 │         └── type: TypeAnnotationNode
 ├── returnType: TypeAnnotationNode?
 └── body: Statement[]
```

```text
InterfaceNode
 ├── name: String
 ├── typeParameters: GenericTypeNode[]?
 └── members: MethodSignature[]
```

---

## 4. Usage

The AST model is reused for:

* `.d.trb` generation
* Static type checking
* LSP services (go-to-definition, hover info)
* Code transformation and analysis
