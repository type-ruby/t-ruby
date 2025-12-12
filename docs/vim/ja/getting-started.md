# T-Ruby for Vim - はじめに

Vim用T-Rubyへようこそ！このガイドでは、VimでT-Rubyのシンタックスハイライトと統合を設定する方法を説明します。

## 前提条件

プラグインをインストールする前に、以下が必要です：

- **Vim** 8.0以上（`+syntax`機能を含む）
- **Ruby** 3.0以上（コンパイル用、オプション）
- **T-Rubyコンパイラ** (`trc`) コンパイル機能用

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

## インストール方法

### 方法1: vim-plugを使用（推奨）

`~/.vimrc`に追加：

```vim
call plug#begin('~/.vim/plugged')

Plug 'type-ruby/t-ruby', { 'rtp': 'editors/vim' }

call plug#end()
```

次に実行：
```vim
:PlugInstall
```

### 方法2: Vundleを使用

`~/.vimrc`に追加：

```vim
Plugin 'type-ruby/t-ruby', { 'rtp': 'editors/vim' }
```

次に実行：
```vim
:PluginInstall
```

### 方法3: Pathogenを使用

```bash
cd ~/.vim/bundle
git clone https://github.com/type-ruby/t-ruby.git
```

### 方法4: 手動インストール

```bash
# リポジトリをクローン
git clone https://github.com/type-ruby/t-ruby.git

# プラグインファイルをVimディレクトリにコピー
cp -r t-ruby/editors/vim/* ~/.vim/
```

または特定のディレクトリのみ：
```bash
cp t-ruby/editors/vim/syntax/truby.vim ~/.vim/syntax/
cp t-ruby/editors/vim/ftdetect/truby.vim ~/.vim/ftdetect/
cp t-ruby/editors/vim/ftplugin/truby.vim ~/.vim/ftplugin/
```

## インストール確認

インストール後、プラグインが動作しているか確認：

1. `.trb`拡張子のファイルを作成
2. Vimで開く
3. `:set filetype?`を実行 - `filetype=truby`と表示されるはず

## 機能

### シンタックスハイライト

プラグインは以下のシンタックスハイライトを提供します：
- 型エイリアス（`type Name = Type`）
- インターフェース定義（`interface Name ... end`）
- 型アノテーション付き関数定義
- ユニオン型（`String | Integer`）
- ジェネリック型（`Array<String>`）
- インターセクション型（`Readable & Writable`）

### ファイルタイプ検出

自動検出：
- `.trb`ファイル - T-Rubyソースファイル
- `.d.trb`ファイル - T-Ruby宣言ファイル

### キーマッピング

デフォルトのキーマッピング（ノーマルモード）：

| キー | アクション |
|------|----------|
| `<leader>tc` | 現在のファイルをコンパイル |
| `<leader>td` | 宣言ファイルを生成 |

### インデント

Ruby互換のインデント：
- インデントレベルごとに2スペース
- `def`、`interface`、`class`などの後に自動インデント
- `end`で自動デデント

### コード折りたたみ

コード折りたたみのサポート：
- インデントレベルで折りたたみ
- `za`で折りたたみをトグル
- `zR`で全ての折りたたみを開く
- `zM`で全ての折りたたみを閉じる

## 設定

カスタマイズのために`~/.vimrc`に追加：

```vim
" カスタムリーダーキーを設定（デフォルトは\）
let mapleader = ","

" カスタムT-Ruby設定
augroup truby_settings
  autocmd!
  " 2スペースの代わりに4スペースを使用
  autocmd FileType truby setlocal shiftwidth=4 softtabstop=4

  " コメントでスペルチェックを有効化
  autocmd FileType truby setlocal spell

  " カスタムコンパイラを設定
  autocmd FileType truby setlocal makeprg=/path/to/trc\ %
augroup END

" カスタムキーマッピング
autocmd FileType truby nnoremap <buffer> <F5> :!trc %<CR>
autocmd FileType truby nnoremap <buffer> <F6> :!trc --decl %<CR>
```

## クイックスタート例

1. ファイル`hello.trb`を作成：

```bash
vim hello.trb
```

2. 以下のコードを入力：

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

3. 以下を確認できます：
   - `type`、`interface`、`def`、`end`がキーワードとしてハイライト
   - 型名（`UserId`、`User`、`String`、`Integer`）が型としてハイライト
   - Enterを押した時に適切なインデント

4. `<leader>tc`または`:!trc %`でコンパイル

## トラブルシューティング

### シンタックスハイライトが機能しない

1. ファイルタイプを確認：`:set filetype?`
2. 手動でファイルタイプを設定：`:set filetype=truby`
3. シンタックスファイルの存在を確認：`:echo globpath(&rtp, 'syntax/truby.vim')`

### 間違ったファイルタイプが検出される

`~/.vimrc`に追加：
```vim
autocmd BufRead,BufNewFile *.trb set filetype=truby
autocmd BufRead,BufNewFile *.d.trb set filetype=truby
```

### キーマッピングが動作しない

1. リーダーキーを確認：`:echo mapleader`
2. マッピングを確認：`:map <leader>tc`
3. 競合を確認：`:verbose map <leader>tc`

### コンパイルエラー

1. `trc`がPATHにあるか確認：`:!which trc`
2. makeprg設定を確認：`:set makeprg?`
3. 手動でテスト：`:!trc --version`

## 他のプラグインとの統合

### ALE（Asynchronous Lint Engine）と一緒に

```vim
" T-Rubyリンターを追加
let g:ale_linters = {
\   'truby': ['trc'],
\}
```

### vim-polyglotと一緒に

T-RubyプラグインはVim-polyglotと互換性があります。両方がインストールされている場合、`.trb`ファイルに対してT-Ruby設定が優先されます。

## 次のステップ

- [シンタックスハイライトガイド](../../syntax-highlighting/ja/guide.md)
- [Neovimセットアップ](../../neovim/ja/getting-started.md)（LSPサポート用）
- [T-Ruby言語リファレンス](https://github.com/type-ruby/t-ruby/wiki)

## サポート

質問やバグ報告：
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- Discussions: https://github.com/type-ruby/t-ruby/discussions
