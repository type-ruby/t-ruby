# T-Ruby Project Roadmap

> **Single Source of Truth**: 로드맵은 GitHub에서 관리됩니다.

## Links

- **[GitHub Project Board](https://github.com/orgs/type-ruby/projects/1)** - 작업 현황
- **[Milestones](https://github.com/type-ruby/t-ruby/milestones)** - 버전별 진행 상황
- **[Roadmap Issues](https://github.com/type-ruby/t-ruby/labels/roadmap)** - 로드맵 관련 이슈

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

*For detailed roadmap, features, and release information, visit [GitHub Project Board](https://github.com/orgs/type-ruby/projects/1).*
