# T-Ruby for Neovim - 시작하기

Neovim을 위한 T-Ruby에 오신 것을 환영합니다! 이 가이드는 Neovim에서 T-Ruby의 전체 LSP 지원, 구문 강조, 고급 기능을 설정하는 방법을 안내합니다.

## 사전 요구 사항

설치 전에 다음이 필요합니다:

- **Neovim** 0.8.0 이상 (최상의 LSP 지원을 위해 0.9+ 권장)
- **Ruby** 3.0 이상
- **T-Ruby 컴파일러** (`trc`)가 설치되어 PATH에 등록되어 있어야 함

### T-Ruby 컴파일러 설치

```bash
# gem으로 설치 (권장)
gem install t-ruby

# 또는 소스에서 빌드
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby
bundle install
rake install
```

설치 확인:
```bash
trc --version
```

## 설치 방법

### 방법 1: lazy.nvim 사용 (권장)

`~/.config/nvim/lua/plugins/t-ruby.lua`에 추가:

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

### 방법 2: packer.nvim 사용

`~/.config/nvim/lua/plugins.lua`에 추가:

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

### 방법 3: 수동 설치

```bash
# 저장소 클론
git clone https://github.com/type-ruby/t-ruby.git

# Vim 플러그인 파일 복사
cp -r t-ruby/editors/vim/* ~/.config/nvim/

# Neovim Lua 설정 복사
mkdir -p ~/.config/nvim/lua
cp t-ruby/editors/nvim/lua/t-ruby-lsp.lua ~/.config/nvim/lua/
```

그 다음 `init.lua`에 추가:

```lua
require('t-ruby-lsp').setup()
require('t-ruby-lsp').create_commands()
```

## LSP 설정

### nvim-lspconfig 사용 (권장)

`nvim-lspconfig`를 사용한다면, T-Ruby LSP가 원활하게 통합됩니다:

```lua
-- LSP 설정 파일에서
require('t-ruby-lsp').setup({
  cmd = { "trc", "--lsp" },
  filetypes = { "truby" },
  settings = {},
})
```

### 수동 LSP 설정 (nvim-lspconfig 없이)

추가 플러그인 없이 최소 설정:

```lua
require('t-ruby-lsp').setup_manual()
```

### coc.nvim 사용

coc.nvim을 선호한다면 `:CocConfig`에 추가:

```json
{
  "languageserver": {
    "t-ruby": {
      "command": "trc",
      "args": ["--lsp"],
      "filetypes": ["truby"],
      "rootPatterns": [".trb.yml", ".git/"]
    }
  }
}
```

## 기능

### LSP 기능

LSP가 활성화되면 다음을 사용할 수 있습니다:

- **자동완성**: 지능적인 타입 제안
- **호버**: 타입 정보 보기 (기본적으로 `K`)
- **정의로 이동**: 타입/함수 정의로 점프 (`gd`)
- **진단**: 실시간 오류 검사
- **문서 심볼**: 파일 내 심볼 탐색

### 구문 강조

완전한 강조 지원:
- 타입 별칭과 인터페이스
- 타입 어노테이션이 있는 함수 정의
- 유니온, 인터섹션, 제네릭 타입
- T-Ruby 키워드와 내장 타입

### 사용자 명령어

`create_commands()` 호출 후:

| 명령어 | 설명 |
|--------|------|
| `:TRubyCompile` | 현재 파일 컴파일 |
| `:TRubyDecl` | 선언 파일 생성 |
| `:TRubyLspInfo` | LSP 상태 확인 |

## 설정 옵션

```lua
require('t-ruby-lsp').setup({
  -- T-Ruby 컴파일러 경로
  cmd = { "trc", "--lsp" },

  -- 활성화할 파일 타입
  filetypes = { "truby", "trb" },

  -- 루트 디렉토리 감지
  root_dir = function(fname)
    return vim.fn.getcwd()
  end,

  -- LSP 설정
  settings = {},
})
```

## 키 매핑

T-Ruby를 위한 권장 키 매핑 (설정에 추가):

```lua
-- T-Ruby 전용 매핑
vim.api.nvim_create_autocmd("FileType", {
  pattern = "truby",
  callback = function()
    local opts = { buffer = true, silent = true }

    -- 현재 파일 컴파일
    vim.keymap.set("n", "<leader>tc", ":TRubyCompile<CR>", opts)

    -- 선언 생성
    vim.keymap.set("n", "<leader>td", ":TRubyDecl<CR>", opts)

    -- LSP 매핑 (네이티브 LSP 사용 시)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
  end,
})
```

## 빠른 시작 예제

1. `hello.trb` 생성:

```ruby
type UserId = String

interface User
  id: UserId
  name: String
  age: Integer
end

def greet(user: User): String
  "안녕하세요, #{user.name}님!"
end
```

2. Neovim에서 열기:
```bash
nvim hello.trb
```

3. 다음 기능 시도:
   - `User` 위에서 `K`를 눌러 타입 정보 확인
   - `UserId`에서 `gd`를 눌러 정의로 이동
   - 매개변수 이름 뒤에 `:`를 입력하여 자동완성
   - 파일 저장하여 진단 확인

4. 컴파일:
```vim
:TRubyCompile
```

## 인기 플러그인과 통합

### nvim-cmp (자동완성)

LSP 완성이 nvim-cmp와 자동으로 통합됩니다:

```lua
-- nvim-cmp 설정에서
sources = cmp.config.sources({
  { name = 'nvim_lsp' },
  -- T-Ruby 완성은 LSP를 통해 표시됩니다
})
```

### telescope.nvim

```lua
-- T-Ruby 파일 찾기
vim.keymap.set("n", "<leader>ft", function()
  require("telescope.builtin").find_files({
    find_command = { "fd", "-e", "trb" }
  })
end)
```

### trouble.nvim

진단이 trouble.nvim과 자동으로 통합됩니다:

```vim
:Trouble diagnostics
```

## 문제 해결

### LSP가 시작되지 않음

1. `trc`가 사용 가능한지 확인:
```vim
:!trc --version
```

2. LSP 상태 확인:
```vim
:TRubyLspInfo
```

3. LSP 로그 보기:
```vim
:lua vim.cmd('e ' .. vim.lsp.get_log_path())
```

### 구문 강조가 안 됨

1. 파일타입 확인:
```vim
:set filetype?
```

2. 필요 시 수동 설정:
```vim
:set filetype=truby
```

3. 구문 파일이 로드되었는지 확인:
```vim
:echo globpath(&rtp, 'syntax/truby.vim')
```

### 자동완성이 작동 안 함

1. LSP가 연결되었는지 확인:
```vim
:lua print(vim.inspect(vim.lsp.get_active_clients()))
```

2. 오류 확인:
```vim
:lua print(vim.inspect(vim.diagnostic.get()))
```

## 다음 단계

- [구문 강조 가이드](../../syntax-highlighting/ko/guide.md)
- [Vim 설정](../../vim/ko/getting-started.md) (LSP 없는 기본 Vim)
- [T-Ruby 언어 레퍼런스](https://github.com/type-ruby/t-ruby/wiki)

## 지원

질문이나 버그 보고:
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- Discussions: https://github.com/type-ruby/t-ruby/discussions
