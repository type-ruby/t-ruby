# T-Ruby Project Roadmap

## Current Status

### ✅ Completed Phases

**Milestone 1: Basic Type Parsing & Erasure**
- Basic type annotation parsing in function definitions
- Type erasure to produce valid Ruby code
- Comprehensive error handling and validation
- Full test coverage with RSpec (100% coverage)

**Milestone 2: Advanced Type System**
- **Phase 1**: Type Aliases (`type UserId = String`)
  - Registry-based type alias management
  - Circular reference detection
  - 14 test cases

- **Phase 2**: RBS File Generation
  - RBS signature generation for functions and type aliases
  - Integration with Ruby ecosystem
  - 13 test cases

- **Phase 3**: Interface Definitions (`interface Name ... end`)
  - Multi-line interface parsing
  - Member tracking and definition
  - 6 test cases

- **Phase 4**: Union Types (`String | Integer | nil`)
  - Union type parsing with member deduplication
  - Duplicate detection in unions
  - 11 test cases

- **Phase 5**: Generics (`Array<String>`, `Map<K, V>`)
  - Generic type parsing with nested support
  - Parameter type handling
  - 6 test cases

- **Phase 6**: Intersection Types (`Readable & Writable`)
  - Intersection type parsing
  - Duplicate detection in intersections
  - 7 test cases

**Test Coverage**: 112 examples, 0 failures, 85.35% coverage (338/396 lines)

---

## 🚀 Milestone 3: Ecosystem & Tooling Integration

### Phase 1: LSP (Language Server Protocol) Support

**Goal**: Enable IDE integration with autocomplete, diagnostics, and navigation

**Implementation Details**:
- Create `lib/t_ruby/lsp_server.rb`
- Implement LSP protocol handlers:
  - `initialize` - server capabilities
  - `textDocument/didOpen` - file opened
  - `textDocument/didChange` - file modified
  - `textDocument/completion` - autocomplete suggestions
  - `textDocument/hover` - type information
  - `textDocument/diagnostic` - validation errors
- Add LSP client executable as CLI entry point
- Support for VS Code extension integration

**Expected Test Coverage**: 15-20 test cases
**Dependencies**: Existing parser and error handler
**Estimated Complexity**: Medium

---

### Phase 2: .d.trb Type Declaration Files

**Goal**: Generate and consume separate type declaration files (similar to TypeScript .d.ts)

**Implementation Details**:
- Create `lib/t_ruby/declaration_generator.rb`
- Implement declaration file generation:
  - Extract type signatures from source files
  - Generate `.d.trb` files in separate directory
  - Support for re-exporting declarations
- Implement declaration file parser:
  - Load types from `.d.trb` files
  - Support for library type definitions
  - Version management for breaking changes
- Integration with compiler to load external declarations
- Support for npm-style packages with type definitions

**Expected Test Coverage**: 12-18 test cases
**Dependencies**: RBSGenerator, Parser, TypeAliasRegistry
**Estimated Complexity**: Medium-High

---

### Phase 3: IDE Language Integration

**Goal**: Create IDE extensions and plugins for popular editors

**Implementation Details**:
- **VS Code Extension**:
  - Syntax highlighting for .trb and .d.trb files
  - Integration with LSP server
  - Configuration UI for .trb.yml settings
  - Quick fixes and code actions

- **Vim/Neovim Plugin**:
  - Syntax highlighting via vim-polyglot
  - Integration via coc.nvim or native LSP
  - Navigation and diagnostic display

- **JetBrains IDE Support**:
  - Plugin development using JetBrains SDK
  - Custom language support registration
  - Debugger integration

**Expected Implementation**: Shell scripts/configs for easy installation
**Estimated Complexity**: Medium (LSP foundation required first)

---

### Phase 4: Standard Library Type Definitions

**Goal**: Provide type definitions for Ruby standard library

**Implementation Details**:
- Create `lib/stdlib_types/` directory with `.d.trb` files for:
  - Core classes (String, Array, Hash, etc.)
  - File I/O types
  - Network types
  - Concurrency primitives (Thread, Mutex, etc.)
