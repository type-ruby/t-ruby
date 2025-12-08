# T-Ruby シンタックスハイライト ガイド

このガイドでは、様々なエディターでT-Rubyのシンタックスハイライトを設定し、カスタマイズする方法を説明します。

## 概要

T-Rubyシンタックスハイライトは以下の要素を視覚的に区別します：

- **キーワード**: `type`, `interface`, `def`, `end`
- **型**: `String`, `Integer`, `Boolean`, `Array`, `Hash` など
- **型アノテーション**: パラメータと戻り値の型宣言
- **型演算子**: `|`（ユニオン）、`&`（インターセクション）、`<>`（ジェネリクス）
- **コメント**: `#` 単一行コメント
- **文字列**: シングルクォートとダブルクォート両方
- **数値**: 整数と浮動小数点
- **シンボル**: `:symbol_name`

## ハイライトされる要素

### 型エイリアス

```ruby
type UserId = String           # 'type'キーワード、'UserId'を型名として
type Age = Integer             # '='演算子、組み込み型
type UserMap = Hash<UserId, User>  # ジェネリック型
```

### インターフェース

```ruby
interface Printable            # 'interface'キーワード、インターフェース名
  to_string: String           # メンバー名、型アノテーション
  print: void
end                           # 'end'キーワード
```

### 型アノテーション付き関数

```ruby
def greet(name: String): String    # 関数名、型付きパラメータ、戻り値型
  "こんにちは、#{name}さん！"
end

def process(items: Array<String>, count: Integer): Hash<String, Integer>
  # ジェネリック型もハイライトされます
end
```

### ユニオンとインターセクション型

```ruby
type StringOrInt = String | Integer    # '|'を使ったユニオン型
type ReadWrite = Readable & Writable   # '&'を使ったインターセクション型
type MaybeString = String | nil        # Nullable型
```

## エディター別設定

### VS Code

VS Code拡張機能は自動的にシンタックスハイライトを提供します。以下からインストール：
- VS Codeマーケットプレイス: "T-Ruby"を検索
- または`editors/vscode`ディレクトリから手動インストール

**テーマのカスタマイズ：**

`settings.json`に追加：

```json
{
  "editor.tokenColorCustomizations": {
    "[使用中のテーマ]": {
      "textMateRules": [
        {
          "scope": "keyword.declaration.type.t-ruby",
          "settings": {
            "foreground": "#C678DD"
          }
        },
        {
          "scope": "entity.name.type.t-ruby",
          "settings": {
            "foreground": "#E5C07B"
          }
        },
        {
          "scope": "support.type.builtin.t-ruby",
          "settings": {
            "foreground": "#56B6C2"
          }
        }
      ]
    }
  }
}
```

### Vim/Neovim

シンタックスファイルを設定にコピー：

```bash
# Vim
cp editors/vim/syntax/truby.vim ~/.vim/syntax/
cp editors/vim/ftdetect/truby.vim ~/.vim/ftdetect/

# Neovim
cp editors/vim/syntax/truby.vim ~/.config/nvim/syntax/
cp editors/vim/ftdetect/truby.vim ~/.config/nvim/ftdetect/
```

**カラーのカスタマイズ：**

`~/.vimrc`または`init.vim`に追加：

```vim
" カスタムT-Rubyハイライト色
augroup truby_colors
  autocmd!
  autocmd ColorScheme * highlight tRubyKeyword ctermfg=176 guifg=#C678DD
  autocmd ColorScheme * highlight tRubyTypeName ctermfg=180 guifg=#E5C07B
  autocmd ColorScheme * highlight tRubyBuiltinType ctermfg=73 guifg=#56B6C2
  autocmd ColorScheme * highlight tRubyInterface ctermfg=114 guifg=#98C379
augroup END
```

LuaでのNeovim：

```lua
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "tRubyKeyword", { fg = "#C678DD" })
    vim.api.nvim_set_hl(0, "tRubyTypeName", { fg = "#E5C07B" })
    vim.api.nvim_set_hl(0, "tRubyBuiltinType", { fg = "#56B6C2" })
  end,
})
```

