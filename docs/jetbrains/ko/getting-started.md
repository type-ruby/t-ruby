<p align="center">
  <img src="https://avatars.githubusercontent.com/u/248530250" alt="T-Ruby" height="120">
</p>

<h1 align="center">T-Ruby for JetBrains</h1>

<p align="center">
  <a href="https://type-ruby.github.io">공식 홈페이지</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="https://github.com/type-ruby/t-ruby">GitHub</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="https://plugins.jetbrains.com/plugin/29335-t-ruby">JetBrains 마켓플레이스</a>
</p>

---

T-Ruby JetBrains 플러그인에 오신 것을 환영합니다! 이 가이드는 타입이 있는 Ruby 개발을 위한 T-Ruby 플러그인의 설치 및 구성 방법을 안내합니다.

> **Note**: 이 플러그인은 IntelliJ IDEA, RubyMine, WebStorm 등 모든 JetBrains IDE에서 동작합니다.

## 사전 요구 사항

플러그인을 설치하기 전에 다음이 필요합니다:

- **JetBrains IDE** 2023.1 이상 (IntelliJ IDEA, RubyMine, WebStorm 등)
- **Ruby** 3.0 이상
- **T-Ruby 컴파일러** (`trc`)가 설치되어 PATH에 등록되어 있어야 함

### T-Ruby 컴파일러 설치

```bash
# gem으로 설치 (권장)
gem install t-ruby
```

설치 확인:
```bash
trc --version
```

## 설치 방법

### 방법 1: JetBrains 마켓플레이스 (권장)

1. JetBrains IDE를 엽니다
2. `Settings/Preferences` > `Plugins`로 이동합니다
3. `Marketplace` 탭에서 "T-Ruby"를 검색합니다
4. **Install**을 클릭합니다
5. IDE를 재시작합니다

또는 [JetBrains 마켓플레이스](https://plugins.jetbrains.com/plugin/29335-t-ruby)에서 직접 설치하세요.

### 방법 2: 디스크에서 설치 (예정)

1. [Releases](https://github.com/type-ruby/t-ruby/releases)에서 `.zip` 파일을 다운로드합니다
2. `Settings/Preferences` > `Plugins`로 이동합니다
3. 톱니바퀴 아이콘 > `Install Plugin from Disk...`를 클릭합니다
4. 다운로드한 파일을 선택합니다

### 방법 3: 소스에서 빌드

```bash
# 저장소 클론
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby/editors/jetbrains

# Gradle로 빌드
./gradlew buildPlugin

# 빌드된 플러그인은 build/distributions/에 생성됩니다
```

## 설정

설치 후 `Settings/Preferences` > `Languages & Frameworks` > `T-Ruby`에서 플러그인을 구성합니다:

### 설정 옵션

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| T-Ruby 컴파일러 경로 | `trc` | T-Ruby 컴파일러 경로 |
| 실시간 진단 활성화 | `true` | 타이핑 중 오류 검사 |
| 자동완성 활성화 | `true` | 타입 기반 자동완성 |

## 기능

### 구문 강조

플러그인은 다음 파일에 대한 완전한 구문 강조를 제공합니다:
- `.trb` 파일 (T-Ruby 소스 파일)
- `.d.trb` 파일 (T-Ruby 선언 파일)

타입 어노테이션, 인터페이스, 타입 별칭이 구별되어 강조됩니다.

### IntelliSense

- **자동완성**: 매개변수와 반환 타입에 대한 타입 제안
- **호버**: 심볼 위에 마우스를 올려 타입 정보 확인
- **정의로 이동**: `Ctrl+Click`으로 타입/함수 정의로 이동

### 진단

다음에 대한 실시간 오류 검사:
- 알 수 없는 타입
- 중복 정의
- 구문 오류

### 액션

`Find Action` (`Ctrl+Shift+A` / `Cmd+Shift+A`)에서 접근:

| 액션 | 설명 |
|------|------|
| `T-Ruby: Compile Current File` | 현재 `.trb` 파일 컴파일 |
| `T-Ruby: Generate Declaration File` | 소스에서 `.d.trb` 생성 |

## 빠른 시작 예제

1. 새 파일 `hello.trb`를 생성합니다:

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

2. 파일을 저장하면 구문 강조와 실시간 진단을 볼 수 있습니다

3. 타입 위에 마우스를 올려 정의를 확인합니다

4. `Ctrl+Space`를 눌러 자동완성 제안을 받습니다

## 문제 해결

### 플러그인이 동작하지 않음

1. `trc`가 설치되어 있는지 확인: `which trc`
2. 설정에서 경로 확인: `Settings` > `Languages & Frameworks` > `T-Ruby`
3. IDE 로그 확인: `Help` > `Show Log in Finder/Explorer`

### 구문 강조가 안 됨

1. 파일 확장자가 `.trb` 또는 `.d.trb`인지 확인
2. 파일 타입 연결 확인: `Settings` > `Editor` > `File Types`

### 성능 문제

- 큰 파일의 진단 비활성화
- IDE 재시작

## 다음 단계

- [구문 강조 가이드](../../syntax-highlighting/ko/guide.md)
- [T-Ruby 언어 레퍼런스](https://github.com/type-ruby/t-ruby/wiki)
- [이슈 보고](https://github.com/type-ruby/t-ruby/issues)

## 지원

질문이나 버그 보고는 GitHub Issues를 방문해 주세요:
https://github.com/type-ruby/t-ruby/issues
