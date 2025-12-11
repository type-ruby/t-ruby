# T-Ruby Project Roadmap

## Status

**Milestone 6 completed. Milestone -7 (Technical Debt) in progress.** All tests passing.

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

## 🔄 Milestone -7: Technical Debt & System Foundation

> 기술 부채 해소 및 지속 가능한 개발 시스템 구축

### ✅ Phase 1: Foundation Setup (Completed)

| Task | Description | Status |
|------|-------------|--------|
| TDD Workflow Rules | `.claude/rules/tdd-workflow.md` TDD 지침 정의 | ✅ Done |
| Code Review Checklist | `.claude/rules/code-review-checklist.md` | ✅ Done |
| Documentation-Driven Rules | `.claude/rules/documentation-driven.md` | ✅ Done |
| Monorepo Setup (moon) | `.moon/workspace.yml`, `.moon/toolchain.yml` | ✅ Done |
| Project moon.yml Files | 각 프로젝트별 태스크 정의 | ✅ Done |

### ⏳ Phase 2: CI/CD Pipeline

| Task | Description | Status |
|------|-------------|--------|
| CI Workflow | `.github/workflows/ci.yml` (Ruby matrix test) | ⏳ Planned |
| RuboCop CI | CI에 린트 검사 추가 | ⏳ Planned |
| Codecov Integration | 테스트 커버리지 리포트 | ⏳ Planned |
| VSCode Test CI | 플러그인 테스트 자동화 | ⏳ Planned |
| JetBrains Test CI | 플러그인 테스트 자동화 | ⏳ Planned |
| Docs Verify CI | 문서 예제 검증 자동화 | ⏳ Planned |
| Release Workflow | `.github/workflows/release.yml` (동시 배포) | ⏳ Planned |

### ⏳ Phase 3: Editor Plugin Integration

| Task | Description | Status |
|------|-------------|--------|
| VERSION File | `editors/VERSION` (v0.2.0) Single Source of Truth | ⏳ Planned |
| Version Sync Script | `scripts/sync-editor-versions.sh` | ⏳ Planned |
| VSCode Test Setup | `@vscode/test-electron` + Mocha | ⏳ Planned |
| VSCode Tests | `editors/vscode/src/test/` 테스트 작성 | ⏳ Planned |
| JetBrains Test Setup | JUnit 5 + IntelliJ Platform Test | ⏳ Planned |
| JetBrains Tests | `editors/jetbrains/src/test/` 테스트 작성 | ⏳ Planned |
| Editor CONTRIBUTING.md | 플러그인 기여 가이드 | ⏳ Planned |

### ⏳ Phase 4: Documentation Verification

| Task | Description | Status |
|------|-------------|--------|
| DocsExampleExtractor | 마크다운에서 코드 블록 추출 | ⏳ Planned |
| DocsExampleVerifier | 컴파일/타입체크 검증 | ⏳ Planned |
| DocsBadgeGenerator | 커버리지 뱃지 생성 | ⏳ Planned |
| Rake Task | `rake docs:verify`, `rake docs:badge` | ⏳ Planned |
| DocsBadge Component | Docusaurus 뱃지 컴포넌트 | ⏳ Planned |

### ⏳ Phase 5: Release Automation

| Task | Description | Status |
|------|-------------|--------|
| COMMIT_CONVENTION.md | Conventional Commits 가이드 | ⏳ Planned |
| .releaserc.yml | semantic-release 설정 | ⏳ Planned |
| CHANGELOG Automation | 자동 생성 및 GitHub Release | ⏳ Planned |

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

## 🔄 Milestone 7: Next Generation (In Progress)

| Feature | Description | Status |
|---------|-------------|--------|
| JetBrains IDE Plugin | IntelliJ IDEA, RubyMine 플러그인 (LSP 기반) | ✅ Done |
| WebAssembly Target | 브라우저용 WASM 패키지 (`@t-ruby/wasm`) | ✅ Done |
| External SMT Solver (Z3) | Z3 통합으로 고급 타입 추론 강화 | ⏳ Planned |
| LSP v3 | Language Server Protocol 3.x 지원 | ⏳ Planned |
| Type-safe Metaprogramming | 메타프로그래밍 타입 안전성 | ⏳ Planned |
| Gradual Typing Migration | 기존 Ruby 코드 점진적 마이그레이션 도구 | ⏳ Planned |
| Performance Benchmarks Docs | 벤치마크 결과 문서화 및 공식 문서 반영 | ⏳ Planned |

### ✅ JetBrains IDE Plugin (Completed)
- IntelliJ Platform Plugin SDK 기반
- LSP4IJ로 `trc --lsp` 연결
- 문법 하이라이팅, 자동완성, 진단, 네비게이션
- 지원 IDE: IntelliJ IDEA, RubyMine, WebStorm, PyCharm, GoLand (2024.2+)
- 문서: 영어, 한국어, 일본어
- **Marketplace**: https://plugins.jetbrains.com/plugin/29335-t-ruby
- **Version**: v0.1.2

### ✅ WebAssembly Target (Completed)
- npm 패키지: `@t-ruby/wasm`
- 브라우저에서 T-Ruby 컴파일러 실행
- Playground 지원용
- **Version**: v0.0.8
