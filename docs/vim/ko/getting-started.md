# T-Ruby for Vim - 시작하기

Vim을 위한 T-Ruby에 오신 것을 환영합니다! 이 가이드는 Vim에서 T-Ruby 구문 강조 및 통합을 설정하는 방법을 안내합니다.

## 사전 요구 사항

플러그인을 설치하기 전에 다음이 필요합니다:

- **Vim** 8.0 이상 (`+syntax` 기능 포함)
- **Ruby** 3.0 이상 (컴파일을 위해 선택 사항)
- **T-Ruby 컴파일러** (`trc`) 컴파일 기능을 위해 필요

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

## 설치 방법

### 방법 1: vim-plug 사용 (권장)

`~/.vimrc`에 추가:

```vim
call plug#begin('~/.vim/plugged')

Plug 'type-ruby/t-ruby', { 'rtp': 'editors/vim' }

call plug#end()
```

그 다음 실행:
```vim
:PlugInstall
```

### 방법 2: Vundle 사용

`~/.vimrc`에 추가:

```vim
Plugin 'type-ruby/t-ruby', { 'rtp': 'editors/vim' }
```

그 다음 실행:
```vim
:PluginInstall
```

### 방법 3: Pathogen 사용

```bash
cd ~/.vim/bundle
git clone https://github.com/type-ruby/t-ruby.git
```

### 방법 4: 수동 설치

```bash
# 저장소 클론
git clone https://github.com/type-ruby/t-ruby.git

# 플러그인 파일을 Vim 디렉토리로 복사
cp -r t-ruby/editors/vim/* ~/.vim/
```

또는 특정 디렉토리만:
```bash
cp t-ruby/editors/vim/syntax/truby.vim ~/.vim/syntax/
cp t-ruby/editors/vim/ftdetect/truby.vim ~/.vim/ftdetect/
cp t-ruby/editors/vim/ftplugin/truby.vim ~/.vim/ftplugin/
```

## 설치 확인

설치 후 플러그인이 작동하는지 확인:

1. `.trb` 확장자로 파일 생성
2. Vim에서 열기
3. `:set filetype?` 실행 - `filetype=truby`가 표시되어야 함

## 기능

### 구문 강조

플러그인은 다음에 대한 구문 강조를 제공합니다:
- 타입 별칭 (`type Name = Type`)
- 인터페이스 정의 (`interface Name ... end`)
- 타입 어노테이션이 있는 함수 정의
- 유니온 타입 (`String | Integer`)
- 제네릭 타입 (`Array<String>`)
- 인터섹션 타입 (`Readable & Writable`)

### 파일 타입 감지

자동 감지:
- `.trb` 파일 - T-Ruby 소스 파일
- `.d.trb` 파일 - T-Ruby 선언 파일

### 키 매핑

기본 키 매핑 (일반 모드):

| 키 | 동작 |
|----|------|
| `<leader>tc` | 현재 파일 컴파일 |
| `<leader>td` | 선언 파일 생성 |

### 들여쓰기

Ruby 호환 들여쓰기:
- 들여쓰기 레벨당 2칸
- `def`, `interface`, `class` 등 뒤에 자동 들여쓰기
- `end`에서 자동 내어쓰기

### 코드 접기

코드 접기 지원:
- 들여쓰기 레벨로 접기
- `za`로 접기 토글
- `zR`로 모든 접기 열기
- `zM`으로 모든 접기 닫기

## 설정

커스터마이징을 위해 `~/.vimrc`에 추가:

```vim
" 사용자 정의 리더 키 설정 (기본값은 \)
let mapleader = ","

" 사용자 정의 T-Ruby 설정
augroup truby_settings
  autocmd!
  " 2칸 대신 4칸 사용
  autocmd FileType truby setlocal shiftwidth=4 softtabstop=4

  " 주석에서 맞춤법 검사 활성화
  autocmd FileType truby setlocal spell

  " 사용자 정의 컴파일러 설정
  autocmd FileType truby setlocal makeprg=/path/to/trc\ %
augroup END

" 사용자 정의 키 매핑
autocmd FileType truby nnoremap <buffer> <F5> :!trc %<CR>
autocmd FileType truby nnoremap <buffer> <F6> :!trc --decl %<CR>
```

## 빠른 시작 예제

1. 파일 `hello.trb` 생성:

```bash
vim hello.trb
```

2. 다음 코드 입력:

```trb
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

3. 다음을 확인할 수 있습니다:
   - `type`, `interface`, `def`, `end`가 키워드로 강조됨
   - 타입 이름 (`UserId`, `User`, `String`, `Integer`)이 타입으로 강조됨
   - Enter 누를 때 적절한 들여쓰기

4. `<leader>tc` 또는 `:!trc %`로 컴파일

## 문제 해결

### 구문 강조가 안 됨

1. 파일타입 확인: `:set filetype?`
2. 수동으로 파일타입 설정: `:set filetype=truby`
3. 구문 파일 존재 확인: `:echo globpath(&rtp, 'syntax/truby.vim')`

### 잘못된 파일 타입 감지

`~/.vimrc`에 추가:
```vim
autocmd BufRead,BufNewFile *.trb set filetype=truby
autocmd BufRead,BufNewFile *.d.trb set filetype=truby
```

### 키 매핑이 작동 안 함

1. 리더 키 확인: `:echo mapleader`
2. 매핑 확인: `:map <leader>tc`
3. 충돌 확인: `:verbose map <leader>tc`

### 컴파일 오류

1. `trc`가 PATH에 있는지 확인: `:!which trc`
2. makeprg 설정 확인: `:set makeprg?`
3. 수동으로 테스트: `:!trc --version`

## 다른 플러그인과 통합

### ALE (Asynchronous Lint Engine)와 함께

```vim
" T-Ruby 린터 추가
let g:ale_linters = {
\   'truby': ['trc'],
\}
```

### vim-polyglot과 함께

T-Ruby 플러그인은 vim-polyglot과 호환됩니다. 둘 다 설치된 경우 `.trb` 파일에 대해 T-Ruby 설정이 우선합니다.

## 다음 단계

- [구문 강조 가이드](../../syntax-highlighting/ko/guide.md)
- [Neovim 설정](../../neovim/ko/getting-started.md) (LSP 지원을 위해)
- [T-Ruby 언어 레퍼런스](https://github.com/type-ruby/t-ruby/wiki)

## 지원

질문이나 버그 보고:
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- Discussions: https://github.com/type-ruby/t-ruby/discussions
