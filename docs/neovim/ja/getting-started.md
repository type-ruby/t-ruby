# T-Ruby for Neovim - はじめに

Neovim用T-Rubyへようこそ！このガイドでは、Neovimでの完全なLSPサポート、シンタックスハイライト、高度な機能を設定する方法を説明します。

## 前提条件

インストール前に、以下が必要です：

- **Neovim** 0.8.0以上（最高のLSPサポートには0.9+推奨）
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

### 方法1: lazy.nvimを使用（推奨）

`~/.config/nvim/lua/plugins/t-ruby.lua`に追加：

```lua
return {
  "type-ruby/t-ruby",
  ft = { "truby" },
  config = function()
    require("t-ruby-lsp").setup()
    require("t-ruby-lsp").create_commands()
  end,
}
```

### 方法2: packer.nvimを使用

`~/.config/nvim/lua/plugins.lua`に追加：

```lua
use {
  'type-ruby/t-ruby',
  ft = { 'truby' },
  config = function()
    require('t-ruby-lsp').setup()
    require('t-ruby-lsp').create_commands()
  end
}
```

### 方法3: 手動インストール

```bash
# リポジトリをクローン
git clone https://github.com/type-ruby/t-ruby.git

# Vimプラグインファイルをコピー
cp -r t-ruby/editors/vim/* ~/.config/nvim/

# Neovim Lua設定をコピー
mkdir -p ~/.config/nvim/lua
cp t-ruby/editors/nvim/lua/t-ruby-lsp.lua ~/.config/nvim/lua/
```

次に`init.lua`に追加：

```lua
require('t-ruby-lsp').setup()
require('t-ruby-lsp').create_commands()
```

## LSP設定

### nvim-lspconfigを使用（推奨）

`nvim-lspconfig`を使用している場合、T-Ruby LSPはシームレスに統合されます：

```lua
-- LSP設定ファイルで
require('t-ruby-lsp').setup({
  cmd = { "trc", "--lsp" },
  filetypes = { "truby" },
  settings = {},
})
```

### 手動LSPセットアップ（nvim-lspconfigなし）

追加プラグインなしの最小セットアップ：

```lua
require('t-ruby-lsp').setup_manual()
```

### coc.nvimを使用

coc.nvimを好む場合は、`:CocConfig`に追加：

```json
{
  "languageserver": {
    "t-ruby": {
      "command": "trc",
      "args": ["--lsp"],
      "filetypes": ["truby"],
      "rootPatterns": ["trbconfig.yml", ".git/"]
    }
  }
}
```

## 機能

### LSP機能

LSPが有効な場合、以下が利用できます：

- **自動補完**: インテリジェントな型の提案
- **ホバー**: 型情報の表示（デフォルトで`K`）
- **定義へ移動**: 型/関数の定義へジャンプ（`gd`）
- **診断**: リアルタイムエラーチェック
- **ドキュメントシンボル**: ファイル内のシンボルをナビゲート

### シンタックスハイライト

完全なハイライトサポート：
- 型エイリアスとインターフェース
- 型アノテーション付き関数定義
- ユニオン、インターセクション、ジェネリック型
- T-Rubyキーワードと組み込み型

### ユーザーコマンド

`create_commands()`呼び出し後：

| コマンド | 説明 |
|----------|------|
| `:TRubyCompile` | 現在のファイルをコンパイル |
| `:TRubyDecl` | 宣言ファイルを生成 |
| `:TRubyLspInfo` | LSPステータスを確認 |

## 設定オプション

```lua
require('t-ruby-lsp').setup({
  -- T-Rubyコンパイラのパス
  cmd = { "trc", "--lsp" },

  -- 有効化するファイルタイプ
  filetypes = { "truby", "trb" },

  -- ルートディレクトリの検出
  root_dir = function(fname)
    return vim.fn.getcwd()
  end,

  -- LSP設定
  settings = {},
})
```

## キーマッピング

T-Ruby用の推奨キーマッピング（設定に追加）：

```lua
-- T-Ruby専用マッピング
vim.api.nvim_create_autocmd("FileType", {
  pattern = "truby",
  callback = function()
    local opts = { buffer = true, silent = true }

    -- 現在のファイルをコンパイル
    vim.keymap.set("n", "<leader>tc", ":TRubyCompile<CR>", opts)

    -- 宣言を生成
    vim.keymap.set("n", "<leader>td", ":TRubyDecl<CR>", opts)

    -- LSPマッピング（ネイティブLSP使用時）
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
  end,
})
```

## クイックスタート例

1. `hello.trb`を作成：

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

2. Neovimで開く：
```bash
nvim hello.trb
```

3. 以下の機能を試す：
   - `User`の上で`K`を押して型情報を確認
   - `UserId`で`gd`を押して定義へ移動
   - パラメータ名の後に`:`を入力して自動補完
   - ファイルを保存して診断を確認

4. コンパイル：
```vim
:TRubyCompile
```

## 人気プラグインとの統合

### nvim-cmp（補完）

LSP補完はnvim-cmpと自動的に統合されます：

```lua
-- nvim-cmp設定で
sources = cmp.config.sources({
  { name = 'nvim_lsp' },
  -- T-Ruby補完はLSPを通じて表示されます
})
```

### telescope.nvim

```lua
-- T-Rubyファイルを検索
vim.keymap.set("n", "<leader>ft", function()
  require("telescope.builtin").find_files({
    find_command = { "fd", "-e", "trb" }
  })
end)
```

### trouble.nvim

診断はtrouble.nvimと自動的に統合されます：

```vim
:Trouble diagnostics
```

## トラブルシューティング

### LSPが起動しない

1. `trc`が利用可能か確認：
```vim
:!trc --version
```

2. LSPステータスを確認：
```vim
:TRubyLspInfo
```

3. LSPログを表示：
```vim
:lua vim.cmd('e ' .. vim.lsp.get_log_path())
```

### シンタックスハイライトが機能しない

1. ファイルタイプを確認：
```vim
:set filetype?
```

2. 必要に応じて手動設定：
```vim
:set filetype=truby
```

3. シンタックスファイルがロードされているか確認：
```vim
:echo globpath(&rtp, 'syntax/truby.vim')
```

### 自動補完が動作しない

1. LSPが接続されているか確認：
```vim
:lua print(vim.inspect(vim.lsp.get_active_clients()))
```

2. エラーを確認：
```vim
:lua print(vim.inspect(vim.diagnostic.get()))
```

## 次のステップ

- [シンタックスハイライトガイド](../../syntax-highlighting/ja/guide.md)
- [Vimセットアップ](../../vim/ja/getting-started.md)（LSPなしの基本Vim）
- [T-Ruby言語リファレンス](https://github.com/type-ruby/t-ruby/wiki)

## サポート

質問やバグ報告：
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- Discussions: https://github.com/type-ruby/t-ruby/discussions
