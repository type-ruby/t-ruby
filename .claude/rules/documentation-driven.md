<!-- Follows Document Simplification Principle: max 200 lines -->

# 문서 주도 개발 규칙

> 문서에 작성된 모든 사실과 코드 예제는 자동화된 테스트로 검증되어야 한다.

---

## 1. 핵심 원칙

### 문서 = 실행 가능한 명세

- 문서의 모든 코드 예제는 실제로 컴파일되어야 함
- 문서에 명시된 동작은 테스트로 검증되어야 함
- 문서와 구현이 불일치하면 버그로 간주

### 검증 대상

| 유형 | 설명 | 검증 방법 |
|------|------|----------|
| 코드 예제 | `.trb` 코드 블록 | 컴파일 테스트 |
| 명시된 동작 | "X는 Y를 반환한다" | 유닛 테스트 |
| CLI 명령어 | `trc compile file.trb` | 통합 테스트 |
| 에러 메시지 | 예상 에러 출력 | 에러 테스트 |

---

## 2. 문서 위치별 규칙

### 공식 문서 사이트 (`t-ruby.github.io/docs/`)

- 모든 코드 예제는 `spec/docs/` 테스트로 검증
- 각 페이지별 검증 상태 뱃지 표시
- 3개 언어 버전 동기화 유지

### 프로젝트 README

- 설치 명령어가 실제로 동작하는지 CI에서 검증
- 퀵스타트 예제가 컴파일되는지 검증

### API 문서 (`lib/t_ruby/`)

- YARD 주석의 예제 코드 검증
- `@example` 태그 내용이 실행 가능해야 함

---

## 3. 코드 예제 작성 규칙

### 마크다운 형식

```markdown
```ruby title="example.trb"
def greet(name: String): String
  "Hello, #{name}!"
end
```
```

### 필수 요소

- `title` 속성으로 파일명 명시
- 완전한 실행 가능한 코드 (스니펫 아님)
- 예상 결과가 있으면 주석으로 표시

### 에러 예제

```ruby title="error-example.trb"
# 이 코드는 타입 에러를 발생시킴
def add(a: Integer, b: Integer): Integer
  a + b
end

add("hello", "world")  # Error: Expected Integer, got String
```

---

## 4. 검증 시스템

### 검증 파이프라인

```
문서 마크다운
    ↓
DocsExampleExtractor (코드 블록 추출)
    ↓
DocsExampleVerifier (컴파일/타입체크)
    ↓
DocsBadgeGenerator (뱃지 생성)
    ↓
CI 리포트
```

### Rake 태스크

```bash
# 모든 문서 예제 검증
bundle exec rake docs:verify

# 뱃지 생성
bundle exec rake docs:badge

# 특정 섹션만 검증
bundle exec rake docs:verify[learn/basics]
```

---

## 5. 뱃지 상태

| 상태 | 의미 | 색상 |
|------|------|------|
| `VERIFIED` | 모든 예제 검증 통과 | 녹색 |
| `PARTIAL` | 일부 예제만 검증 | 노란색 |
| `UNVERIFIED` | 검증되지 않음 | 빨간색 |

### 뱃지 표시 위치

각 문서 페이지 상단 제목 옆에 표시:

```markdown
# Basic Types ![Verified](badge-url)
```

---

## 6. 문서 변경 워크플로우

### 새 기능 문서화

1. 기능 구현 완료
2. 문서 작성 (코드 예제 포함)
3. `spec/docs/` 에 검증 테스트 추가
4. `rake docs:verify` 통과 확인
5. PR 제출

### 기존 문서 수정

1. 문서 수정
2. 관련 테스트 업데이트
3. `rake docs:verify` 통과 확인
4. 3개 언어 동기화
5. PR 제출

---

## 7. CI 통합

### docs-verify Job

```yaml
docs-verify:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
    - name: Verify documentation examples
      run: bundle exec rake docs:verify
```

### 실패 시 대응

- 문서 예제가 컴파일 실패 → PR 차단
- 명시된 동작과 불일치 → PR 차단
- 뱃지 상태 변경 필요 → 경고

---

## 8. 예외 사항

검증을 건너뛸 수 있는 경우:

- 의사 코드 (pseudo-code) 블록
- 언어 비교 예제 (다른 언어 코드)
- 의도적 에러 시연 (명시적 표시 필요)

### 예외 표시 방법

```markdown
```pseudo
# 이것은 의사 코드입니다
type Maybe<T> = Some<T> | None
```
```

---

## 관련 문서

- [TDD 워크플로우 규칙](./tdd-workflow.md)
- [코드 리뷰 체크리스트](./code-review-checklist.md)
- [DOCUMENTATION.md](../docs/DOCUMENTATION.md)
