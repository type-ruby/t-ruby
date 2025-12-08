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

**Test Coverage**: 217 examples, 0 failures, 90.36% coverage (806/892 lines)

---

## 🚀 Milestone 3: Ecosystem & Tooling Integration

### ✅ Phase 1: LSP (Language Server Protocol) Support

**Goal**: Enable IDE integration with autocomplete, diagnostics, and navigation

**Status**: COMPLETED ✅

**Implementation Details**:
- Created `lib/t_ruby/lsp_server.rb` with full LSP support
- Implemented LSP protocol handlers:
  - `initialize` - server capabilities ✅
  - `textDocument/didOpen` - file opened ✅
  - `textDocument/didChange` - file modified ✅
  - `textDocument/didClose` - file closed ✅
  - `textDocument/completion` - autocomplete suggestions ✅
  - `textDocument/hover` - type information ✅
  - `textDocument/definition` - go to definition ✅
  - `textDocument/publishDiagnostics` - validation errors ✅
- Added LSP CLI entry point (`trc --lsp`)
- Support for VS Code extension integration ready

**Test Coverage**: 29 test cases
**Dependencies**: Parser, ErrorHandler, TypeAliasRegistry
**Complexity**: Medium

---

### ✅ Phase 2: .d.trb Type Declaration Files

**Goal**: Generate and consume separate type declaration files (similar to TypeScript .d.ts)

**Status**: COMPLETED ✅

**Implementation Details**:
- Created `lib/t_ruby/declaration_generator.rb` with:
  - `DeclarationGenerator` - generates .d.trb files from source ✅
  - `DeclarationParser` - parses .d.trb files ✅
  - `DeclarationLoader` - manages declaration file loading ✅
- Declaration file generation:
  - Extract type signatures from source files ✅
  - Generate `.d.trb` files with type aliases, interfaces, functions ✅
  - Auto-generated header comments ✅
- Declaration file parser:
  - Load types from `.d.trb` files ✅
  - Recursive directory loading support ✅
  - Merge declarations from multiple files ✅
- Integration with compiler:
  - DeclarationLoader integrated into Compiler ✅
  - Multiple search paths support ✅
  - CLI `--decl` command for generating declarations ✅
- Config support via `emit.dtrb` option ✅

**Test Coverage**: 34 test cases
**Dependencies**: Parser, TypeAliasRegistry
**Complexity**: Medium-High

---

### ✅ Phase 3: IDE Language Integration

**Goal**: Create IDE extensions and plugins for popular editors

**Status**: COMPLETED ✅

**Implementation Details**:
- **VS Code Extension** (`editors/vscode/`):
  - Full syntax highlighting for .trb and .d.trb files ✅
  - TextMate grammar with type annotations support ✅
  - LSP client integration ✅
  - Commands: Compile, Generate Declaration, Restart LSP ✅
  - Configuration options for LSP and diagnostics ✅

- **Vim Plugin** (`editors/vim/`):
  - Syntax highlighting (syntax/truby.vim) ✅
  - Filetype detection (ftdetect/truby.vim) ✅
  - Filetype plugin with indentation and folding (ftplugin/truby.vim) ✅
  - Key mappings for compilation ✅

- **Neovim Plugin** (`editors/nvim/`):
  - Lua LSP configuration (lua/t-ruby-lsp.lua) ✅
  - nvim-lspconfig integration ✅
  - coc.nvim configuration ✅
  - User commands for compile and declaration generation ✅

- **Documentation** (`editors/README.md`):
  - Installation instructions for all editors ✅
  - Configuration examples ✅
  - Troubleshooting guide ✅

**Files Created**: 9 editor integration files
**Complexity**: Medium

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

