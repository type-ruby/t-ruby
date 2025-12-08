# T-Ruby 구문 강조 가이드

이 가이드는 다양한 에디터에서 T-Ruby 구문 강조를 설정하고 커스터마이징하는 방법을 설명합니다.

## 개요

T-Ruby 구문 강조는 다음 요소들을 시각적으로 구분합니다:

- **키워드**: `type`, `interface`, `def`, `end`
- **타입**: `String`, `Integer`, `Boolean`, `Array`, `Hash` 등
- **타입 어노테이션**: 매개변수 및 반환 타입 선언
- **타입 연산자**: `|` (유니온), `&` (인터섹션), `<>` (제네릭)
- **주석**: `#` 한 줄 주석
- **문자열**: 작은따옴표 및 큰따옴표
- **숫자**: 정수 및 부동소수점
- **심볼**: `:symbol_name`

## 강조되는 요소들

### 타입 별칭

```ruby
type UserId = String           # 'type' 키워드, 'UserId' 타입명
type Age = Integer             # '=' 연산자, 내장 타입
type UserMap = Hash<UserId, User>  # 제네릭 타입
```

### 인터페이스

```ruby
interface Printable            # 'interface' 키워드, 인터페이스명
  to_string: String           # 멤버명, 타입 어노테이션
  print: void
end                           # 'end' 키워드
```

### 타입 어노테이션이 있는 함수

```ruby
def greet(name: String): String    # 함수명, 타입이 있는 매개변수, 반환 타입
  "안녕하세요, #{name}님!"
end

def process(items: Array<String>, count: Integer): Hash<String, Integer>
  # 제네릭 타입도 강조됨
end
```

### 유니온 및 인터섹션 타입

```ruby
type StringOrInt = String | Integer    # '|'를 사용한 유니온 타입
type ReadWrite = Readable & Writable   # '&'를 사용한 인터섹션 타입
type MaybeString = String | nil        # Nullable 타입
```

## 에디터별 설정

### VS Code

VS Code 확장은 자동으로 구문 강조를 제공합니다. 다음에서 설치:
- VS Code 마켓플레이스: "T-Ruby" 검색
- 또는 `editors/vscode` 디렉토리에서 수동 설치

**테마 커스터마이징:**

`settings.json`에 추가:

```json
{
  "editor.tokenColorCustomizations": {
    "[사용 중인 테마]": {
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

구문 파일을 설정에 복사:

```bash
# Vim
cp editors/vim/syntax/truby.vim ~/.vim/syntax/
cp editors/vim/ftdetect/truby.vim ~/.vim/ftdetect/

# Neovim
cp editors/vim/syntax/truby.vim ~/.config/nvim/syntax/
cp editors/vim/ftdetect/truby.vim ~/.config/nvim/ftdetect/
```

**색상 커스터마이징:**

`~/.vimrc` 또는 `init.vim`에 추가:

```vim
" 사용자 정의 T-Ruby 강조 색상
augroup truby_colors
  autocmd!
  autocmd ColorScheme * highlight tRubyKeyword ctermfg=176 guifg=#C678DD
  autocmd ColorScheme * highlight tRubyTypeName ctermfg=180 guifg=#E5C07B
  autocmd ColorScheme * highlight tRubyBuiltinType ctermfg=73 guifg=#56B6C2
  autocmd ColorScheme * highlight tRubyInterface ctermfg=114 guifg=#98C379
augroup END
```

Lua를 사용하는 Neovim:

```lua
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "tRubyKeyword", { fg = "#C678DD" })
    vim.api.nvim_set_hl(0, "tRubyTypeName", { fg = "#E5C07B" })
    vim.api.nvim_set_hl(0, "tRubyBuiltinType", { fg = "#56B6C2" })
  end,
})
```

## 구문 그룹 참조

### VS Code TextMate 스코프

| 요소 | 스코프 |
|------|--------|
| `type`, `interface` 키워드 | `keyword.declaration.type.t-ruby` |
| 타입명 | `entity.name.type.t-ruby` |
| 내장 타입 | `support.type.builtin.t-ruby` |
| 함수명 | `entity.name.function.t-ruby` |
| 매개변수 | `variable.parameter.t-ruby` |
| 타입 연산자 (`\|`, `&`) | `keyword.operator.type.t-ruby` |
| 제네릭 괄호 | `punctuation.definition.generic.t-ruby` |

### Vim 하이라이트 그룹

| 요소 | 그룹 |
|------|------|
| 키워드 | `tRubyKeyword` |
| 타입명 | `tRubyTypeName` |
| 내장 타입 | `tRubyBuiltinType` |
| 인터페이스 | `tRubyInterface` |
| 인터페이스 멤버 | `tRubyInterfaceMember` |
| 타입 어노테이션 | `tRubyTypeAnnotation` |
| 반환 타입 | `tRubyReturnType` |
| 타입 연산자 | `tRubyTypeOperator` |

## 예제 파일

### 간단한 예제

```ruby
# simple.trb - 기본 T-Ruby 구문

type UserId = String
type Score = Integer

def get_score(user_id: UserId): Score
  100
end
```

### 복잡한 예제

```ruby
# complex.trb - 고급 T-Ruby 구문

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
  # 구현
end

def find_user(id: UserId): User | nil
  # 구현
end

def get_users_by_role(role: String): Array<User>
  # 구현
end
```

## 문제 해결

### 강조가 적용되지 않음

1. **파일 확장자 확인**: `.trb` 또는 `.d.trb`여야 함
2. **파일타입 감지 확인**:
   - VS Code: 우측 하단 상태바 확인
   - Vim: `:set filetype?` 실행
3. **구문 파일 로드 확인**:
   - Vim: `:echo exists("g:truby_syntax_loaded")`

### 잘못된 색상

1. **컬러 스킴 호환성 확인**
2. **하이라이트 그룹 링크 확인**:
   - Vim: `:highlight tRubyKeyword`
3. **사용자 정의 색상으로 오버라이드** (위 참조)

### 부분적으로만 강조됨

1. **복잡한 중첩 타입**은 구문 재로드가 필요할 수 있음:
   - Vim: `:syntax sync fromstart`
2. **파싱을 방해하는 구문 오류 확인**

## 테마와의 통합

### One Dark 테마

T-Ruby 구문은 One Dark 및 유사한 테마와 잘 작동하도록 설계되었습니다:

| 요소 | One Dark 색상 |
|------|--------------|
| 키워드 | `#C678DD` (보라) |
| 타입 | `#E5C07B` (노랑) |
| 내장 타입 | `#56B6C2` (청록) |
| 함수 | `#61AFEF` (파랑) |
| 문자열 | `#98C379` (초록) |

### Dracula 테마

| 요소 | Dracula 색상 |
|------|-------------|
| 키워드 | `#FF79C6` (분홍) |
| 타입 | `#8BE9FD` (청록) |
| 함수 | `#50FA7B` (초록) |
| 문자열 | `#F1FA8C` (노랑) |

## 다음 단계

- [VS Code 설정](../../vscode/ko/getting-started.md)
- [Vim 설정](../../vim/ko/getting-started.md)
- [Neovim 설정](../../neovim/ko/getting-started.md)

## 지원

구문 강조 문제:
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- 보고 시 에디터 버전과 테마 이름을 포함해 주세요
