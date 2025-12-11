# Commit Convention Guide

T-Ruby follows [Conventional Commits](https://www.conventionalcommits.org/) specification for automated versioning and changelog generation.

## Commit Message Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

## Types

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat` | New feature | Minor (0.X.0) |
| `fix` | Bug fix | Patch (0.0.X) |
| `docs` | Documentation only | None |
| `style` | Code style (formatting, semicolons) | None |
| `refactor` | Code refactoring | None |
| `perf` | Performance improvement | Patch |
| `test` | Adding/updating tests | None |
| `build` | Build system changes | None |
| `ci` | CI/CD configuration | None |
| `chore` | Other changes | None |

## Breaking Changes

Add `!` after type/scope or include `BREAKING CHANGE:` in footer:

```
feat!: remove deprecated API
```

or

```
feat(parser): add new syntax support

BREAKING CHANGE: old syntax no longer supported
```

Breaking changes trigger a **Major** version bump (X.0.0).

## Scopes

Common scopes for T-Ruby:

| Scope | Description |
|-------|-------------|
| `parser` | Parser and syntax |
| `compiler` | Compilation pipeline |
| `type-checker` | Type checking |
| `lsp` | Language Server Protocol |
| `cli` | Command line interface |
| `vscode` | VS Code extension |
| `jetbrains` | JetBrains plugin |
| `wasm` | WebAssembly target |
| `docs` | Documentation |
| `ci` | CI/CD |
| `deps` | Dependencies |

## Examples

### Features

```
feat(parser): add support for intersection types

Implements A & B syntax for type intersections.
Closes #123
```

```
feat(lsp): add semantic token highlighting

- Support for type annotations
- Support for interfaces
- Support for generics
```

### Bug Fixes

```
fix(compiler): handle nested generic types correctly

Previously, types like Map<String, Array<Integer>> would fail to parse.
This commit fixes the recursive parsing logic.

Fixes #456
```

### Documentation

```
docs: update installation guide for Ruby 3.3
```

### Refactoring

```
refactor(type-checker): simplify constraint resolution

- Extract constraint solver into separate module
- Use SMT solver for complex constraints
- Improve error messages
```

### Breaking Changes

```
feat(parser)!: change interface syntax to match Ruby 3.2

BREAKING CHANGE: Interface definitions now use `module` keyword
instead of `interface`. Migration guide: see docs/migration.md
```

## Automated Release

When commits following this convention are pushed to `main`:

1. **semantic-release** analyzes commits since last release
2. Determines version bump (major/minor/patch)
3. Generates CHANGELOG.md
4. Creates GitHub release
5. Triggers release workflow

## Validation

Commits are validated by:
- Pre-commit hooks (optional, via husky)
- CI checks on pull requests

### Local Setup (optional)

```bash
# Install commitlint
npm install -g @commitlint/cli @commitlint/config-conventional

# Validate last commit
echo "feat: test" | commitlint
```

## Tips

1. **Keep subjects short** - 50 characters or less
2. **Use imperative mood** - "add" not "added" or "adds"
3. **Don't end with period** - No punctuation at end of subject
4. **Explain why, not what** - Body should explain motivation
5. **Reference issues** - Use "Fixes #123" or "Closes #123"

## Migration from Old Format

If converting existing commits:

```bash
# Interactive rebase to rewrite commit messages
git rebase -i HEAD~10  # last 10 commits

# Or use git filter-branch for entire history (advanced)
```

## Resources

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [semantic-release](https://semantic-release.gitbook.io/)
- [Angular Commit Guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit)
