<p align="center">
  <img src="https://avatars.githubusercontent.com/u/248530250" alt="T-Ruby" height="170">
</p>

<h1 align="center">T-Ruby</h1>

<p align="center">
  <strong>Ruby를 위한 TypeScript 스타일 타입</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/CI-passing-brightgreen" alt="CI: passing" />
  <img src="https://img.shields.io/badge/ruby-3.0+-cc342d" alt="Ruby 3.0+" />
  <a href="https://rubygems.org/gems/t-ruby"><img src="https://img.shields.io/gem/v/t-ruby" alt="Gem Version" /></a>
  <img src="https://img.shields.io/gem/dt/t-ruby" alt="Downloads" />
  <img src="https://img.shields.io/badge/coverage-90%25-brightgreen" alt="Coverage: 90%" />
</p>

<p align="center">
  <a href="#설치">설치</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="#빠른-시작">빠른 시작</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="#기능">기능</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./ROADMAP.md">로드맵</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./README.md">English</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="./README.ja.md">日本語</a>
</p>

> [!NOTE]
> 이 프로젝트는 아직 실험적인 프로젝트입니다. 이 프로젝트를 지지한다면 스타를 눌러주세요! 개선 의견이 있다면 이슈로 알려주시고, PR도 환영합니다!

---

## T-Ruby란?

T-Ruby는 TypeScript에서 영감을 받은 Ruby용 타입 레이어입니다.
`trc`라는 단일 실행 파일로 제공됩니다.

타입 어노테이션이 포함된 `.trb` 파일을 작성하고, 표준 `.rb` 파일로 컴파일하세요.
타입은 컴파일 시점에 제거됩니다 — Ruby가 실행되는 어디서든 코드가 동작합니다.

```bash
trc hello.trb                  # Ruby로 컴파일
```

`trc` 컴파일러는 Steep, Ruby LSP 같은 도구를 위한 `.rbs` 시그니처 파일도 생성합니다.
런타임 오버헤드 없이 기존 Ruby 프로젝트에 점진적으로 타입을 도입하세요.

```bash
trc --watch src/               # 워치 모드
trc --emit-rbs src/            # .rbs 파일 생성
trc --check src/               # 컴파일 없이 타입 검사만
```

---

## 왜 T-Ruby인가?

우리는 루비의 친구이자, 여전히 루비를 사용하는 루비스트입니다.

루비가 덕 타이핑과 동적 타입 시스템의 DNA를 가진 언어라는 걸 잘 압니다.
하지만 현실의 산업 환경에서 정적 타입 시스템이 점점 필수가 되어가는 것도
부정할 수 없었습니다.

루비 생태계는 이 문제에 대해 수년간 치열하게 논의해왔지만,
아직 적극적인 답을 내놓지 못한 것 같습니다.

### 기존 방식

**1) Sorbet**
- 코드 위에 주석처럼 타입을 작성합니다.
- 마치 JSDoc을 쓰고 IDE가 에러를 잡아주길 기대하는 것과 비슷합니다.

```ruby
# Sorbet
extend T::Sig

sig { params(name: String).returns(String) }
def greet(name)
  "Hello, #{name}!"
end
```

**2) RBS**
- Ruby 공식 접근법으로, `.rbs` 파일은 TypeScript의 `.d.ts`와 같은 타입정의용 별도 파일입니다.
- 하지만 Ruby에서는 직접 만들거나 '암묵적 추론 + 수작업 보완'이 필요해 여전히 번거롭습니다.

```rbs
# greet.rbs (별도 파일)
def greet: (String name) -> String
```

```ruby
# greet.rb (타입 정보 없음)
def greet(name)
  "Hello, #{name}!"
end
```

### T-Ruby
- TypeScript처럼, 타입이 코드 안에 있습니다.
- `.trb`로 작성하면 `trc`가 `.rb`와 `.rbs`를 모두 생성합니다.

```trb
# greet.trb
def greet(name: String): String
  "Hello, #{name}!"
end
```

