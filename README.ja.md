<p align="center">
  <img src="https://avatars.githubusercontent.com/u/248530250" alt="T-Ruby" height="170">
</p>

<h1 align="center">T-Ruby</h1>

<p align="center">
  <strong>Ruby のための TypeScript スタイルの型</strong>
</p>

<p align="center">
  <a href="https://github.com/type-ruby/t-ruby/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/type-ruby/t-ruby/ci.yml?label=CI" alt="CI" /></a>
  <img src="https://img.shields.io/badge/ruby-3.0+-cc342d" alt="Ruby 3.0+" />
  <a href="https://rubygems.org/gems/t-ruby"><img src="https://img.shields.io/gem/v/t-ruby" alt="Gem Version" /></a>
  <img src="https://img.shields.io/gem/dt/t-ruby" alt="Downloads" />
  <a href="https://coveralls.io/github/type-ruby/t-ruby?branch=main"><img src="https://coveralls.io/repos/github/type-ruby/t-ruby/badge.svg?branch=main" alt="Coverage" /></a>
</p>

<p align="center">
  <a href="#インストール">インストール</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="#クイックスタート">クイックスタート</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="#機能">機能</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./ROADMAP.md">ロードマップ</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./README.md">English</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./README.ko.md">한국어</a>
</p>

> [!NOTE]
> このプロジェクトはまだ実験段階です。このプロジェクトを支持してくださる方は、スターをお願いします！改善のご提案があれば Issue でお知らせください。PR も歓迎します！

---

## T-Ruby とは？

T-Ruby は TypeScript にインスパイアされた Ruby 用の型レイヤーです。
`trc` という単一の実行ファイルとして提供されます。

型アノテーション付きの `.trb` ファイルを書き、標準の `.rb` ファイルにコンパイルします。
型はコンパイル時に削除されます — Ruby が動く場所ならどこでもコードが動作します。

```bash
trc hello.trb                  # Ruby にコンパイル
```

`trc` コンパイラは Steep や Ruby LSP などのツール用に `.rbs` シグネチャファイルも生成します。
ランタイムオーバーヘッドなしで、既存の Ruby プロジェクトに段階的に型を導入できます。

```bash
trc --watch src/               # ウォッチモード
trc --emit-rbs src/            # .rbs ファイル生成
trc --check src/               # コンパイルなしで型チェックのみ
```

---

## なぜ T-Ruby なのか？

私たちは Ruby の友であり、今も Ruby を使い続ける Rubyist です。

Ruby がダックタイピングと動的型システムの DNA を持つ言語であることはよく分かっています。
しかし、現実の産業環境で静的型システムが必須になりつつあることも
否定できませんでした。

Ruby エコシステムはこの問題について長年議論してきましたが、
まだ明確な答えを出せていないように思います。

### 既存のアプローチ

**1) Sorbet**
- コードの上にコメントのように型を書きます。
- まるで JSDoc を書いて IDE がエラーを拾ってくれることを期待するようなものです。

```ruby
# Sorbet
extend T::Sig

sig { params(name: String).returns(String) }
def greet(name)
  "Hello, #{name}!"
end
```

**2) RBS**
- Ruby 公式のアプローチで、`.rbs` ファイルは TypeScript の `.d.ts` のような型定義用の別ファイルです。
- しかし Ruby では手動で書くか、「暗黙の推論 + 手動修正」に頼る必要があり、依然として面倒です。

```rbs
# greet.rbs（別ファイル）
def greet: (String name) -> String
```

```ruby
# greet.rb（型情報なし）
def greet(name)
  "Hello, #{name}!"
end
```

### T-Ruby
- TypeScript のように、型がコードの中にあります。
- `.trb` で書けば、`trc` が `.rb` と `.rbs` の両方を生成します。

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

### その他...
**Crystal** のような新しい言語もありますが、厳密には Ruby とは別の言語です。

私たちは今も Ruby を愛しており、
これが Ruby エコシステムからの**脱出ではなく、進歩**であることを願っています。

---

## インストール

```bash
# RubyGems でインストール（推奨）
gem install t-ruby

# ソースからインストール
git clone https://github.com/type-ruby/t-ruby
cd t-ruby && bundle install
```

### インストール確認

```bash
trc --version
```

---

## クイックスタート

### 1. プロジェクト初期化

```bash
trc --init
```

以下が生成されます：
- `trbconfig.yml` — プロジェクト設定ファイル
- `src/` — ソースディレクトリ
- `build/` — 出力ディレクトリ

### 2. `.trb` を書く

```trb
# src/hello.trb
def greet(name: String): String
  "Hello, #{name}!"
end

puts greet("world")
```

### 3. コンパイル

```bash
trc src/hello.trb
```

### 4. 実行

```bash
ruby build/hello.rb
# => Hello, world!
```

### 5. ウォッチモード

```bash
trc -w           # trbconfig.yml のソースディレクトリを監視（デフォルト: src/）
trc -w lib/      # 特定のディレクトリを監視
```

ファイル変更時に自動で再コンパイルされます。

---

## 設定

`trc --init` はすべての設定オプションを含む `trbconfig.yml` ファイルを生成します：

```yaml
# T-Ruby 設定ファイル
# 参考: https://type-ruby.github.io/docs/getting-started/project-configuration

source:
  include:
    - src
  exclude: []
  extensions:
    - ".trb"
    - ".rb"

output:
  ruby_dir: build
  # rbs_dir: sig  # オプション: .rbs ファイル用の別ディレクトリ
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
  # paths: []  # 追加の監視パス
  debounce: 100
  # clear_screen: false
  # on_success: "bundle exec rspec"
```

---

## 機能

- **型アノテーション** — パラメータと戻り値の型、コンパイル時に削除
- **ユニオン型** — `String | Integer | nil`
- **ジェネリクス** — `Array<User>`, `Hash<String, Integer>`
- **インターフェース** — オブジェクト間の契約を定義
- **型エイリアス** — `type UserID = Integer`
- **RBS 生成** — Steep、Ruby LSP、Sorbet と連携
- **IDE サポート** — VS Code、Neovim + LSP
- **ウォッチモード** — ファイル変更時に自動再コンパイル

---

## リンク

**IDE サポート**
- [VS Code 拡張 (および Cursor)](https://github.com/type-ruby/t-ruby-vscode)
- [JetBrains プラグイン](https://github.com/type-ruby/t-ruby-jetbrains)
- [Vim / Neovim](https://github.com/type-ruby/t-ruby-vim)

**ガイド**
- [シンタックスハイライト](./docs/syntax-highlighting/ja/guide.md)

---

## ステータス

> **実験的** — T-Ruby は活発に開発中です。
> API が変更される可能性があります。本番環境での使用はまだ推奨しません。

| マイルストーン | ステータス |
|---------------|----------|
| 型パース & 削除 | ✅ |
| コア型システム | ✅ |
| LSP & IDE サポート | ✅ |
| 高度な機能 | ✅ |

詳細は [ROADMAP.md](./ROADMAP.md) を参照してください。

---

## コントリビュート

コントリビューションを歓迎します！Issue や Pull Request をお気軽にお送りください。

## ライセンス

[MIT](./LICENSE)
