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

### ✅ Phase 4: Standard Library Type Definitions

**Goal**: Provide type definitions for Ruby standard library

**Status**: COMPLETED ✅

**Implementation Details**:
- Created `lib/stdlib_types/` directory structure:
  - `core/` - Core Ruby classes
  - `io/` - File system and I/O
  - `net/` - Network types
  - `concurrent/` - Threading and synchronization
  - `index.d.trb` - Index with usage instructions

- **Core Types** (6 files):
  - `string.d.trb` - String manipulation ✅
  - `integer.d.trb` - Numeric operations ✅
  - `array.d.trb` - Array<T> with generics ✅
  - `hash.d.trb` - Hash<K, V> with generics ✅
  - `symbol.d.trb` - Symbol class ✅
  - `object.d.trb` - Base Object class ✅

- **I/O Types** (3 files):
  - `io.d.trb` - Base IO class ✅
  - `file.d.trb` - File and FileClass ✅
  - `dir.d.trb` - Dir and DirClass ✅

- **Network Types** (2 files):
  - `socket.d.trb` - Socket, TCPSocket, UDPSocket, etc. ✅
  - `http.d.trb` - HTTP, HTTPRequest, HTTPResponse ✅

- **Concurrency Types** (2 files):
  - `thread.d.trb` - Thread and ThreadClass ✅
  - `mutex.d.trb` - Mutex, Queue, ConditionVariable ✅

**Deliverables**: 14 type definition files with 500+ method signatures
**Dependencies**: Declaration file system
**Complexity**: Low-Medium

---

## ✅ Milestone 4: Advanced Features & Optimization

### ✅ Phase 1: Constraint System

**Goal**: Enable type constraints for more precise type checking

**Status**: COMPLETED ✅

**Implementation Details**:
- Created `lib/t_ruby/constraint_checker.rb` with:
  - `Constraint` - Base constraint class ✅
  - `BoundsConstraint` - T <: BaseType bounds ✅
  - `EqualityConstraint` - T == SpecificType ✅
  - `NumericRangeConstraint` - Integer where min..max ✅
  - `PatternConstraint` - String where /regex/ ✅
  - `PredicateConstraint` - Type where predicate? ✅
  - `LengthConstraint` - String/Array length constraints ✅
  - `ConstraintChecker` - Main validation engine ✅
  - `ConstrainedTypeRegistry` - Type registration and management ✅
- Validation at compile-time and runtime
- Constraint propagation through generics
- Error messages with constraint violation details

**Syntax Example**:
```ruby
type PositiveInt <: Integer where > 0
def process(count: PositiveInt): String
end
```

**Test Coverage**: 16 test cases
**Files Created**: `lib/t_ruby/constraint_checker.rb`, `spec/t_ruby/constraint_checker_spec.rb`

---

### ✅ Phase 2: Type Inference System

**Goal**: Infer types from code patterns to reduce annotation burden

**Status**: COMPLETED ✅

**Implementation Details**:
- Created `lib/t_ruby/type_inferencer.rb` with:
  - `InferredType` - Type with confidence scoring ✅
  - `TypeInferencer` - Main inference engine ✅
  - Literal inference (strings, integers, floats, booleans, symbols, arrays, hashes) ✅
  - Method call return type inference ✅
  - Return type inference from function body ✅
  - Parameter type inference from usage patterns ✅
  - Generic parameter inference ✅
  - Type narrowing in conditionals (is_a?, nil?) ✅
  - Operator result type inference ✅
- Confidence scoring (HIGH, MEDIUM, LOW)
- Variable type tracking

**Syntax Example**:
```ruby
def add(a, b)  # Inferred as (Integer, Integer) -> Integer from usage
  a + b
end
```

**Test Coverage**: 25 test cases
**Files Created**: `lib/t_ruby/type_inferencer.rb`, `spec/t_ruby/type_inferencer_spec.rb`

---

### ✅ Phase 3: Runtime Type Validation

**Goal**: Generate runtime checks to validate types at execution

**Status**: COMPLETED ✅