```bash
trc greet.trb
# => build/greet.rb
#  + build/greet.rbs
```

### 그 외 ...
**Crystal** 같은 새로운 언어도 있지만, 그것은 엄밀히 루비와 다른 언어입니다.

우리는 여전히 루비를 사랑하고,
이것이 루비 생태계의 **탈출이 아닌 진보**이기를 원합니다.

---

## 설치

```bash
# RubyGems로 설치 (권장)
gem install t-ruby

# 소스에서 설치
git clone https://github.com/pyhyun/t-ruby
cd t-ruby && bundle install
```

### 설치 확인

```bash
trc --version
```

---

## 빠른 시작

### 1. 프로젝트 초기화

```bash
trc --init
```

다음 항목들이 생성됩니다:
- `trbconfig.yml` — 프로젝트 설정 파일
- `src/` — 소스 디렉토리
- `build/` — 출력 디렉토리

### 2. `.trb` 작성

```trb
# src/hello.trb
def greet(name: String): String
  "Hello, #{name}!"
end

puts greet("world")
```

### 3. 컴파일

```bash
trc src/hello.trb
```

### 4. 실행

```bash
ruby build/hello.rb
# => Hello, world!
```

### 5. 워치 모드

```bash
trc -w           # trbconfig.yml의 소스 디렉토리 감시 (기본값: src/)
trc -w lib/      # 특정 디렉토리 감시
```

파일 변경 시 자동으로 재컴파일됩니다.

---

## 설정

`trc --init`은 모든 설정 옵션이 포함된 `trbconfig.yml` 파일을 생성합니다:

```yaml
# T-Ruby 설정 파일
# 참고: https://type-ruby.github.io/docs/getting-started/project-configuration

source:
  include:
    - src
  exclude: []
  extensions:
    - ".trb"
    - ".rb"

output:
  ruby_dir: build
  # rbs_dir: sig  # 선택: .rbs 파일을 위한 별도 디렉토리
  preserve_structure: true
  # clean_before_build: false

compiler:
  strictness: standard  # strict | standard | permissive
  generate_rbs: true
  target_ruby: "3.0"
  # experimental: []
  # checks:
  #   no_implicit_any: false
  #   no_unused_vars: false
  #   strict_nil: false

watch:
  # paths: []  # 추가 감시 경로
  debounce: 100
  # clear_screen: false
  # on_success: "bundle exec rspec"
```

---

## 기능

- **타입 어노테이션** — 파라미터와 리턴 타입, 컴파일 시 제거됨
- **유니온 타입** — `String | Integer | nil`
- **제네릭** — `Array<User>`, `Hash<String, Integer>`
- **인터페이스** — 객체 간 계약 정의
- **타입 별칭** — `type UserID = Integer`
- **RBS 생성** — Steep, Ruby LSP, Sorbet과 연동
- **IDE 지원** — VS Code, Neovim + LSP
- **워치 모드** — 파일 변경 시 자동 재컴파일

---

## 빠른 링크

**시작하기**
- [VS Code 확장](./docs/vscode/ko/getting-started.md)
- [Vim 설정](./docs/vim/ko/getting-started.md)
- [Neovim 설정](./docs/neovim/ko/getting-started.md)

**가이드**
- [구문 강조](./docs/syntax-highlighting/ko/guide.md)

---

## 상태

> **실험적** — T-Ruby는 활발히 개발 중입니다.
> API가 변경될 수 있습니다. 아직 프로덕션 사용은 권장하지 않습니다.

| 마일스톤 | 상태 |
|----------|------|
| 타입 파싱 & 제거 | ✅ |
| 코어 타입 시스템 | ✅ |
| LSP & IDE 지원 | ✅ |
| 고급 기능 | ✅ |

자세한 내용은 [ROADMAP.md](./ROADMAP.md)를 참조하세요.

---

## 기여하기

기여를 환영합니다! 이슈와 풀 리퀘스트를 자유롭게 제출해 주세요.

## 라이선스

[MIT](./LICENSE)
