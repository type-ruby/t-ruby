# T-Ruby JetBrainsプラグイン

[![JetBrains Marketplace](https://img.shields.io/jetbrains/plugin/v/29335-t-ruby.svg)](https://plugins.jetbrains.com/plugin/29335-t-ruby)

JetBrains IDE（RubyMine、IntelliJ IDEA、WebStormなど）向けのT-Ruby言語サポートプラグインです。

## 機能

- **シンタックスハイライト**: `.trb`および`.d.trb`ファイルの完全なシンタックスハイライト
- **コード補完**: 型認識オートコンプリート提案
- **リアルタイム診断**: インライン型エラー報告
- **定義へ移動**: 型および関数定義へのナビゲーション
- **ホバー情報**: ホバー時の型情報表示
- **コンパイルコマンド**: IDEから直接T-RubyファイルをRubyにコンパイル

## 必要条件

- JetBrains IDE 2024.2以降
- [LSP4IJプラグイン](https://plugins.jetbrains.com/plugin/23257-lsp4ij)がインストール済み
- T-Rubyコンパイラ（`trc`）がPATHにインストール済み

### T-Rubyコンパイラのインストール

```bash
gem install t-ruby
```

## インストール

### JetBrains Marketplaceから

1. JetBrains IDEを開く
2. **Settings** → **Plugins** → **Marketplace**に移動
3. "T-Ruby"を検索
4. **Install**をクリック

### 手動インストール

1. [Releases](https://github.com/type-ruby/t-ruby/releases)から最新の`.zip`をダウンロード
2. **Settings** → **Plugins** → **⚙️** → **Install Plugin from Disk...**に移動
3. ダウンロードした`.zip`ファイルを選択

## 使い方

### T-Rubyファイルの作成

`.trb`拡張子で新しいファイルを作成:

```ruby
# example.trb
type UserId = Integer

def greet(name: String): String
  "Hello, #{name}!"
end

def find_user(id: UserId): User | nil
  # ...
end
```

### コンパイル

- **キーボード**: `Ctrl+Shift+T`（macOS: `Cmd+Shift+T`）
- **メニュー**: **Tools** → **T-Ruby** → **Compile T-Ruby File**
- **コンテキストメニュー**: `.trb`ファイルを右クリック → **Compile T-Ruby File**

### 宣言ファイルの生成

- **キーボード**: `Ctrl+Shift+D`（macOS: `Cmd+Shift+D`）
- **メニュー**: **Tools** → **T-Ruby** → **Generate Declaration File**

## 設定

**Settings** → **Tools** → **T-Ruby**:

| 設定 | 説明 | デフォルト |
|------|------|-----------|
| T-Ruby compiler path | `trc`実行ファイルのパス | `trc`（PATHから） |
| Enable LSP | LSP機能を有効化 | `true` |
| Enable diagnostics | リアルタイム型エラーを表示 | `true` |
| Enable completion | コード補完を有効化 | `true` |

## 対応IDE

- RubyMine 2024.2+
- IntelliJ IDEA 2024.2+（Ultimate & Community）
- WebStorm 2024.2+
- PyCharm 2024.2+
- GoLand 2024.2+
- その他のJetBrains IDE 2024.2+

## ソースからビルド

```bash
# リポジトリをクローン
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby/editors/jetbrains

# プラグインをビルド
./gradlew buildPlugin

# プラグインZIPはbuild/distributions/に作成されます
```

### 開発モードで実行

```bash
./gradlew runIde
```

プラグインがインストールされたサンドボックスIDEインスタンスが起動します。

## ライセンス

MIT License - 詳細は[LICENSE](../../LICENSE)を参照

## リンク

- [JetBrains Marketplace](https://plugins.jetbrains.com/plugin/29335-t-ruby)
- [T-Rubyドキュメント](https://type-ruby.github.io)
- [GitHubリポジトリ](https://github.com/type-ruby/t-ruby)
- [LSP4IJプラグイン](https://plugins.jetbrains.com/plugin/23257-lsp4ij)
