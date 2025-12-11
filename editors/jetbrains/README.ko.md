# T-Ruby JetBrains 플러그인

JetBrains IDE(RubyMine, IntelliJ IDEA, WebStorm 등)를 위한 T-Ruby 언어 지원 플러그인입니다.

## 기능

- **구문 강조**: `.trb` 및 `.d.trb` 파일의 완전한 구문 강조
- **코드 완성**: 타입 인식 자동 완성 제안
- **실시간 진단**: 인라인 타입 오류 보고
- **정의로 이동**: 타입 및 함수 정의로 이동
- **호버 정보**: 호버 시 타입 정보 표시
- **컴파일 명령**: IDE에서 직접 T-Ruby 파일을 Ruby로 컴파일

## 요구 사항

- JetBrains IDE 2024.2 이상
- [LSP4IJ 플러그인](https://plugins.jetbrains.com/plugin/23257-lsp4ij) 설치
- T-Ruby 컴파일러(`trc`)가 PATH에 설치되어 있어야 함

### T-Ruby 컴파일러 설치

```bash
gem install t-ruby
```

## 설치

### JetBrains Marketplace에서 설치

1. JetBrains IDE 열기
2. **Settings** → **Plugins** → **Marketplace**로 이동
3. "T-Ruby" 검색
4. **Install** 클릭

### 수동 설치

1. [Releases](https://github.com/type-ruby/t-ruby/releases)에서 최신 `.zip` 다운로드
2. **Settings** → **Plugins** → **⚙️** → **Install Plugin from Disk...** 이동
3. 다운로드한 `.zip` 파일 선택

## 사용법

### T-Ruby 파일 생성

`.trb` 확장자로 새 파일 생성:

```ruby
# example.trb
type UserId = Integer

def greet(name: String): String
  "Hello, #{name}!"
end

def find_user(id: UserId): User | nil
  # ...
end
```

### 컴파일

- **단축키**: `Ctrl+Shift+T` (macOS: `Cmd+Shift+T`)
- **메뉴**: **Tools** → **T-Ruby** → **Compile T-Ruby File**
- **컨텍스트 메뉴**: `.trb` 파일 우클릭 → **Compile T-Ruby File**

### 선언 파일 생성

- **단축키**: `Ctrl+Shift+D` (macOS: `Cmd+Shift+D`)
- **메뉴**: **Tools** → **T-Ruby** → **Generate Declaration File**

## 설정

**Settings** → **Tools** → **T-Ruby**:

| 설정 | 설명 | 기본값 |
|------|------|--------|
| T-Ruby compiler path | `trc` 실행 파일 경로 | `trc` (PATH에서) |
| Enable LSP | LSP 기능 활성화 | `true` |
| Enable diagnostics | 실시간 타입 오류 표시 | `true` |
| Enable completion | 코드 완성 활성화 | `true` |

## 지원 IDE

- RubyMine 2024.2+
- IntelliJ IDEA 2024.2+ (Ultimate & Community)
- WebStorm 2024.2+
- PyCharm 2024.2+
- GoLand 2024.2+
- 기타 JetBrains IDE 2024.2+

## 소스에서 빌드

```bash
# 저장소 클론
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby/editors/jetbrains

# 플러그인 빌드
./gradlew buildPlugin

# 플러그인 ZIP은 build/distributions/에 생성됨
```

### 개발 모드에서 실행

```bash
./gradlew runIde
```

플러그인이 설치된 샌드박스 IDE 인스턴스가 실행됩니다.

## 라이선스

MIT License - 자세한 내용은 [LICENSE](../../LICENSE) 참조

## 링크

- [T-Ruby 문서](https://type-ruby.github.io)
- [GitHub 저장소](https://github.com/type-ruby/t-ruby)
- [LSP4IJ 플러그인](https://plugins.jetbrains.com/plugin/23257-lsp4ij)
