<p align="center">
  <img src="https://avatars.githubusercontent.com/u/248530250" alt="T-Ruby" height="170">
</p>

<h1 align="center">T-Ruby</h1>

<p align="center">
  <strong>TypeScript-style types for Ruby</strong>
</p>

<p align="center">
  <a href="https://github.com/type-ruby/t-ruby/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/type-ruby/t-ruby/ci.yml?label=CI" alt="CI" /></a>
  <img src="https://img.shields.io/badge/ruby-3.0+-cc342d" alt="Ruby 3.0+" />
  <a href="https://rubygems.org/gems/t-ruby"><img src="https://img.shields.io/gem/v/t-ruby" alt="Gem Version" /></a>
  <img src="https://img.shields.io/gem/dt/t-ruby" alt="Downloads" />
  <a href="https://coveralls.io/github/type-ruby/t-ruby?branch=main"><img src="https://coveralls.io/repos/github/type-ruby/t-ruby/badge.svg?branch=main" alt="Coverage" /></a>
</p>

<p align="center">
  <a href="https://type-ruby.github.io"><strong>🌐 Official Website</strong></a>
</p>

<p align="center">
  <a href="#install">Install</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="#quick-start">Quick Start</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="#features">Features</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./ROADMAP.md">Roadmap</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./README.ko.md">한국어</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./README.ja.md">日本語</a>
</p>

> [!NOTE]
> This project is still experimental. If you support this project, please give it a star! If you have suggestions for improvements, please open an issue. Pull requests are also welcome!

---

## What is T-Ruby?

T-Ruby is a typed layer for Ruby, inspired by TypeScript.
It ships as a single executable called `trc`.

Write `.trb` files with type annotations, compile to standard `.rb` files.
Types are erased at compile time — your Ruby code runs everywhere Ruby runs.

```bash
trc hello.trb                  # Compile to Ruby
```

The `trc` compiler also generates `.rbs` signature files for tools like
Steep and Ruby LSP. Gradually adopt types in existing Ruby projects
with zero runtime overhead.

```bash
trc --watch src/               # Watch mode
trc --emit-rbs src/            # Generate .rbs files
trc --check src/               # Type check without compiling
```

---

## Why T-Ruby?

We are friends of Ruby — Rubyists who still use and love Ruby.

We know Ruby has duck typing and dynamic types in its DNA.
But we couldn't ignore that static type systems are becoming
essential in real-world production environments.

The Ruby ecosystem has debated this for years,
yet hasn't quite found its answer.

### Existing Approaches

**1) Sorbet**
- Types are written like comments above your code.
- It feels like writing JSDoc and hoping the IDE catches errors.

```ruby
# Sorbet
extend T::Sig

sig { params(name: String).returns(String) }
def greet(name)
  "Hello, #{name}!"
end
```

**2) RBS**
- Ruby's official approach, where `.rbs` files are separate type definition files like TypeScript's `.d.ts`.
- But in Ruby, you have to write them manually or rely on "implicit inference + manual fixes" — still cumbersome.

```rbs
# greet.rbs (separate file)
def greet: (String name) -> String
```

```ruby
# greet.rb (no type info)
def greet(name)
  "Hello, #{name}!"
end
```

### T-Ruby
- Like TypeScript, types live inside your code.
- Write `.trb`, and `trc` generates both `.rb` and `.rbs`.

```trb
# greet.trb
def greet(name: String): String
  "Hello, #{name}!"
end
```

```bash
trc greet.trb
# => build/greet.rb
#  + build/greet.rbs
```

### Others...
There are new languages like **Crystal**, but strictly speaking, it's a different language from Ruby.

We still love Ruby, and we want this to be
**progress within the Ruby ecosystem, not an escape from it.**

---

## Install

```bash
# with RubyGems (recommended)
gem install t-ruby

# from source
git clone https://github.com/type-ruby/t-ruby
cd t-ruby && bundle install
```

### Verify installation

```bash
trc --version
```

---

## Quick start

### 1. Initialize project

```bash
trc --init
```

This creates:
- `trbconfig.yml` — project configuration
- `src/` — source directory
- `build/` — output directory

### 2. Write `.trb`

```trb
# src/hello.trb
def greet(name: String): String
  "Hello, #{name}!"
end

puts greet("world")
```

### 3. Compile

```bash
trc src/hello.trb
```

### 4. Run

```bash
ruby build/hello.rb
# => Hello, world!
```

### 5. Watch mode

```bash
trc -w           # Watch directories from trbconfig.yml (default: src/)
trc -w lib/      # Watch specific directory
```

Files are automatically recompiled on change.

---

## Configuration

`trc --init` generates a `trbconfig.yml` file with all available options:

```yaml
# T-Ruby configuration file
# See: https://type-ruby.github.io/docs/getting-started/project-configuration

source:
  include:
    - src
  exclude: []
  extensions:
    - ".trb"
    - ".rb"

output:
  ruby_dir: build
  # rbs_dir: sig  # Optional: separate directory for .rbs files
  preserve_structure: true
  # clean_before_build: false

compiler:
  strictness: standard  # strict | standard | permissive
  generate_rbs: true
  target_ruby: "3.0"
  # experimental: []
  # checks:
  #   no_implicit_any: false
  #   no_unused_vars: false
  #   strict_nil: false

watch:
  # paths: []  # Additional paths to watch
  debounce: 100
  # clear_screen: false
  # on_success: "bundle exec rspec"
```

---

## Features

- **Type annotations** — Parameter and return types, erased at compile time
- **Union types** — `String | Integer | nil`
- **Generics** — `Array<User>`, `Hash<String, Integer>`
- **Interfaces** — Define contracts between objects
- **Type aliases** — `type UserID = Integer`
- **RBS generation** — Works with Steep, Ruby LSP, Sorbet
- **IDE support** — VS Code, Neovim with LSP
- **Watch mode** — Recompile on file changes

---

## Links

**IDE Support**
- [VS Code Extension (and Cursor)](https://github.com/type-ruby/t-ruby-vscode)
- [JetBrains Plugin](./docs/jetbrains/en/getting-started.md)
- [Vim Setup](./docs/vim/en/getting-started.md)
- [Neovim Setup](./docs/neovim/en/getting-started.md)

**Guides**
- [Syntax Highlighting](./docs/syntax-highlighting/en/guide.md)

---

## Status

> **Experimental** — T-Ruby is under active development.
> APIs may change. Not recommended for production use yet.

| Milestone | Status |
|-----------|--------|
| Type Parsing & Erasure | ✅ |
| Core Type System | ✅ |
| LSP & IDE Support | ✅ |
| Advanced Features | ✅ |

See [ROADMAP.md](./ROADMAP.md) for details.

---

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

[MIT](./LICENSE)
