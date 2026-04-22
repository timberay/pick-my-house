# Design: 부부 평점카드 기반 이사집 평가 시스템

Status: APPROVED
Mode: Startup
Date: 2026-04-22
Branch: main
Origin: /office-hours (quality score 8.4/10, 2 rounds of adversarial review)
Origin doc: `~/.gstack/projects/timberay-pick-my-house/tonny-main-design-20260422-093334.md`

## Problem Statement

이사 갈 집을 여러 채 방문하며 평가할 때, 현재 **한국 프롭테크 시장의 기존 앱(직방/다방/호갱노노 등)은 매물 조회·시세 중심이고 "방문 시 평가 및 비교" 기능이 사실상 부재**하다.
이 공백 속에서 사용자는 개인 구글 문서·PDF 체크리스트·"느낌"으로 의사결정을 내리고, 이사 후 후회하는 경우가 많다.

핵심 사용자 경험 갭:
1. **여러 집을 본 뒤 비교 불가** — 마지막 본 집의 인상이 과잉 대표됨
2. **부부·가족 간 공유 미흡** — 배우자 간 기억·선호 차이가 정량화되지 않음
3. **이사 후 후회 사이클** — 놓친 체크 항목이 사후에 드러남

## Demand Evidence

현재 시점에서의 증거는 **약함**. 솔직하게 기록한다.
- **강한 증거 없음**: 창업자 외 실제 이름이 있는 사용자 인터뷰 0건, 사전 주문 0건, 대기자 0명
- **간접 신호 (Landscape 검색 기반)**:
  - 한국 블로그/유튜브에 "임장 체크리스트" 콘텐츠 풍부 — 수요 존재 신호
  - 구글플레이에 "부동산 임장 체크리스트", "Home Checklist"(Flutter) 등 소규모 앱 존재하나 점유율 미미 — 시도했지만 제품-시장 적합 아직 찾지 못함
  - 전세사기 여파로 "계약 체크리스트" 콘텐츠·도서 시장 성장 (교보문고에 2026 계약 체크리스트 도서 존재)
  - 호갱노노(1등 앱, 200만 회원)에 체크리스트 기능 없음 — 갭
- **창업자 본인의 pain**: 학군 이사 중 "확인할 게 10개 넘음 + 남편 기억 못함" (n=1)

**The Assignment(하단)의 1번이 이 간극을 메운다.** 코드 쓰기 전에 실제 사용자 5명 인터뷰가 게이트 0.

## Status Quo

- **대부분의 사람**: 체크리스트를 **안 쓴다**. 방문 후 "느낌"으로 결정
- **소수의 체계적인 사람**: 구글 문서·인쇄 PDF 체크리스트를 쓴다
- **공통 현상**: 이사 후 "아, 그것도 봤어야 했는데" 후회가 2-12개월 뒤에 발현
- **의사결정 구조**: 부동산 중개인 주도, 부부가 각자 본 뒤 비언어적 합의

**핵심 통찰**: 사용자는 "점검의 필요성"을 가장 필요한 순간(현장 방문 중)에 **가장 적게 느낀다**. 후회는 사후에 온다. 이건 "진통제가 아닌 비타민"의 전형이다.

## Target User & Narrowest Wedge

**페르소나**: 40대 아이 둘 엄마 (학군 이사)
- 확인해야 할 항목이 10개 이상
- 남편은 기억 못함 → 부부 간 정량화된 공유 필요
- 초등/중등 전환기 학군 민감
- 프롭테크 유료 사용 경험 있음

**Narrowest Wedge (이번 주 안에 쓸 수 있는 형태)**:
- 한 집에 대한 **10개 고정 범주 평점카드**(1-5점)
- 부부가 각각 평점 입력
- 방문한 여러 집 자동 비교 리포트
- 공유 링크로 배우자 초대

유료 계층은 **나중**. MVP는 무료 + 실제 사용 여부 검증.

## Constraints