**Implementation Details**:
- Created `lib/t_ruby/runtime_validator.rb` with:
  - `ValidationConfig` - Configuration options ✅
  - `RuntimeValidator` - Validation code generator ✅
  - Parameter validation generation ✅
  - Return value validation ✅
  - Union type validation ✅
  - Generic type validation (Array<T>, Hash<K,V>) ✅
  - Intersection type validation ✅
  - Optional type (T?) validation ✅
  - `RuntimeTypeError` - Custom error class ✅
  - `RuntimeTypeChecks` - Mixin module for classes ✅
- Source transformation to inject validation code
- Validation module generation
- Configurable: validate_all, validate_public_only, raise_on_error

**Generated Code Example**:
```ruby
def process(items: Array<String>): Integer
  raise TypeError unless items.is_a?(Array) && items.all? { |i| i.is_a?(String) }
  # ... function body ...
end
```

**Test Coverage**: 15 test cases
**Files Created**: `lib/t_ruby/runtime_validator.rb`, `spec/t_ruby/runtime_validator_spec.rb`

---

### ✅ Phase 4: Type Checking & Flow Analysis

**Goal**: Implement static type checking to catch errors before runtime

**Status**: COMPLETED ✅

**Implementation Details**:
- Created `lib/t_ruby/type_checker.rb` with:
  - `TypeCheckError` - Structured error with suggestions ✅
  - `TypeHierarchy` - Subtype relationship tracking ✅
  - `TypeScope` - Lexical scope for variable types ✅
  - `FlowContext` - Flow-sensitive type narrowing ✅
  - `TypeChecker` - Main type checking engine ✅
- Function call argument type checking ✅
- Return type compatibility checking ✅
- Assignment type checking ✅
- Operator type compatibility ✅
- Type narrowing in conditionals (is_a?, nil?) ✅
- Type alias resolution ✅
- Detailed error messages with suggestions ✅

**Expected Warnings**:
```
Type mismatch in function call:
  Function expects: String
  Provided: Integer
  Suggestion: Convert to string with .to_s
```

**Test Coverage**: 20 test cases
**Files Created**: `lib/t_ruby/type_checker.rb`, `spec/t_ruby/type_checker_spec.rb`

---

### ✅ Phase 5: Performance Optimization

**Goal**: Optimize compilation speed and generated code performance

**Status**: COMPLETED ✅

**Implementation Details**:
- Created `lib/t_ruby/cache.rb` with:
  - `CacheEntry` - Entry with metadata and access tracking ✅
  - `MemoryCache` - LRU in-memory cache ✅
  - `FileCache` - Persistent file-based cache ✅
  - `ParseCache` - AST parse tree caching ✅
  - `TypeResolutionCache` - Type resolution caching ✅
  - `DeclarationCache` - Declaration file caching ✅
  - `IncrementalCompiler` - Skip unchanged files ✅
  - `ParallelProcessor` - Multi-threaded file processing ✅
  - `CompilationProfiler` - Performance profiling ✅
- LRU eviction strategy
- File modification time tracking
- Dependency-aware recompilation
- Work-stealing parallel processing

**Test Coverage**: 20 test cases
**Files Created**: `lib/t_ruby/cache.rb`, `spec/t_ruby/cache_spec.rb`

---

### ✅ Phase 6: Package & Distribution

**Goal**: Enable sharing of typed Ruby libraries

**Status**: COMPLETED ✅

**Implementation Details**:
- Created `lib/t_ruby/package_manager.rb` with:
  - `SemanticVersion` - Version parsing and comparison ✅
  - `VersionConstraint` - ^, ~, >=, <=, etc. constraints ✅
  - `PackageManifest` - .trb-manifest.json handling ✅
  - `DependencyResolver` - Transitive dependency resolution ✅
  - `PackageRegistry` - Package storage and lookup ✅
  - `PackageManager` - Main package management API ✅
- Package manifest (.trb-manifest.json)
- Dependency resolution with conflict detection
- Version constraint satisfaction
- Lockfile generation
- Package search and listing
- Deprecation support

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

**Test Coverage**: 18 test cases
**Files Created**: `lib/t_ruby/package_manager.rb`, `spec/t_ruby/package_manager_spec.rb`

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

