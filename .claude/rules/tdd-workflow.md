<!-- Follows Document Simplification Principle: max 200 lines -->

# TDD 워크플로우 규칙

> t-ruby 개발을 위한 테스트 주도 개발 지침

---

## 1. 핵심 원칙

### Red-Green-Refactor 사이클

1. **Red**: 실패하는 테스트를 먼저 작성
2. **Green**: 테스트를 통과하는 최소한의 코드 작성
3. **Refactor**: 테스트가 통과하는 상태에서 코드 개선

### 테스트 우선, 항상

- 새 기능은 실패하는 테스트로 시작
- 버그 수정은 버그를 재현하는 테스트로 시작
- 테스트 없는 프로덕션 코드 금지

### 실제 동작 검증 필수

- **단위 테스트만으로는 불충분**: "값을 읽는다", "객체가 생성된다" 수준의 테스트는 기능 검증이 아님
- **End-to-End 테스트 필수**: 모든 기능은 실제 동작을 검증하는 e2e 테스트를 포함해야 함
- **설정 옵션 테스트**: Config 값을 읽는 것뿐 아니라, 해당 설정이 실제로 동작에 영향을 미치는지 검증

```ruby
# ❌ 나쁜 예: 값만 확인
it "returns 'strict' when set" do
  config = create_config("compiler:\n  strictness: strict")
  expect(config.strictness).to eq("strict")  # 값만 읽음
end

# ✅ 좋은 예: 실제 동작 검증
it "strict mode rejects implicit any types" do
  config = create_config("compiler:\n  strictness: strict")
  compiler = TRuby::Compiler.new(config)
  source = "def foo(x)\n  x\nend"  # 타입 없는 파라미터
  expect { compiler.compile(source) }.to raise_error(/implicit any/)
end
```

---

## 2. 커버리지 기준

| 컴포넌트 | 목표 | 최소 |
|----------|------|------|
| 컴파일러 코어 (`lib/t_ruby/`) | 95% | 90% |
| 에디터 플러그인 (`editors/`) | 80% | 70% |
| 문서 예제 | 100% | 100% |

---

## 3. 테스트 무결성 규칙

### 가짜 통과 테스트 금지

- 테스트는 정당하게 통과하거나 실패해야 함
- 실패를 숨기는 트릭, 스텁, 목 금지
- 테스트가 실패하고 수정할 수 없는 경우:
  1. 실패 이유 문서화
  2. GitHub 이슈 생성
  3. 테스트를 실패 상태로 유지 (skip 금지)
  4. 명시적 결정 후에만 삭제

### 금지된 관행

- `skip` 또는 `pending`으로 실패 숨기기
- 통과를 위해 거짓 값 반환하는 스텁
- 문제를 드러내는 assertion 제거
- 테스트해야 할 기능을 목으로 대체

---

## 4. 커밋 전 체크리스트

모든 커밋 전:

- [ ] 모든 기존 테스트 통과 (`bundle exec rspec`)
- [ ] 새 코드에 해당 테스트 존재
- [ ] 테스트 커버리지 유지 또는 개선
- [ ] skip/pending 테스트 추가 없음

---

## 5. 테스트 구조

### 파일 구조

```
spec/
├── t_ruby/
│   ├── compiler_spec.rb      # 유닛 테스트
│   ├── parser_spec.rb
│   └── ...
├── integration/
│   └── integration_spec.rb   # E2E 테스트
└── spec_helper.rb
```

### 명명 규칙

- 스펙 파일: `{모듈명}_spec.rb`
- 테스트 그룹: `describe ClassName` 또는 `describe '#method_name'`
- 테스트 케이스: `it '특정 동작을 수행한다'`

---

## 6. 테스트 패턴 (AAA)

```ruby
describe '#compile' do
  it '타입이 있는 함수를 Ruby로 컴파일한다' do
    # Arrange (준비)
    source = "def add(a: Integer, b: Integer): Integer\n  a + b\nend"
    compiler = TRuby::Compiler.new

    # Act (실행)
    result = compiler.compile(source)

    # Assert (검증)
    expect(result).to include('def add(a, b)')
    expect(result).not_to include('Integer')
  end
end
```

---

## 7. 테스트 실행

```bash
# 전체 테스트 실행
bundle exec rspec

# 특정 파일 실행
bundle exec rspec spec/t_ruby/compiler_spec.rb

# 커버리지 리포트 확인
bundle exec rspec
open coverage/index.html
```

---

## 8. 예외 사항

TDD를 건너뛸 수 있는 경우:

- 순수 설정 파일 변경
- 문서만 변경 (코드 예제 없음)
- 에셋 업데이트 (이미지, 아이콘)

---

## 관련 문서

- [TESTING.md](../../TESTING.md) - 테스트 원칙
- [코드 리뷰 체크리스트](./code-review-checklist.md)
- [문서 주도 개발 규칙](./documentation-driven.md)
