<!-- Follows Document Simplification Principle: max 200 lines -->

# Documentation Guidelines

> This document defines documentation standards for the t-ruby project.

**Translations:** [日本語](./DOCUMENTATION.ja.md) | [한국어](./DOCUMENTATION.ko.md)

---

## 1. Document Types

### Service Documentation

User-facing documentation for software users.

- **Purpose:** Installation guides, usage tutorials, API references
- **Location:** Project root (`README.md`, etc.)
- **Primary language:** English (translations must maintain parity)

### Development Documentation

Contributor-facing documentation for project development.

- **Purpose:** Architecture specs, coding standards, internal APIs
- **Location:** `.claude/` directory
- **Primary language:** English (translations must maintain parity)

---

## 2. Language Policy

### Standard Language

**English** is the project's standard language.

### Required Translations

All documents must be maintained in three languages:

| Language | Suffix | Example |
|----------|--------|---------|
| English | (none) | `README.md` |
| Japanese | `.ja` | `README.ja.md` |
| Korean | `.ko` | `README.ko.md` |

### Translation Links

Each document must include links to its translations at the top:

```markdown
**Translations:** [日本語](./README.ja.md) | [한국어](./README.ko.md)
```

---

## 3. Document Simplification Principle

### Line Limit

All **development documents** must be under **200 lines**.

### Declaration

Every development document must declare compliance at the top:

```markdown
<!-- Follows Document Simplification Principle: max 200 lines -->
```

### Splitting Large Documents

When a document exceeds 200 lines:

1. Create a folder with the same name as the document
2. Move heavy sections to separate files in order of size
3. Keep the main file as an overview with links to split sections
4. All split files must maintain the 200-line limit

**Example:**

Before:
```
.claude/
└── spec.md (350 lines)
```

After:
```
.claude/spec/
├── README.md (overview, ~80 lines)
├── syntax.md (split section)
├── type-system.md (split section)
└── ast.md (split section)
```

---

## 4. File Naming Conventions

### Service Documents

```
README.md           # English (primary)
README.ja.md        # Japanese
README.ko.md        # Korean
```

### Development Documents

```
.claude/docs/DOCUMENTATION.md      # This guide
.claude/spec/README.md             # Language specification
```

### Split Documents

When splitting into a folder, use `README.md` as the main entry point:

```
.claude/{topic}/
├── README.md        # Overview + table of contents
├── section-a.md     # Split section
└── section-b.md     # Split section
```

---

## 5. Maintenance Rules

1. **Sync translations:** When updating any document, update all translations
2. **Check line counts:** Verify documents stay under 200 lines
3. **Update links:** Ensure cross-references remain valid after changes
4. **Review declarations:** All development documents must have the simplification declaration

---

## Related Documents

- [Language Specification](./../spec/README.md)
- [Project README](./../../README.md)
