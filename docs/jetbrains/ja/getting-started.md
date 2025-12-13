<p align="center">
  <img src="https://avatars.githubusercontent.com/u/248530250" alt="T-Ruby" height="120">
</p>

<h1 align="center">T-Ruby for JetBrains</h1>

<p align="center">
  <a href="https://type-ruby.github.io">公式サイト</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="https://github.com/type-ruby/t-ruby">GitHub</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="https://plugins.jetbrains.com/plugin/29335-t-ruby">JetBrains マーケットプレイス</a>
</p>

---

T-Ruby JetBrainsプラグインへようこそ！このガイドでは、型付きRuby開発のためのT-Rubyプラグインのインストールと設定方法を説明します。

> **Note**: このプラグインはIntelliJ IDEA、RubyMine、WebStormなど、すべてのJetBrains IDEで動作します。

## 前提条件

プラグインをインストールする前に、以下が必要です：

- **JetBrains IDE** 2023.1以上（IntelliJ IDEA、RubyMine、WebStormなど）
- **Ruby** 3.0以上
- **T-Rubyコンパイラ** (`trc`) がインストールされ、PATHに登録されていること

### T-Rubyコンパイラのインストール

```bash
# gemでインストール（推奨）
gem install t-ruby
```

インストールの確認：
```bash
trc --version
```

## インストール方法

### 方法1: JetBrains マーケットプレイス（推奨）

1. JetBrains IDEを開きます
2. `Settings/Preferences` > `Plugins`に移動します
3. `Marketplace`タブで"T-Ruby"を検索します
4. **Install**をクリックします
5. IDEを再起動します

または[JetBrains マーケットプレイス](https://plugins.jetbrains.com/plugin/29335-t-ruby)から直接インストールしてください。

### 方法2: ディスクからインストール（予定）

1. [Releases](https://github.com/type-ruby/t-ruby/releases)から`.zip`ファイルをダウンロードします
2. `Settings/Preferences` > `Plugins`に移動します
3. 歯車アイコン > `Install Plugin from Disk...`をクリックします
4. ダウンロードしたファイルを選択します

### 方法3: ソースからビルド

```bash
# リポジトリをクローン
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby/editors/jetbrains

# Gradleでビルド
./gradlew buildPlugin

# ビルドされたプラグインはbuild/distributions/に生成されます
```

## 設定

インストール後、`Settings/Preferences` > `Languages & Frameworks` > `T-Ruby`でプラグインを構成します：

### 設定オプション

| オプション | デフォルト | 説明 |
|------------|---------|------|
| T-Rubyコンパイラパス | `trc` | T-Rubyコンパイラのパス |
| リアルタイム診断を有効化 | `true` | 入力中にエラーをチェック |
| 自動補完を有効化 | `true` | 型ベースの自動補完 |

## 機能

### シンタックスハイライト

プラグインは以下のファイルに対して完全なシンタックスハイライトを提供します：
- `.trb`ファイル（T-Rubyソースファイル）
- `.d.trb`ファイル（T-Ruby宣言ファイル）

型アノテーション、インターフェース、型エイリアスは区別してハイライトされます。

### IntelliSense

- **自動補完**: パラメータと戻り値の型の提案
- **ホバー**: シンボルの上にマウスを置いて型情報を表示
- **定義へ移動**: `Ctrl+Click`で型/関数の定義へジャンプ

### 診断

以下のリアルタイムエラーチェック：
- 不明な型
- 重複定義
- 構文エラー

### アクション

`Find Action`（`Ctrl+Shift+A` / `Cmd+Shift+A`）からアクセス：

| アクション | 説明 |
|------------|------|
| `T-Ruby: Compile Current File` | 現在の`.trb`ファイルをコンパイル |
| `T-Ruby: Generate Declaration File` | ソースから`.d.trb`を生成 |

## クイックスタート例

1. 新しいファイル`hello.trb`を作成します：

```trb
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

### プラグインが動作しない

1. `trc`がインストールされているか確認: `which trc`
2. 設定でパスを確認: `Settings` > `Languages & Frameworks` > `T-Ruby`
3. IDEログを確認: `Help` > `Show Log in Finder/Explorer`

### シンタックスハイライトが機能しない

1. ファイル拡張子が`.trb`または`.d.trb`であることを確認
2. ファイルタイプの関連付けを確認: `Settings` > `Editor` > `File Types`

### パフォーマンスの問題

- 大きなファイルの診断を無効化
- IDEを再起動

## 次のステップ

- [シンタックスハイライトガイド](../../syntax-highlighting/ja/guide.md)
- [T-Ruby言語リファレンス](https://github.com/type-ruby/t-ruby/wiki)
- [Issue報告](https://github.com/type-ruby/t-ruby/issues)

## サポート

質問やバグ報告はGitHub Issuesをご覧ください：
https://github.com/type-ruby/t-ruby/issues