- **기술 스택**: Rails 8, Hotwire (Turbo + Stimulus), TailwindCSS, Importmap, SQLite + Solid Trifecta, Kamal 2 배포 (CLAUDE.md 준수)
- **언어**: 한국어 UI, 한국어 단일 시작 (다국어 확장은 후순위)
- **모바일-퍼스트**: 주 사용 컨텍스트는 방문 현장 (스마트폰)
- **네트워크**: **온라인 전용 MVP**. 오프라인 지원은 v2 과제
- **인증**: **익명 소유자 + share_token 모델 확정**. User 모델 도입은 v2
- **개발 원칙**: TDD (Red-Green-Refactor), Tidy First, Small Commits (CLAUDE.md 준수)

### Auth 모델 (확정)

- House는 브라우저 세션 쿠키(`owner_session_id`, UUID)로 소유자 식별. DB에 `User` 테이블 없음.
- 배우자는 `share_token` URL로 접근. 첫 진입 시 이름 입력 → 해당 집에 고유한 `rater_session_id` 쿠키 발급.
- 같은 기기에서 2개 이상의 배우자 rater 지원 불필요 (MVP 스코프 밖).
- `share_token` 라이프사이클: 집 생성 시 랜덤 32자 URL-safe 생성, 만료 없음, 소유자가 "링크 재발급" 시 구 토큰 폐기.
- 보안: enumeration 방지 위해 최소 32자 엔트로피. Rate limit (Rack::Attack) 적용.
- **`rater_session_id` 구현 주의**: 같은 기기 2명 배우자 케이스는 MVP 스코프 밖. 구현 중 제약이 부자연스러우면 "link → 이름 입력 → 제출 단위 session" 모델로 변경 가능 (TDD 단계에서 재확인).

## Premises

**합의된 전제**:
1. 타겟은 "40대 아이 둘 가정, 학군 이사" 세그먼트 고정
2. 핵심 가치 = "부부 공유되는 정량화된 비교" (점검 완료가 아님)
3. 체크리스트 형식 **버림** → 평점카드 형식 채택
4. 초기 배포 형태: 독립 웹앱 (PWA 고려)
5. 수요 검증이 우선, 기능 확장은 후순위

**미검증 전제** (리스크):
- 40대 엄마가 모바일에서 5분 이상 체계적 입력을 완수한다
- 부부가 각자 입력한 결과를 실제로 대조·토론한다 (단순 기록이 아닌 의사결정 도구로 쓴다)
- 한 번의 이사 사이클에서 최소 3채 이상 방문한다 (비교 가치가 생기는 최소 수량)

## Approaches Considered

### Approach A: 사진-우선 AI 임장 일지 (기각)
방별 사진 → AI 자동 태깅 → 체크는 사진 주석. Effort: L, Risk: High.
기각: 학습/검증 단계에 오버엔지니어링.

### Approach B: 부부 평점카드 비교기 (채택) ✓
10개 고정 범주 1-5점 부부 각자 평가 → 자동 비교. Effort: S, Risk: Low.

### Approach C: 후회 역산 프롬프트 (조건부 기각)
방문 전 "6개월 후 후회 3가지?" → 집별 특화 체크 항목 생성. Effort: M, Risk: Med.
기각: B 확장 경로로 염두.

## Recommended Approach: 부부 평점카드 비교기

### UX 흐름 (모바일 퍼스트)

**1. 집 추가 화면**
- 집 별칭 (필수, 예: "신반포 32평")
- 주소 (선택), 중개인 연락처 (선택)
- 생성 → 방문 모드 이동

**2. 방문 모드 (현장, 핵심 화면)**
- **10개 고정 범주** (seed):
  1. 학군 접근성 (`school_access`)
  2. 평면 구조 / 공간 배치 (`layout`)
  3. 채광 / 향 (`lighting`)
  4. 소음 (`noise`)
  5. 수납 공간 (`storage`)
  6. 주차 (`parking`)
  7. 노후도 / 수리 상태 (`condition`)
  8. 엘리베이터 / 동선 (`access`)
  9. 옵션 / 빌트인 (`builtin`)
  10. 주변 편의시설 (`amenities`)
- 각 범주 1-5점 평가 (탭 한 번)
- 각 범주별 자유 메모 1줄 (선택)
- **MVP는 사진 첨부 제외** (v2)
- "내 평가 저장" → Turbo Stream 즉시 반영
- 미입력 범주 = null ("미평가"), 리포트에서 제외

**3. 배우자 초대 화면**
- 공유 링크 생성 (`share_token`)
- 배우자 접속 → 이름 입력 → 동일 평점카드
- 양쪽 모두 평점 입력된 범주부터 리포트 활성화

