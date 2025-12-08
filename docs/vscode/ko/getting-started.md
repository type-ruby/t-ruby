# T-Ruby for VS Code - 시작하기

T-Ruby VS Code 확장 프로그램에 오신 것을 환영합니다! 이 가이드는 타입이 있는 Ruby 개발을 위한 T-Ruby 확장 프로그램의 설치 및 구성 방법을 안내합니다.

## 사전 요구 사항

확장 프로그램을 설치하기 전에 다음이 필요합니다:

- **Visual Studio Code** 1.75.0 이상
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

### 방법 1: VS Code 마켓플레이스 (권장)

1. VS Code를 엽니다
2. `Ctrl+Shift+X` (Windows/Linux) 또는 `Cmd+Shift+X` (macOS)를 눌러 확장 탭을 엽니다
3. "T-Ruby"를 검색합니다
4. **설치**를 클릭합니다

### 방법 2: VSIX 파일로 설치

1. [Releases](https://github.com/type-ruby/t-ruby/releases)에서 `.vsix` 파일을 다운로드합니다
2. VS Code를 엽니다
3. `Ctrl+Shift+P`를 누르고 "VSIX에서 설치"를 입력합니다
4. 다운로드한 파일을 선택합니다

### 방법 3: 소스에서 빌드

```bash
# 저장소 클론
git clone https://github.com/type-ruby/t-ruby.git
cd t-ruby/editors/vscode

# 의존성 설치
npm install

# 확장 프로그램 빌드
npm run compile

# 확장 프로그램 설치
code --install-extension .
```

## 설정

설치 후 VS Code 설정(`Ctrl+,`)에서 확장 프로그램을 구성합니다:

```json
{
  "t-ruby.lspPath": "trc",
  "t-ruby.enableLSP": true,
  "t-ruby.diagnostics.enable": true,
  "t-ruby.completion.enable": true
}
```

### 설정 옵션

| 옵션 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `t-ruby.lspPath` | string | `"trc"` | T-Ruby 컴파일러 경로 |
| `t-ruby.enableLSP` | boolean | `true` | 언어 서버 활성화 |
| `t-ruby.diagnostics.enable` | boolean | `true` | 실시간 진단 활성화 |
| `t-ruby.completion.enable` | boolean | `true` | 자동완성 활성화 |

## 기능

### 구문 강조

확장 프로그램은 다음 파일에 대한 완전한 구문 강조를 제공합니다:
- `.trb` 파일 (T-Ruby 소스 파일)
- `.d.trb` 파일 (T-Ruby 선언 파일)

타입 어노테이션, 인터페이스, 타입 별칭이 구별되어 강조됩니다.

### IntelliSense

- **자동완성**: 매개변수와 반환 타입에 대한 타입 제안
- **호버**: 심볼 위에 마우스를 올려 타입 정보 확인
- **정의로 이동**: 타입/함수 정의로 이동

### 진단

다음에 대한 실시간 오류 검사:
- 알 수 없는 타입
- 중복 정의
- 구문 오류

### 명령어

명령 팔레트(`Ctrl+Shift+P`)에서 접근:

| 명령어 | 설명 |
|--------|------|
| `T-Ruby: Compile Current File` | 현재 `.trb` 파일 컴파일 |
| `T-Ruby: Generate Declaration File` | 소스에서 `.d.trb` 생성 |
| `T-Ruby: Restart Language Server` | LSP 서버 재시작 |

## 빠른 시작 예제

1. 새 파일 `hello.trb`를 생성합니다:

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

2. 파일을 저장하면 구문 강조와 실시간 진단을 볼 수 있습니다

3. 타입 위에 마우스를 올려 정의를 확인합니다

4. `Ctrl+Space`를 눌러 자동완성 제안을 받습니다

## 문제 해결

### LSP가 시작되지 않음

1. `trc`가 설치되어 있는지 확인: `which trc`
2. 설정에서 경로 확인: `t-ruby.lspPath`
3. 출력 패널 확인: 보기 > 출력 > T-Ruby Language Server

### 구문 강조가 안 됨

1. 파일 확장자가 `.trb` 또는 `.d.trb`인지 확인
2. 파일 연결 확인: 보기 > 명령 팔레트 > "언어 모드 변경"

### 성능 문제

- 큰 파일의 진단 비활성화: `"t-ruby.diagnostics.enable": false`
- 언어 서버 재시작: 명령 팔레트 > "T-Ruby: Restart Language Server"

## 다음 단계

- [구문 강조 가이드](../../syntax-highlighting/ko/guide.md)
- [T-Ruby 언어 레퍼런스](https://github.com/type-ruby/t-ruby/wiki)
- [이슈 보고](https://github.com/type-ruby/t-ruby/issues)

## 지원

질문이나 버그 보고는 다음을 방문해 주세요:
- GitHub Issues: https://github.com/type-ruby/t-ruby/issues
- Discussions: https://github.com/type-ruby/t-ruby/discussions
