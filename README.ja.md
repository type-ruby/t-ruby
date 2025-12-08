# t-ruby (日本語ドキュメント)

> TypeScript にインスパイアされた Ruby 用の静的型レイヤー。
> `.trb` を書き、`trc` で `.rb` と `.rbs` を生成します。

`t-ruby` は Ruby の上に構築される **オプショナル（段階的）静的型システム** です。

* ソースファイル: `.trb`
* コンパイラ: `trc`
* 設定ファイル: `.trb.yml`
* 出力形式:

  * Ruby 実行コード: `.rb`
  * Ruby 公式シグネチャファイル: `.rbs`（オプション）
  * t-ruby 専用宣言ファイル: `.d.trb`（オプション、RBS より高い表現力）

目的は、Ruby エコシステムを尊重しながら、
Ruby 開発者に **TypeScript に近い快適な開発体験（DX）** を提供することです。

---

## ステータス（Status）

**非常に初期の実験段階です。**
文法・API・挙動は予告なく変更される可能性があります。

現在の最初のゴール:

* 限定的な t-ruby 文法のパース
* 型アノテーションの削除（type erasure）
* 実行可能な Ruby `.rb` の生成
* 必要に応じて最小限の `.rbs` スタブを生成

---

## コンセプト（Concept）

### 1) `.trb` ファイルを書く

```ruby
# hello.trb

def greet(name: String): void
  puts "Hello, #{name} from t-ruby!"
end

greet("world")
```

### 2) `trc` でコンパイル

```bash
trc hello.trb
# => build/hello.rb （必要に応じて .rbs / .d.trb も生成）
```

### 3) Ruby で実行

```bash
ruby build/hello.rb
```

---

## デザイン目標（Design Goals）

### 1. Ruby 開発者のための TypeScript ライクな DX

* オプショナル型（gradual typing）
* `type`、`interface`、ジェネリクス、ユニオン/インターセクション型など
* 単一のコンパイラ CLI: `trc`

### 2. 既存の Ruby エコシステムとの高い互換性

* 標準 Ruby でそのまま動く `.rb` 出力
* Steep や Ruby LSP が読める `.rbs` 出力
* t-ruby 専用の強力な型を格納する `.d.trb` もオプション提供

### 3. RBS を基盤として尊重しつつ、RBS に縛られない

* t-ruby の型システムは RBS の **上位互換（superset）** を目指す
* `.rbs` へ投影しづらい高度な型は、保守的に単純化して出力
* 既存の `.rbs` タイプ資産をそのまま利用可能

### 4. Ruby 文化に合う設定スタイル

* プロジェクト設定は `.trb.yml`
* Ruby の YAML ベース設定文化（例: `.rubocop.yml`, `database.yml`）と一致

---

## `.trb.yml` の例

```yaml
emit:
  rb: true
  rbs: true
  dtrb: false

paths:
  src: ./src
  out: ./build
  stdlib_rbs: ./rbs/stdlib

strict:
  rbs_compat: true
  null_safety: true
  inference: basic
```

---

## ロードマップ（Roadmap）

### 🔹 Milestone 0 – "Hello, t-ruby"

* `trc` CLI スケルトン
* `.trb.yml` の読み込み
* `.trb` → `.rb` の単純変換
* 最初のプロトタイプ公開

### 🔹 Milestone 1 – 基本文法 + 型削除

* 引数型: `name: String`
* 戻り値型: `): String`
* 型アノテーション削除後に Ruby コード生成
* 基本的な構文エラー報告

### 🔹 Milestone 2 – コア型システム

* `type` エイリアス
* `interface` 定義
* ジェネリクス: `Result<T, E>`
* ユニオン / インターセクション型
* `.rbs` への投影設計

### 🔹 Milestone 3 – エコシステム & ツール

* `.d.trb` 宣言ファイルの確立
* 基本 LSP 機能（Go-to-definition, Hover, Diagnostics）
* 既存 Ruby ツールとの統合

---

## 哲学（Philosophy）

t-ruby は Ruby を置き換える言語ではありません。

* Ruby はランタイムおよびホスト言語のまま
* t-ruby はその上に載る **オプショナルな型レイヤー**
* 既存 Ruby プロジェクトに段階的に導入可能であることが重要

また、t-ruby は RBS と競合するものでもありません。

* RBS は Ruby の公式シグネチャ形式として尊重
* t-ruby は RBS を **拡張・再利用** する方向でアプローチ
* 高度な型は `.rbs` では単純化投影し、完全表現は `.d.trb` で提供

---

## 多言語ドキュメント

* English: [README.md](./README.md)
* 한국어: [README.ko.md](./README.ko.md)

---

## ライセンス

未定（TBD）。