**4. 비교 리포트 화면**
- 방문한 집 목록 + 각 집별 부부 평균 점수 (양쪽 다 평가한 범주만 계산)
- **"의견 일치 범주"** = `|남편 점수 − 아내 점수| ≤ 1`
- **"의견 갈린 범주"** = `|남편 점수 − 아내 점수| ≥ 2`
- **"이 집이 다른 집보다 앞선 범주"** = 해당 집 부부 평균이 다른 집들 평균보다 `+1.0` 이상
- **공유: Web Share API**로 단순화 (카카오 SDK는 v2)
- PDF/Solid Queue 파이프라인은 v2

### 데이터 모델 (Rails 8, MVP 확정)

```
House
  - alias:string (required)
  - address:string (nullable)
  - agent_contact:string (nullable)
  - owner_session_id:string (required, indexed)
  - share_token:string (required, unique, 32 chars URL-safe)

Category (seed, 10개 고정)
  - key:string (unique, e.g., "school_access")
  - label_ko:string (e.g., "학군 접근성")
  - order:integer

Rating
  - house:references
  - category:references
  - rater_name:string (required)
  - rater_session_id:string (required)
  - score:integer (1-5, required)
  - memo:text (nullable)
  - unique index on (house_id, category_id, rater_session_id)
```

**Rails 8 특수 고려**:
- Hotwire Turbo Stream으로 평점 입력 시 즉시 반영
- Solid Queue/Cable은 **MVP 미사용** (v2)
- SQLite 백업: `litestream` 또는 일일 `sqlite3 .backup` + S3 — 게이트 1 전에 확정

### 구성 요소 (Components)

각 단위는 명확한 경계와 단일 책임을 가진다:

- `HousesController` — 집 CRUD (owner_session_id 스코프)
- `RaterSessionsController` — share_token 진입점, 이름 입력, rater_session_id 발급
- `RatingsController` — 평점 upsert (Turbo Stream 응답)
- `ReportsController` — 단일 집 리포트 / 집 간 비교 리포트
- `OwnerIdentity` concern — owner_session_id 쿠키 관리
- `RaterIdentity` concern — rater_session_id 쿠키 관리
- `ScorecardCalculator` (POJO) — 일치/불일치/앞선범주 계산 (순수 함수, 테스트 용이)
- `CategorySeeder` (db/seeds.rb) — 10개 범주 보장

### 에러 처리

- **share_token 유효하지 않음**: 404 + 한국어 안내 ("초대 링크가 만료되었거나 잘못되었습니다")
- **owner_session_id 없이 보호 경로 접근**: 자동으로 홈으로 리다이렉트 (쿠키 없는 새 방문자)
- **동시 수정 충돌**: Rating unique index + optimistic — upsert 실패 시 Turbo Stream으로 최신 값 표시
- **Rate limit 초과**: 429 + "잠시 후 다시 시도해 주세요"
- **JavaScript 비활성**: Turbo 없이도 기본 form submission 작동 (progressive enhancement)

### 테스트 전략 (TDD)

**모델 테스트**:
- House validation (alias 필수, share_token 유일)
- Rating 1-5 범위, (house, category, rater_session_id) unique
- 10개 Category seed 로딩

**Request 테스트**:
- owner_session_id 쿠키로 내 House만 보임
- share_token URL 접근 가능 / 다른 token 접근 거부
- Turbo Stream 평점 응답 포맷
- Rate limit 동작 확인

**System 테스트** (Capybara + 모바일 뷰포트 375x667):
- 집 생성 → 평점 입력 → 저장 → 리포트 전체 플로우
- 비교 리포트 경계값 (점수 차 =1, =2, =3)
- 접근성 수동 체크: 대비, 터치 타겟 ≥44px (axe-core 자동화는 v2)

## Open Questions (v2 후보)

1. ~~인증 방식~~ — **확정**: 익명 소유자 + share_token
2. **오프라인 지원 (v2)**: Service Worker + IndexedDB → 온라인 복귀 시 동기화
3. **학군 데이터 (v2)**: 공공데이터포털 '학교기본정보' API 연동 vs 수동 입력
4. **유료화 시점 (v2)**: Week 4 검증 후 결정
5. **카카오톡 공유 (v2)**: 카카오 JavaScript SDK (도메인 등록 필요)
6. **사진 첨부 (v2)**: ActiveStorage 범주별 사진
7. **SQLite 백업 전략 (게이트 1 전 결정, blocker)**: `litestream` vs 일일 스크립트