## シンタックスグループ参照

### VS Code TextMateスコープ

| 要素 | スコープ |
|------|---------|
| `type`, `interface`キーワード | `keyword.declaration.type.t-ruby` |
| 型名 | `entity.name.type.t-ruby` |
| 組み込み型 | `support.type.builtin.t-ruby` |
| 関数名 | `entity.name.function.t-ruby` |
| パラメータ | `variable.parameter.t-ruby` |
| 型演算子（`\|`, `&`） | `keyword.operator.type.t-ruby` |
| ジェネリック括弧 | `punctuation.definition.generic.t-ruby` |

### Vimハイライトグループ

| 要素 | グループ |
|------|---------|
| キーワード | `tRubyKeyword` |
| 型名 | `tRubyTypeName` |
| 組み込み型 | `tRubyBuiltinType` |
| インターフェース | `tRubyInterface` |
| インターフェースメンバー | `tRubyInterfaceMember` |
| 型アノテーション | `tRubyTypeAnnotation` |
| 戻り値型 | `tRubyReturnType` |
| 型演算子 | `tRubyTypeOperator` |

## サンプルファイル

### シンプルな例

```ruby
# simple.trb - 基本的なT-Ruby構文

type UserId = String
type Score = Integer

def get_score(user_id: UserId): Score
  100
end
```

### 複雑な例

```ruby
# complex.trb - 高度なT-Ruby構文

type UserId = String
type Email = String
type Timestamp = Integer

interface Identifiable
  id: UserId
end

interface Timestamped
  created_at: Timestamp
  updated_at: Timestamp
end

interface User
  id: UserId
  name: String
  email: Email
  age: Integer | nil
  roles: Array<String>
  metadata: Hash<String, String>
end

type UserWithTimestamp = User & Timestamped

def create_user(name: String, email: Email): User
  # 実装
end

def find_user(id: UserId): User | nil
  # 実装
end

def get_users_by_role(role: String): Array<User>
  # 実装
end
```

## トラブルシューティング

### ハイライトが適用されない

1. **ファイル拡張子を確認**: `.trb`または`.d.trb`である必要があります
2. **ファイルタイプ検出を確認**：
   - VS Code: 右下のステータスバーを確認
   - Vim: `:set filetype?`を実行
3. **シンタックスファイルの読み込みを確認**：
   - Vim: `:echo exists("g:truby_syntax_loaded")`

### 間違った色

1. **カラースキームの互換性を確認**
2. **ハイライトグループのリンクを確認**：
   - Vim: `:highlight tRubyKeyword`
3. **カスタム色でオーバーライド**（上記参照）

### 部分的にのみハイライト

1. **複雑なネストされた型**はシンタックスの再読み込みが必要な場合があります：
   - Vim: `:syntax sync fromstart`
2. **パースを妨げるシンタックスエラーを確認**

## テーマとの統合

### One Darkテーマ

T-RubyシンタックスはOne Darkおよび類似のテーマでうまく動作するように設計されています：

| 要素 | One Dark色 |
|------|-----------|
| キーワード | `#C678DD`（紫） |
| 型 | `#E5C07B`（黄） |
| 組み込み型 | `#56B6C2`（シアン） |
| 関数 | `#61AFEF`（青） |
| 文字列 | `#98C379`（緑） |

### Draculaテーマ

| 要素 | Dracula色 |
|------|----------|
| キーワード | `#FF79C6`（ピンク） |
| 型 | `#8BE9FD`（シアン） |
| 関数 | `#50FA7B`（緑） |
| 文字列 | `#F1FA8C`（黄） |

## 次のステップ

- [VS Codeセットアップ](../../vscode/ja/getting-started.md)
- [Vimセットアップ](../../vim/ja/getting-started.md)
- [Neovimセットアップ](../../neovim/ja/getting-started.md)

## サポート

シンタックスハイライトの問題：
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- 報告時にはエディターのバージョンとテーマ名を含めてください