- Auto-include stdlib types in compiler
- Support for different Ruby versions (2.7, 3.0, 3.1, 3.2+)
- Version-specific type variants

**Expected Deliverables**: 50+ type definition files
**Dependencies**: Declaration file system from Phase 2
**Estimated Complexity**: Low-Medium (repetitive but straightforward)

---

## 🎯 Milestone 4: Advanced Features & Optimization

### Phase 1: Constraint System

**Goal**: Enable type constraints for more precise type checking

**Implementation Details**:
- Create `lib/t_ruby/constraint_checker.rb`
- Implement constraint types:
  - Bounds constraints: `T <: Number` (T is subtype of Number)
  - Equality constraints: `T == String`
  - Numeric range constraints: `Int where 0..100`
  - Pattern constraints for strings
  - Custom predicate constraints
- Validation at compile-time and runtime
- Constraint propagation through generics
- Error messages with constraint violation details

**Syntax Example**:
```ruby
type PositiveInt <: Integer where > 0
def process(count: PositiveInt): String
end
```

**Expected Test Coverage**: 16-20 test cases
**Dependencies**: Parser enhancements, error handler
**Estimated Complexity**: Medium-High

---

### Phase 2: Type Inference System

**Goal**: Infer types from code patterns to reduce annotation burden

**Implementation Details**:
- Create `lib/t_ruby/type_inferencer.rb`
- Inference strategies:
  - Literal type inference (`"hello"` → `String`)
  - Return type inference from function body
  - Parameter type inference from usage patterns
  - Generic parameter inference in function calls
  - Type narrowing in conditional branches
- Integration with parser for optional type annotations
- Confidence scoring for inferred types
- User warnings for ambiguous inferences

**Syntax Example**:
```ruby
def add(a, b)  # Inferred as (Integer, Integer) -> Integer from usage
  a + b
end
```

**Expected Test Coverage**: 18-25 test cases
**Dependencies**: Parser, type erasure, all type system components
**Estimated Complexity**: High

---

### Phase 3: Runtime Type Validation

**Goal**: Generate runtime checks to validate types at execution

**Implementation Details**:
- Create `lib/t_ruby/runtime_validator.rb`
- Implement validation generators:
  - Parameter type validation at function entry
  - Return value validation before return
  - Property type validation on assignment
  - Generic type parameter validation
- Configuration for selective validation (all vs. public API only)
- Performance optimization: inline simple checks, extract complex ones
- Integration with error reporting

**Generated Code Example**:
```ruby
def process(items: Array<String>): Integer
  raise TypeError unless items.is_a?(Array) && items.all? { |i| i.is_a?(String) }
  # ... function body ...
end
```

**Expected Test Coverage**: 12-16 test cases
**Dependencies**: Compiler, type erasure, all type systems
**Estimated Complexity**: Medium

---

### Phase 4: Type Checking & Flow Analysis

**Goal**: Implement static type checking to catch errors before runtime

**Implementation Details**:
- Create `lib/t_ruby/type_checker.rb`
- Implement checking rules:
  - Function call argument type checking
  - Return type compatibility checking
  - Property access validation
  - Operator type compatibility
  - Type narrowing in conditionals (if/unless/case)
- Track type flow through control structures
- Support for type guards and assertions
- Detailed error messages with suggestions

**Expected Warnings**:
```
Type mismatch in function call:
  Function expects: String
  Provided: Integer
  Suggestion: Convert to string with .to_s
```

**Expected Test Coverage**: 20-25 test cases
**Dependencies**: Parser, all type systems, type inference
**Estimated Complexity**: High

---

### Phase 5: Performance Optimization

**Goal**: Optimize compilation speed and generated code performance

**Implementation Details**:
- Implement caching:
  - AST parse tree caching
  - Type resolution caching
  - Declaration file caching
  - Incremental compilation support
- Generated code optimization:
  - Inline simple type checks
  - Extract common validation patterns
  - Dead code elimination for unused types
- Parallel processing:
  - Multi-file compilation in parallel
  - Type checking in parallel when safe
