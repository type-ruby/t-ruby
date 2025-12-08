# Testing Principles and Guidelines

This document outlines the testing principles and practices followed in the t-ruby project.

## Core Testing Principles

### 1. Comprehensive Test Coverage
- Test each feature from multiple angles and scenarios
- Create diverse test cases that cover both happy paths and edge cases
- Ensure all code paths are exercised by tests
- Target: 100% code coverage for all production code

### 2. Test Integrity
**Critical Rule: Never create fake passing tests**

- Tests must either pass legitimately or fail
- Failing tests must never be marked as passing through tricks, stubs, or mocks when the underlying functionality doesn't work
- If a test consistently fails and the solution is unclear:
  1. Document the failure and the reasons it's difficult to solve
  2. Leave the test failing (don't skip or mark as pending)
  3. Create an issue to track the problem for future resolution
  4. Once a decision is made to remove the test, it should be explicitly deleted by the developer

**Examples of what NOT to do:**
- ❌ Using `skip` or `pending` to hide failures
- ❌ Creating a stub that returns a false value to make a test pass
- ❌ Removing assertions that would expose the real issue
- ❌ Using `allow` to mock away actual functionality that should be tested

### 3. Clear Test Organization

Tests are organized by:
- **Spec file structure**: Each class/module has its own spec file
  - Core: `version_spec.rb`, `config_spec.rb`, `compiler_spec.rb`, `cli_spec.rb`
  - Type System: `parser_spec.rb`, `union_type_spec.rb`, `generics_spec.rb`, `intersection_type_spec.rb`
  - Tooling: `lsp_server_spec.rb`, `declaration_generator_spec.rb`, `watcher_spec.rb`
  - Advanced: `constraint_checker_spec.rb`, `type_inferencer_spec.rb`, `type_checker_spec.rb`
  - Performance: `cache_spec.rb`, `runtime_validator_spec.rb`, `package_manager_spec.rb`

- **Context groups**: Related test cases are grouped using `describe` and `context` blocks
  - Tests follow AAA pattern: Arrange, Act, Assert

### 4. Test Maintenance

- Update tests when code behavior changes
- Keep tests focused and readable
- Use clear, descriptive test names that explain what is being tested
- Each test should validate a single behavior

## Running Tests

### Run all tests with coverage
```bash
bundle exec rspec
# or
ruby -Ilib -rrspec -e 'RSpec::Core::Runner.run(["spec"])'
```

### Run tests with specific pattern
```bash
ruby -Ilib -rrspec -e 'RSpec::Core::Runner.run(["spec/t_ruby/config_spec.rb"])'
```

### View coverage report
After running tests, view the HTML coverage report:
```bash
open coverage/index.html
```

## Test Configuration

- **Framework**: RSpec 3.x
- **Coverage tracking**: SimpleCov
- **Config file**: `.rspec` - Controls RSpec behavior
- **Setup file**: `spec/spec_helper.rb` - Configures test environment and coverage

## Current Test Coverage

**Total: 260 examples, 0 failures**

| Module | Tests | Status |
|--------|-------|--------|
| Core (Parser, Compiler, CLI) | 57 | ✅ |
| Type System (Union, Generic, Intersection) | 24 | ✅ |
| LSP Server | 29 | ✅ |
| Declaration Generator | 34 | ✅ |
| Constraint Checker | 16 | ✅ |
| Type Inferencer | 25 | ✅ |
| Runtime Validator | 15 | ✅ |
| Type Checker | 20 | ✅ |
| Cache System | 20 | ✅ |
| Package Manager | 18 | ✅ |
| Watcher | 2 | ✅ |

## Contributing Tests

When adding new features:

1. Write tests first (TDD recommended)
2. Follow the organization structure shown above
3. Ensure tests are independent and can run in any order
4. Test both success and failure scenarios
5. Don't remove or skip failing tests - fix them or document why they can't be fixed
6. Run full test suite before submitting changes
7. Maintain or improve code coverage percentage
