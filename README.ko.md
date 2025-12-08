# t-ruby (한국어 문서)

> TypeScript 에 영감을 받은 Ruby용 정적 타입 레이어.
> `.trb` 파일을 작성하고, `trc` 로 `.rb` 와 `.rbs` 를 생성합니다.

`t-ruby` 는 Ruby 위에서 동작하는 **선택적(gradual) 정적 타입 시스템**입니다.

* 소스 파일: `.trb`
* 컴파일러: `trc`
* 설정 파일: `.trb.yml`
* 출력 대상:

  * Ruby 실행 코드: `.rb`
  * Ruby 공식 시그니처 파일: `.rbs` (옵션)
  * t-ruby 전용 선언 파일: `.d.trb` (옵션, RBS보다 표현력 높음)

목표는 Ruby 개발자에게 **TypeScript 와 유사한 개발 경험(DX)** 을 주되,
기존 Ruby/RBS 생태계와 충돌하지 않고 자연스럽게 공존하는 것입니다.

---

## 상태 (Status)

**모든 마일스톤 완료.** 260개 테스트 통과.

### ✅ Milestone 1 – 기초 타입 파싱 & 제거
* 파라미터/리턴 타입 애너테이션, 타입 제거, 에러 처리

### ✅ Milestone 2 – 코어 타입 시스템
* 타입 별칭, 인터페이스, 유니온/인터섹션 타입, 제네릭, RBS 생성

### ✅ Milestone 3 – 생태계 & 툴링
* LSP 서버, `.d.trb` 선언 파일, IDE 통합 (VS Code, Vim, Neovim), 표준 라이브러리 타입

### ✅ Milestone 4 – 고급 기능
* 제약 시스템, 타입 추론, 런타임 검증, 정적 타입 검사, 캐싱, 패키지 관리

---

## 개념 (Concept)

### 1) `.trb` 파일 작성

```ruby
# hello.trb

def greet(name: String): void
  puts "Hello, #{name} from t-ruby!"
end

greet("world")
```

### 2) `trc` 로 컴파일

```bash
trc hello.trb
# => build/hello.rb (필요 시 .rbs / .d.trb 도 생성)
```

### 3) Ruby 로 실행

```bash
ruby build/hello.rb
```

---

## 설계 목표 (Design Goals)

### 1. Ruby 개발자를 위한 TypeScript 수준의 DX

* 선택적 타입 도입 (gradual typing)
* `type`, `interface`, 제네릭, 유니온/인터섹션 타입 지원 예정
* 단일 컴파일러 CLI: `trc`

### 2. 기존 Ruby 생태계와의 자연스러운 상호운용성

* Ruby 인터프리터에서 바로 실행 가능한 `.rb` 출력
* Steep, Ruby LSP 등이 읽을 수 있는 `.rbs` 출력
* t-ruby 만의 확장 타입을 담는 `.d.trb` 선언 파일 옵션 제공

### 3. RBS 를 ‘기반’으로 존중하되, RBS 에 묶이지 않음

* t-ruby 의 타입 시스템은 RBS 의 **상위호환(superset)** 을 목표로 함
* `.rbs` 로 투영하기 어려운 타입은 보수적으로 단순화하여 출력
* 기존 RBS 타입 자산을 그대로 재사용 가능

### 4. Ruby 문화에 어울리는 설정 스타일

* 프로젝트 루트에 `.trb.yml` 사용
* Ruby 생태계의 YAML 기반 설정 관례와 일관성 유지

---

## `.trb.yml` 예시

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

## 로드맵 (Roadmap)

자세한 내용은 [ROADMAP.md](./ROADMAP.md) 참조.

| 마일스톤 | 상태 |
|----------|------|
| 0 – Hello t-ruby | ✅ |
| 1 – 타입 파싱 & 제거 | ✅ |
| 2 – 코어 타입 시스템 | ✅ |
| 3 – 생태계 & 툴링 | ✅ |
| 4 – 고급 기능 | ✅ |

---

## IDE 및 에디터 통합

t-ruby는 구문 강조, LSP 통합, 개발 도구를 통해 인기 에디터들을 최우선으로 지원합니다.

### 지원 에디터

| 에디터 | 구문 강조 | LSP 지원 | 문서 |
|--------|:--------:|:--------:|------|
| **VS Code** | ✅ | ✅ | [시작하기](./docs/vscode/ko/getting-started.md) |
| **Vim** | ✅ | ❌ | [시작하기](./docs/vim/ko/getting-started.md) |
| **Neovim** | ✅ | ✅ | [시작하기](./docs/neovim/ko/getting-started.md) |

### 빠른 설치

**VS Code:**
```bash
# VS Code 마켓플레이스에서
ext install t-ruby

# 또는 소스에서
cd editors/vscode && npm install && npm run compile
code --install-extension .
```

**Vim:**
```vim
" vim-plug 사용
Plug 'type-ruby/t-ruby', { 'rtp': 'editors/vim' }
```

**Neovim:**
```lua
-- lazy.nvim 사용
{ "type-ruby/t-ruby", ft = { "truby" }, config = function()
    require("t-ruby-lsp").setup()
end }
```

### 언어별 문서

| | English | 한국어 | 日本語 |
|---|---------|--------|--------|
| **VS Code** | [Guide](./docs/vscode/en/getting-started.md) | [가이드](./docs/vscode/ko/getting-started.md) | [ガイド](./docs/vscode/ja/getting-started.md) |
| **Vim** | [Guide](./docs/vim/en/getting-started.md) | [가이드](./docs/vim/ko/getting-started.md) | [ガイド](./docs/vim/ja/getting-started.md) |
| **Neovim** | [Guide](./docs/neovim/en/getting-started.md) | [가이드](./docs/neovim/ko/getting-started.md) | [ガイド](./docs/neovim/ja/getting-started.md) |
| **구문 강조** | [Guide](./docs/syntax-highlighting/en/guide.md) | [가이드](./docs/syntax-highlighting/ko/guide.md) | [ガイド](./docs/syntax-highlighting/ja/guide.md) |

---

## 철학 (Philosophy)

t-ruby 는 Ruby 를 대체하려는 언어가 아닙니다.

* Ruby 는 런타임이며 호스트 언어로 남습니다.
* t-ruby 는 그 위에 얹혀 동작하는 **선택적 타입 레이어**입니다.
* 기존 Ruby 프로젝트에 점진적으로 도입할 수 있어야 합니다.

t-ruby 는 RBS 와 경쟁하지 않습니다.

* RBS 는 Ruby 의 공식 시그니처 포맷으로 존중합니다.
* t-ruby 는 RBS 를 **확장하고 재사용**하려 합니다.
* 고급 타입은 `.rbs` 로 투영 시 단순화하거나 별도의 `.d.trb` 로 제공합니다.

---

## 다국어 문서

* English: [README.md](./README.md)
* 日本語: [README.ja.md](./README.ja.md)

---

## 라이선스

미정 (TBD).