- Profiling integration for bottleneck identification

**Expected Test Coverage**: 8-12 test cases
**Dependencies**: All previous phases
**Estimated Complexity**: Medium-High

---

### Phase 6: Package & Distribution

**Goal**: Enable sharing of typed Ruby libraries

**Implementation Details**:
- Create `lib/t_ruby/package_manager.rb`
- Implement package features:
  - Package manifest (.trb-manifest.json)
  - Dependency resolution
  - Type definition publishing
  - Version management
- Integration with existing package managers (Bundler)
- Type definition registry/repository
- Deprecation and migration support

**Manifest Example**:
```json
{
  "name": "my_typed_lib",
  "version": "1.0.0",
  "types": "lib/types/**/*.d.trb",
  "dependencies": {
    "other_lib": "^2.0.0"
  }
}
```

**Expected Test Coverage**: 10-14 test cases
**Dependencies**: Declaration system, all type systems
**Estimated Complexity**: Medium

---

## Architectural Considerations

### Parser Architecture
- **Current**: Modular with separate parsers for Union, Generic, Intersection types
- **Future**: Consider using parser combinator library for more complex grammars (Phase 3+)
- **Consideration**: Union/Generic/Intersection parsers could be unified into a single recursive descent parser

### Type System
- **Current**: Registry-based with tag-based representation
- **Future**: Consider implementing a proper type algebra system for advanced features
- **Consideration**: Constraint solving may require SMT solver integration

### Error Handling
- **Current**: Line-based error reporting with basic context
- **Future**: Implement sophisticated error recovery to report multiple errors per file
- **Consideration**: AST-based error reporting provides better context

### Compiler Pipeline
- **Current**: Linear: Parse → Validate → Erase → Generate RBS
- **Future**: Add intermediate IR (intermediate representation) for optimization and better code generation
- **Consideration**: IR-based pipeline enables more sophisticated transformations

### Testing Strategy
- **Current**: RSpec unit tests with high line coverage
- **Future**: Add integration tests with real .trb files and acceptance tests
- **Consideration**: Property-based testing (using rantly) for type inference edge cases

---

## Implementation Order

1. **Milestone 3 Phase 1**: LSP Support (enables better development experience)
2. **Milestone 3 Phase 2**: Declaration Files (foundation for tooling)
3. **Milestone 3 Phase 3**: IDE Integration (deliver user-facing value)
4. **Milestone 3 Phase 4**: Stdlib Types (improve usability)
5. **Milestone 4 Phase 1**: Constraints (advanced type features)
6. **Milestone 4 Phase 2**: Type Inference (reduce annotation burden)
7. **Milestone 4 Phase 3**: Runtime Validation (optional safety)
8. **Milestone 4 Phase 4**: Type Checking (core type safety)
9. **Milestone 4 Phase 5**: Performance (optimization)
10. **Milestone 4 Phase 6**: Package Management (ecosystem enablement)

---

## Success Metrics

- **Code Quality**: Maintain >85% line coverage across all phases
- **Test Count**: Each phase should have 10-25 comprehensive tests
- **Performance**: Compilation of 100-file project in <5 seconds
- **Usability**: Stdlib types for 95% of common Ruby APIs
- **Adoption**: IDE integration availability for 3+ popular editors
- **Documentation**: Usage examples for all major features

---

## Community & Ecosystem

### Potential Collaborations
- Ruby community for stdlib type definitions
- VSCode Marketplace for extension publication
- RubyGems registry integration
- Type definition community contributions

### Documentation Needs
- User guide for type annotation syntax
- Architecture documentation for contributors
- Migration guide for existing Ruby projects
- API reference for library authors

---

## Notes for Future Development

1. **Backwards Compatibility**: Ensure `.trb.yml` configuration format remains stable
2. **Performance**: Profile early, optimize later - focus on correctness first
3. **User Feedback**: Iterate based on real-world usage patterns
4. **Integration**: Prioritize Bundler/RubyGems integration early
5. **Testing**: Every phase should maintain comprehensive test coverage
6. **Documentation**: Document as you go - future maintainers depend on it

