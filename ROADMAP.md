# T-Ruby Project Roadmap

## Status

**Milestone 5 completed.** 614 test examples, 0 failures. Milestone 6 in progress.

---

## ✅ Milestone 1: Basic Type Parsing & Erasure

- Parameter/return type annotations
- Type erasure for valid Ruby output
- Error handling and validation

---

## ✅ Milestone 2: Core Type System

| Feature | Description |
|---------|-------------|
| Type Aliases | `type UserId = String` |
| Interfaces | `interface Readable ... end` |
| Union Types | `String \| Integer \| nil` |
| Generics | `Array<String>`, `Map<K, V>` |
| Intersections | `Readable & Writable` |
| RBS Generation | `.rbs` file output |

---

## ✅ Milestone 3: Ecosystem & Tooling

| Feature | File |
|---------|------|
| LSP Server | `lsp_server.rb` |
| Declaration Files (.d.trb) | `declaration_generator.rb` |
| IDE Integration | `editors/` (VS Code, Vim, Neovim) |
| Stdlib Types | `lib/stdlib_types/` |

---

## ✅ Milestone 4: Advanced Features

| Feature | File |
|---------|------|
| Constraint System | `constraint_checker.rb` |
| Type Inference | `type_inferencer.rb` |
| Runtime Validation | `runtime_validator.rb` |
| Type Checking | `type_checker.rb` |
| Caching & Parallel Processing | `cache.rb` |
| Package Management | `package_manager.rb` |

---

## ✅ Milestone 5: Future Enhancements (Completed)

| Feature | File | Description |
|---------|------|-------------|
| Bundler/RubyGems Integration | `bundler_integration.rb` | Seamless integration with Ruby ecosystem |
| IR (Intermediate Representation) | `ir.rb` | AST, type nodes, code generation, optimization passes |
| Parser Combinator | `parser_combinator.rb` | Composable parsers for complex type grammars |
| SMT Solver | `smt_solver.rb` | Constraint solving for advanced type inference |

### Bundler Integration Features
- Auto-discovery of type packages for installed gems
- Type gem scaffold generation (`gem-types`)
- Gemfile `:types` group support
- Bundle manifest (`.trb-bundle.json`)
- Migration from native T-Ruby packages

### IR System Features
- Full AST node hierarchy (Program, TypeAlias, Interface, MethodDef, etc.)
- Type representation nodes (SimpleType, GenericType, UnionType, FunctionType, etc.)
- Visitor pattern for AST traversal
- Code generators (Ruby, RBS)
- Optimization passes (Dead Code Elimination, Constant Folding, Unused Declaration Removal)

### Parser Combinator Features
- Primitive parsers (Literal, Regex, Satisfy, EndOfInput)
- Combinators (Sequence, Alternative, Many, Optional, SepBy, Between)
- DSL for building parsers (identifier, integer, quoted_string, lexeme)
- TypeParser for complex type expressions
- DeclarationParser for T-Ruby declarations
- Rich error reporting with context

### SMT Solver Features
- Logical formulas (And, Or, Not, Implies, Iff)
- Type constraints (Subtype, TypeEqual, HasProperty)
- SAT solver using DPLL algorithm
- Type constraint solver with unification
- Type hierarchy with subtype checking
- Type inference engine for methods

---

## Architecture

```
.trb → Parser Combinator → IR Builder → Optimizer → Code Generator → .rb + .rbs
                               ↓
                         Type Checker
                               ↓
                         SMT Solver
                               ↓
                         Diagnostics
```

### Components

| Component | Purpose |
|-----------|---------|
| ParserCombinator | Composable type grammar parsing |
| IR::Builder | AST construction from parsed input |
| IR::Optimizer | Multi-pass optimization |
| IR::CodeGenerator | Ruby code output |
| IR::RBSGenerator | RBS type definition output |
| SMT::ConstraintSolver | Type constraint resolution |
| SMT::TypeInferenceEngine | Automatic type detection |
| BundlerIntegration | Ruby ecosystem integration |

---

## 🔄 Milestone 6: Integration & Production Readiness

### Phase 1: Core Integration

| Task | Description | Priority |
|------|-------------|----------|
| Parser Combinator Integration | Replace `parser.rb` with `parser_combinator.rb` | High |
| IR-based Compiler | Refactor `compiler.rb` to use IR system | High |
| SMT-based Type Checking | Integrate SMT Solver into `type_checker.rb` | High |

### Phase 2: New Features

| Task | Description |
|------|-------------|
| LSP v2 + Semantic Tokens | Type-based syntax highlighting in editors |
| Incremental Compilation | Only recompile changed files (cache-based) |
| Cross-file Type Checking | Type verification across multiple files |
| Watch Mode Enhancement | Faster watch mode using new IR/Parser |

### Phase 3: Ecosystem Expansion

| Task | Description |
|------|-------------|
| Stdlib Types Extension | More Ruby standard library type definitions |
| Popular Gem Type Packages | Rails, RSpec, Sidekiq type definitions |
| RubyGems.org Integration | Publish type packages to gem registry |

### Phase 4: Quality & Documentation

| Task | Description |
|------|-------------|
| Benchmarks | Performance measurement and optimization |
| API Documentation | Comprehensive docs and usage guides |
| E2E Tests | Integration tests with real projects |

---

## Future Possibilities

- External SMT solver integration (Z3)
- WebAssembly compilation target
- Language server protocol v3
- Type-safe metaprogramming support
- Gradual typing migration tools