## Success Criteria (단계별 게이트)

**게이트 0: 수요 검증 (Week 0, 신규 feature 코드 0줄)** — The Assignment 참조
  - 기존 Rails 8 프로젝트 setup은 그대로 유지. House/Category/Rating 모델 및 관련 화면 구현은 이 게이트 통과 전까지 금지.
- [ ] 40대 아이 둘 엄마 5명 인터뷰 완료
- [ ] 5명 중 **3명 이상** "집 평가 힘들다" + "이런 앱 쓸 의향 있다" 응답
- 미달성 → 신규 코드 금지, 피봇 검토 (전세사기/임장러/신축 사전점검 세그먼트)

**게이트 1: 기술 MVP (Week 1-2, 게이트 0 통과 후)**
- [ ] Rails 8 + Hotwire 평점 입력 → 저장 → 리포트 전체 플로우 작동
- [ ] 모바일 Chrome / Safari iOS 반응형
- [ ] RuboCop/Brakeman 클린, Request/System 테스트 통과
- [ ] share_token 보안 검증 (Rate limit, 엔트로피)
- [ ] **SQLite 백업 파이프라인 결정 및 운영** — 배포 전 blocker

**게이트 2: 베타 검증 (Week 3-4)**
- [ ] 인터뷰 5명 중 참여 의향 있는 3명+ 베타 초대
- [ ] 각 가정 최소 2채 평가 완료
- [ ] 2가정+ 부부 양쪽 평점 입력
- [ ] 최소 1명 "다음 이사에도 쓸 것 같다" 피드백

**결정 시점 (Week 4 종료)**:
- 베타 가정 3개+ actively 사용 → 확장 (A 또는 C 요소 검토)
- 3개 미만 → 피봇 또는 세그먼트 포기

## Distribution Plan

- **MVP 단계**: Kamal 2 + Docker 단일 VPS
- **URL**: 도메인 취득 후 예 `picky.house` 또는 서브도메인
- **PWA (MVP 범위)**: `manifest.json` + 아이콘 + "홈 화면에 추가" 메타만. **오프라인 캐싱(Service Worker)은 v2**. Constraints의 "온라인 전용 MVP"와 일관.
- **초기 획득**: 지인 직접 초대 (5명). SNS/블로그는 Week 4 후
- **CI/CD**: GitHub Actions → Kamal deploy (Rails 8 기본 템플릿)

## Dependencies

- Rails 8.1.x / Ruby 3.4.8 (확정)
- TailwindCSS 3.x (확정)
- Rack::Attack (Rate limit)
- Kamal 2 배포 환경 (VPS 선정 필요)
- SQLite 백업 도구 (`litestream` 또는 스크립트 — 게이트 1 전 확정)
- 도메인 등록 (Week 3 시점)
- ActiveStorage는 **MVP 미사용** (v2)

## The Assignment (코드 시작 전 필수)

**이번 주 안에 40대 아이 둘 엄마 5명과 통화/카톡.** 4가지 질문:

1. "최근 1-3년 내에 이사하셨거나 검토 중이신가요? 학군 때문에요?"
2. "집 보러 다닐 때 **뭐가 제일 힘드셨어요**? 남편과 의견 맞추는 건 어떠셨어요?"
3. "기존 부동산 앱(호갱노노/직방) 중에 집 **평가**용으로 쓰신 게 있으세요?"
4. "만약 '방문한 집 여러 채를 부부가 각자 평가하고 자동 비교'해주는 앱이 있다면 쓰시겠어요? 얼마까지 내시겠어요?"

**5명 중 3명 이상** "2번에서 진짜 힘들었다" + "4번에서 쓰겠다" → 코딩 시작.
**1-2명** → 피봇 검토.
**0명** → 이 아이디어 포기, 다른 아이템 탐색.

인터뷰 구실: "이 앱 기획 중인데 피드백 받고 싶어요". 5명 인터뷰 1주일 내 완료 가능.
