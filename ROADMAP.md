# T-Ruby Project Roadmap

> **Single Source of Truth**: 공식 로드맵은 문서 사이트를 참조하세요.
> https://type-ruby.github.io/docs/project/roadmap

이 파일은 개발자용 빠른 참조입니다. 상세 내용은 공식 문서를 확인하세요.

## Quick Status

**Current Version**: v0.0.38
**Current Milestone**: 7 (Next Generation)

## Completed Milestones

| Milestone | Description | Status |
|-----------|-------------|--------|
| 1 | Basic Type Parsing & Erasure | ✅ |
| 2 | Core Type System | ✅ |
| 3 | Ecosystem & Tooling | ✅ |
| 4 | Advanced Features | ✅ |
| 5 | Infrastructure (IR, Parser Combinator, SMT) | ✅ |
| 6 | Integration & Production Readiness | ✅ |

## Current Focus: Milestone 7

| Feature | Status |
|---------|--------|
| External SMT Solver (Z3) | ⏳ Planned |
| LSP v3 | ⏳ Planned |
| Type-safe Metaprogramming | ⏳ Planned |
| Gradual Typing Migration | ⏳ Planned |

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

*For detailed roadmap, features, and release information, visit the [official documentation](https://type-ruby.github.io/docs/project/roadmap).*
