# T-Ruby for VS Code - はじめに

T-Ruby VS Code拡張機能へようこそ！このガイドでは、型付きRuby開発のためのT-Ruby拡張機能のインストールと設定方法を説明します。

## 前提条件

拡張機能をインストールする前に、以下が必要です：

- **Visual Studio Code** 1.75.0以上
- **Ruby** 3.0以上
- **T-Rubyコンパイラ** (`trc`) がインストールされ、PATHに登録されていること

### T-Rubyコンパイラのインストール

```bash
# gemでインストール（推奨）
gem install t-ruby

# またはソースからビルド
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby
bundle install
rake install
```

インストールの確認：
```bash
trc --version
```

## インストール方法

### 方法1: VS Code マーケットプレイス（推奨）

1. VS Codeを開きます
2. `Ctrl+Shift+X`（Windows/Linux）または`Cmd+Shift+X`（macOS）で拡張機能タブを開きます
3. "T-Ruby"を検索します
4. **インストール**をクリックします

### 方法2: VSIXファイルからインストール

1. [Releases](https://github.com/type-ruby/t-ruby/releases)から`.vsix`ファイルをダウンロードします
2. VS Codeを開きます
3. `Ctrl+Shift+P`を押して"VSIXからインストール"と入力します
4. ダウンロードしたファイルを選択します

### 方法3: ソースからビルド

```bash
# リポジトリをクローン
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby/editors/vscode

# 依存関係をインストール
npm install

# 拡張機能をビルド
npm run compile

# 拡張機能をインストール
code --install-extension .
```

## 設定

インストール後、VS Code設定（`Ctrl+,`）で拡張機能を構成します：

```json
{
  "t-ruby.lspPath": "trc",
  "t-ruby.enableLSP": true,
  "t-ruby.diagnostics.enable": true,
  "t-ruby.completion.enable": true
}
```

### 設定オプション

| オプション | 型 | デフォルト | 説明 |
|------------|------|---------|------|
| `t-ruby.lspPath` | string | `"trc"` | T-Rubyコンパイラのパス |
| `t-ruby.enableLSP` | boolean | `true` | 言語サーバーを有効化 |
| `t-ruby.diagnostics.enable` | boolean | `true` | リアルタイム診断を有効化 |
| `t-ruby.completion.enable` | boolean | `true` | 自動補完を有効化 |

## 機能

### シンタックスハイライト

拡張機能は以下のファイルに対して完全なシンタックスハイライトを提供します：
- `.trb`ファイル（T-Rubyソースファイル）
- `.d.trb`ファイル（T-Ruby宣言ファイル）

型アノテーション、インターフェース、型エイリアスは区別してハイライトされます。

### IntelliSense

- **自動補完**: パラメータと戻り値の型の提案
- **ホバー**: シンボルの上にマウスを置いて型情報を表示
- **定義へ移動**: 型/関数の定義へジャンプ

### 診断

以下のリアルタイムエラーチェック：
- 不明な型
- 重複定義
- 構文エラー

### コマンド

コマンドパレット（`Ctrl+Shift+P`）からアクセス：

| コマンド | 説明 |
|----------|------|
| `T-Ruby: Compile Current File` | 現在の`.trb`ファイルをコンパイル |
| `T-Ruby: Generate Declaration File` | ソースから`.d.trb`を生成 |
| `T-Ruby: Restart Language Server` | LSPサーバーを再起動 |

## クイックスタート例

1. 新しいファイル`hello.trb`を作成します：

```ruby
type UserId = String

interface User
  id: UserId
  name: String
  age: Integer
end

def greet(user: User): String
  "こんにちは、#{user.name}さん！"
end
```

2. ファイルを保存すると、シンタックスハイライトとリアルタイム診断が表示されます

3. 型の上にマウスを置いて定義を確認します

4. `Ctrl+Space`を押して自動補完の提案を受け取ります

## トラブルシューティング

### LSPが起動しない

1. `trc`がインストールされているか確認: `which trc`
2. 設定でパスを確認: `t-ruby.lspPath`
3. 出力パネルを確認: 表示 > 出力 > T-Ruby Language Server

### シンタックスハイライトが機能しない

1. ファイル拡張子が`.trb`または`.d.trb`であることを確認
2. ファイルの関連付けを確認: 表示 > コマンドパレット > "言語モードの変更"

### パフォーマンスの問題

- 大きなファイルの診断を無効化: `"t-ruby.diagnostics.enable": false`
- 言語サーバーを再起動: コマンドパレット > "T-Ruby: Restart Language Server"

## 次のステップ

- [シンタックスハイライトガイド](../../syntax-highlighting/ja/guide.md)
- [T-Ruby言語リファレンス](https://github.com/type-ruby/t-ruby/wiki)
- [Issue報告](https://github.com/type-ruby/t-ruby/issues)

## サポート

質問やバグ報告は以下をご覧ください：
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- Discussions: https://github.com/type-ruby/t-ruby/discussions
