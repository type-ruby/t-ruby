# T-Ruby Project Roadmap

## Status

**Milestone 6 All Phases (1-4) completed.** All tests passing.

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

### ✅ Phase 1: Core Integration (Completed)

| Task | Description | Status |
|------|-------------|--------|
| Parser Combinator Integration | Replace `parser.rb` with `parser_combinator.rb` | ✅ Done |
| IR-based Compiler | Refactor `compiler.rb` to use IR system | ✅ Done |
| SMT-based Type Checking | Integrate SMT Solver into `type_checker.rb` | ✅ Done |

### ✅ Phase 2: New Features (Completed)

| Task | Description | Status |
|------|-------------|--------|
| LSP v2 + Semantic Tokens | Type-based syntax highlighting in editors | ✅ Done |
| Incremental Compilation | Only recompile changed files (cache-based) | ✅ Done |
| Cross-file Type Checking | Type verification across multiple files | ✅ Done |
| Watch Mode Enhancement | Faster watch mode using new IR/Parser | ✅ Done |

### ✅ Phase 3: Ecosystem Expansion (Completed)

| Task | Description | Status |
|------|-------------|--------|
| Stdlib Types Extension | Extended core types (Enumerable, Comparable, Range, Regexp, Proc, Time, Exception, Float, Module) | ✅ Done |
| Data Format Types | JSON, YAML, CSV type definitions | ✅ Done |
| Popular Gem Type Packages | Rails, RSpec, Sidekiq type definitions | ✅ Done |
| RubyGems.org Integration | RemoteRegistry with push/yank API | ✅ Done |

### ✅ Phase 4: Quality & Documentation (Completed)

| Task | Description | Status |
|------|-------------|--------|
| Benchmarks | BenchmarkSuite with parsing, type checking, compilation, incremental, parallel, memory benchmarks | ✅ Done |
| API Documentation | DocGenerator with HTML, Markdown, JSON output | ✅ Done |
| E2E Tests | Integration tests for full compilation, watch mode, LSP, package management | ✅ Done |

---

## 🔮 Milestone 7: Next Generation

| Feature | Description | Status |
|---------|-------------|--------|
| JetBrains IDE Plugin | IntelliJ IDEA, RubyMine 플러그인 (LSP 기반) | 🔜 Planned |
| External SMT Solver (Z3) | Z3 통합으로 고급 타입 추론 강화 | ✅ Done |
| WebAssembly Target | `.wasm` 컴파일 타겟 지원 | ✅ Done |
| LSP v3 | Language Server Protocol 3.17 지원 | ✅ Done |
| Type-safe Metaprogramming | 메타프로그래밍 타입 안전성 | ✅ Done |
| Gradual Typing Migration | 기존 Ruby 코드 점진적 마이그레이션 도구 | 🔜 Planned |

### ✅ Completed Features

#### WebAssembly Target (WASM)
- T-Ruby → WebAssembly Text Format (WAT) 컴파일
- `trc --wasm` 명령어 지원
- 브라우저/Node.js 실행 가능
- 런타임 함수 (abs, min, max) 포함
- 문서: [docs/WASM.md](docs/WASM.md)

#### LSP v3.17 Protocol
- Inlay Hints (인라인 타입 힌트)
- Call Hierarchy (호출 계층)
- Type Hierarchy (타입 계층)
- Folding Ranges (코드 접기)
- Selection Range (스마트 선택)
- Linked Editing Range (동기화 편집)
- Code Lens (참조 수, 멤버 수)
- Signature Help (함수 시그니처)
- Rename Support (이름 변경)
- Code Actions (Quick Fixes)

#### Type-safe Metaprogramming
- `define_method` 분석
- `method_missing` 타입 추적
- `class_eval` 분석
- ActiveRecord 동적 finder 지원 (`find_by_*`)
- `#: dynamic_methods` 어노테이션
- `#: method_missing` 패턴 선언

#### Z3 SMT Solver Integration
- Z3 외부 솔버 연동 (선택적)
- Refinement Types 검증 (`Integer where x > 0`)
- 서브타입 관계 증명
- SMT-LIB2 포맷 생성
- 내장 폴백 솔버

### JetBrains IDE Plugin
- IntelliJ Platform Plugin SDK 기반
- LSP4IJ로 `trc --lsp` 연결
- 문법 하이라이팅, 자동완성, 진단, 네비게이션
- 지원 IDE: IntelliJ IDEA, RubyMine, 기타 JetBrains IDE
- 문서: 영어, 한국어, 일본어
