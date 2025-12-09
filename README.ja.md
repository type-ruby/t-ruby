<p align="center">
  <img src="https://avatars.githubusercontent.com/u/248530250" alt="T-Ruby" height="170">
</p>

<h1 align="center">T-Ruby</h1>

<p align="center">
  <strong>Ruby のための TypeScript スタイルの型</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/CI-passing-brightgreen" alt="CI: passing" />
  <img src="https://img.shields.io/badge/ruby-3.0+-cc342d" alt="Ruby 3.0+" />
  <img src="https://img.shields.io/badge/gem-v0.1.0-blue" alt="Gem: v0.1.0" />
  <img src="https://img.shields.io/badge/downloads-0-lightgrey" alt="Downloads" />
  <img src="https://img.shields.io/badge/coverage-90%25-brightgreen" alt="Coverage: 90%" />
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

```ruby
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
git clone https://github.com/pyhyun/t-ruby
cd t-ruby && bundle install
```

### インストール確認

```bash
trc --version
```

---

## クイックスタート

### 1. `.trb` を書く

```ruby
# hello.trb
def greet(name: String): String
  "Hello, #{name}!"
end

puts greet("world")
```

### 2. コンパイル

```bash
trc hello.trb
```

### 3. 実行

```bash
ruby build/hello.rb
# => Hello, world!
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

## クイックリンク

**はじめに**
- [VS Code 拡張](./docs/vscode/ja/getting-started.md)
- [Vim セットアップ](./docs/vim/ja/getting-started.md)
- [Neovim セットアップ](./docs/neovim/ja/getting-started.md)

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
