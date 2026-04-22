# Design: 하자 점검 체크리스트 (단독 사용자)

Status: APPROVED
Date: 2026-04-22
Branch: main (post-reset)
Supersedes: `2026-04-22-couple-scorecard-design.md` (아카이브: `archive/scorecard` 브랜치)

## Problem Statement

이사 갈 집을 현장 방문할 때 사용자는 "수도물 잘 나오는지", "벽에 곰팡이 없는지" 같은 **실생활 하자 / 결함**을 점검해야 한다. 이전 MVP 스펙(부부 평점카드 기반 비교)은 질문이 광범위하고 주관적(학군/채광/편의시설)이라 실제 하자 발견 도구로 부적합했다.

이번 스펙은 다음 두 축으로 피벗한다:

1. **단독 사용자** — 부부 공유 / share_token / rater 세션 제거. 한 명의 소유자가 여러 집을 저장하고 각 집을 독립적으로 점검.
2. **광범위 선호 평점 → 구체 하자 신호등** — 10개 주관 범주 × 1-5점 → 10개 하자 도메인 × 약 50개 구체 항목 × 3단계 (양호/주의/심각).

## Scope Boundaries

**In scope (MVP):**
- 익명 소유자 쿠키 기반 집 저장 및 점검 (단일 기기, 단독 사용자)
- 약 50개 고정 하자 점검 항목 (YAML 관리)
- 항목별 3단계 신호등 (양호/주의/심각) + 선택 메모 1줄
- 단일 집 요약 화면 (카운트 + 심각/주의 리스트 + 미점검 접힘)
- 모바일 우선 UX, Hotwire Turbo Stream으로 즉시 반영

**Explicitly out of scope (v2):**
- 사진 첨부 (ActiveStorage)
- 외부 공유 (Web Share API, 카카오 SDK)
- 오프라인 모드 / Service Worker
- 사용자 정의 항목 / 항목 편집
- 집 간 비교 리포트
- 쿠키 분실 시 집 이관 코드
- 정렬/검색/필터
- 다국어 (한국어 단일)
- 외부 APM / Sentry / 유료 기능

## Constraints

- **기술 스택**: Rails 8.1.x, Hotwire (Turbo + Stimulus), TailwindCSS, Importmap, SQLite + Solid Trifecta, Kamal 2 배포
- **언어**: 한국어 UI 단일
- **모바일 우선**: 주 사용 컨텍스트는 방문 현장 스마트폰 (375x667 viewport 기준 테스트)
- **네트워크**: 온라인 전용 (오프라인은 v2)
- **인증**: 익명 소유자 쿠키 (`owner_session_id`) 단일 모델. `User` / `share_token` 없음.
- **개발 원칙**: TDD (Red-Green-Refactor), Tidy First, Small Commits (CLAUDE.md)

## Data Model

```
House
  - alias            :string  (required, 1-50자, 예: "신반포 32평")
  - address          :string  (optional)
  - agent_contact    :string  (optional, 중개인 이름/전화)
  - visited_at       :date    (optional, default: 생성일)
  - owner_session_id :string  (required, indexed)
  - timestamps

InspectionCheck
  - house:references (dependent: :destroy via House)
  - item_key  :string  (indexed, Checklist.item_keys에 포함)
  - severity  :integer (enum: ok=0, warn=1, severe=2)
  - memo      :text    (nullable, 500자 제한)
  - timestamps
  - unique index on (house_id, item_key)
```

**항목 정의 파일**: `config/checklist.yml`

```yaml
water:
  label_ko: "수도/배관"
  items:
    water_pressure:       { label_ko: "수압 충분 (샤워기 세게 틀어서)" }
    hot_water_time:       { label_ko: "온수 30초 내 나옴" }
    rust_free:            { label_ko: "녹물/이물질 없음" }
    drain_speed:          { label_ko: "세면대/싱크대 배수 빠름" }
    balcony_drain:        { label_ko: "베란다 하수구 막힘 없음" }
    toilet_flush:         { label_ko: "변기 물 내림 정상" }
    boiler_on_time:       { label_ko: "보일러 온수 대기 시간 합리적" }

electric:
  label_ko: "전기"
  items:
    outlets_working:      { label_ko: "콘센트 작동 (방별 1개 이상 확인)" }
    breaker_accessible:   { label_ko: "메인/누전 차단기 위치 확인 가능" }
    lights_working:       { label_ko: "조명 모두 작동" }
    aircon_drain:         { label_ko: "에어컨 배수관 설치 가능 (구멍 있음)" }
    internet_line:        { label_ko: "인터넷 회선(랜선/벽 단자) 존재" }

mold:
  label_ko: "곰팡이/결로"
  items:
    ceiling_corner:       { label_ko: "안방 천장/벽 모서리 곰팡이 없음" }
    bath_silicone:        { label_ko: "욕실 천장/실리콘 곰팡이 없음" }
    window_frame:         { label_ko: "창틀(북향 특히) 결로/곰팡이 흔적 없음" }
    wallpaper_stain:      { label_ko: "벽지/장판 얼룩·들뜸 없음" }
    sink_under:           { label_ko: "싱크대 하부 수납장 곰팡이 없음" }
    balcony_wall:         { label_ko: "베란다 벽 얼룩/결로 흔적 없음" }

windows:
  label_ko: "창호/단열"
  items:
    window_smooth:        { label_ko: "창문 여닫이 부드러움" }
    window_lock:          { label_ko: "창문 잠금 장치 정상" }
    window_screen:        { label_ko: "방충망 찢김 없음" }
    window_draft:         { label_ko: "창문 틈새 외풍 없음" }
    double_glazing:       { label_ko: "이중창 여부 확인" }

smell:
  label_ko: "냄새"
  items:
    indoor_musty:         { label_ko: "실내 곰팡이/쉰내 없음" }
    drain_sewer:          { label_ko: "배수구/하수구 역류 냄새 없음" }
    hallway_smell:        { label_ko: "엘베 홀/복도 냄새 없음" }
    trap_water:           { label_ko: "하수구 트랩 물 고임(S트랩) 있음" }

noise:
  label_ko: "소음"
  items:
    floor_noise:          { label_ko: "층간 소음 (가능하면 저녁 방문)" }
    road_noise:           { label_ko: "도로 소음 (창문 닫고 체감)" }
    pipe_noise:           { label_ko: "배관 소리 (이웃 사용 시)" }
    external_noise:       { label_ko: "주변 공사/철도 소리" }

heating:
  label_ko: "난방"
  items:
    boiler_condition:     { label_ko: "보일러 연식/상태" }
    heating_type:         { label_ko: "난방 방식 (지역/개별/도시가스)" }
    winter_cost:          { label_ko: "겨울 난방비 추정치 확인" }
    floor_heating:        { label_ko: "바닥 난방 작동 (시운전)" }

security:
  label_ko: "방범/잠금"
  items:
    door_lock:            { label_ko: "현관 도어락 정상 (리셋 확인)" }
    peephole:             { label_ko: "현관 외시경/카메라" }
    intercom:             { label_ko: "인터폰 영상/음성 정상" }
    window_guard:         { label_ko: "저층일 경우 창문 방범창" }

finish:
  label_ko: "마감/외관"
  items:
    wallpaper:            { label_ko: "벽지 찢김/얼룩/들뜸" }
    flooring:             { label_ko: "장판 찢김/들뜸/변색" }
    tile_grout:           { label_ko: "타일 깨짐/실리콘 마감" }
    door_hinge:           { label_ko: "문 경첩/손잡이 흔들림 없음" }
    kitchen_cabinet:      { label_ko: "싱크대 상판/수납 파손 없음" }
    door_gap:             { label_ko: "방문 틈새/휨 없음" }

surround:
  label_ko: "주변환경"
  items:
    elevator:             { label_ko: "엘리베이터 속도/소리/청결" }
    corridor:             { label_ko: "공용 복도 냄새/청결" }
    garbage:              { label_ko: "쓰레기장 거리/냄새" }
    parking:              { label_ko: "주차장 자리 확보 여부" }
    delivery_security:    { label_ko: "택배/경비 시스템" }
```

10개 도메인 × 4-7항목 = **총 50개** (water 7, electric 5, mold 6, windows 5, smell 4, noise 4, heating 4, security 4, finish 6, surround 5). 카피/문구는 구현 중 1차 pass 후 베타 피드백으로 다듬는다.

## Components

**Controllers (3):**

- `HousesController` (`index / new / create / show / edit / update / destroy`)
  - `owner_session_id` 스코프
  - `show` = 점검 화면 (도메인별 항목 리스트 + 신호등 UI)
- `InspectionChecksController` (`create / update`)
  - `POST /houses/:house_id/checks` 로 upsert (existing by `(house_id, item_key)` unique)
  - Turbo Stream 응답 (대상: 해당 체크 행 + 도메인 진행 카운트)
- `SummariesController` (`show`)
  - `GET /houses/:house_id/summary`
  - `HouseSummary` PORO 사용, 읽기 전용

**Concerns (1):**

- `OwnerIdentity` — 서명된 쿠키 `owner_session_id` 발급/조회. 모든 컨트롤러에 `before_action :ensure_owner_session_id`.

**POROs / Value Objects:**

- `Checklist` (`app/lib/checklist.rb`)
  - `Checklist.domains` → `[DomainStruct, ...]`
  - `Checklist.item(item_key)` → `ItemStruct`
  - `Checklist.item_keys` → `Set<String>`
  - 부팅 시 YAML 로드, 포맷 오류/파일 누락 시 명시적 예외
- `HouseSummary` (`app/lib/house_summary.rb`)
  - 입력: `House + Array<InspectionCheck>`
  - 출력: `{ counts: {ok:, warn:, severe:, unchecked:}, severe_items:, warn_items:, unchecked_items:, deleted_items: }`
  - 순수 함수 — DB 접근 없음, in-memory 테스트 가능

**Views (ERB):**

- `app/views/houses/` — `index`, `new`, `show` (점검 화면), `edit`
- `app/views/inspection_checks/` — `_check_row.html.erb` (Turbo Stream 대상)
- `app/views/summaries/` — `show`
- `app/views/shared/` — `_severity_badge.html.erb`, `_domain_section.html.erb`

**Stimulus Controllers:**

- `severity_selector_controller.js` — 신호등 탭 전환 + form auto-submit
- `memo_toggle_controller.js` — 메모 입력 영역 펼침/접힘

## Data Flow

1. 첫 방문자 `GET /` → `OwnerIdentity`가 `owner_session_id` 쿠키 발급 → 빈 집 목록 표시
2. `GET /houses/new` → 폼 제출 → `House` 생성 → `GET /houses/:id` (점검 화면)로 리다이렉트
3. 점검 화면: 항목 신호등 탭 → `POST /houses/:id/checks {item_key, severity}` → upsert → Turbo Stream으로 해당 행 + 도메인 카운트 교체
4. 메모 추가 토글 → textarea 노출 → 저장 → 같은 upsert 경로 (memo 필드 포함)
5. "요약 보기" → `GET /houses/:id/summary` → `HouseSummary` 계산 결과 렌더
6. 집 삭제: `DELETE /houses/:id` → `dependent: :destroy`로 checks 동반 삭제 → 목록으로

## Error Handling

- 다른 소유자의 집 URL 직접 접근 → 404
- `Checklist.yml` 누락/포맷 오류 → 부팅 실패 (명시적)
- 유효하지 않은 `item_key` 제출 → 422 + 모델 validation 메시지
- YAML에서 삭제된 `item_key`가 기존 레코드에 존재 → 요약의 `deleted_items` 버킷으로 분리 표시 (무음 drop 금지)
- Turbo Stream 실패 → 기본 form 폴백 (full-page reload)
- Rack::Attack 기존 쓰기 엔드포인트 rate limit 유지, 429 한국어 안내
- 쿠키 삭제 사용자 → 기존 집 안 보임 (MVP 복구 없음, v2 이관 코드)

## Testing Strategy

**모델 (`test/models/`):**
- `HouseTest`: alias validation, owner scope, dependent destroy
- `InspectionCheckTest`: severity enum, item_key inclusion, unique per (house, item_key), memo 길이

**POROs (`test/lib/`):**
- `ChecklistTest`: 10 도메인 로드, item_keys 유니크, YAML 오류 시 예외
- `HouseSummaryTest`: 카운트 정확도, deleted_items 버킷 분리, 순수 함수(DB 접근 없이 호출 가능)

**Request (`test/controllers/`):**
- `HousesControllerTest`: 쿠키 자동 발급, 타인 집 404, CRUD 소유자 스코프
- `InspectionChecksControllerTest`: upsert 동작, Turbo Stream 응답 포맷, 422 on invalid severity, 타인 집 404
- `SummariesControllerTest`: 빈 집 / 혼합 상태 요약, 타인 집 404

**System (`test/system/`, Capybara 모바일 viewport 375x667):**
- `inspection_flow_test.rb`: 홈 → 집 생성 → 항목 "심각" 선택 → 메모 저장 → 요약에서 확인
- `house_deletion_test.rb`: 삭제 확인 + 목록에서 사라짐
- `accessibility_touch_targets_test.rb`: 신호등 버튼 ≥ 44px

**TDD 리듬:** Red → Green → Refactor를 한 커밋. Tidy First — 구조와 행동 분리.

## Pivot Execution Plan

1. `git branch archive/scorecard e5591e6` — 현재 로컬 HEAD 보존
2. `git reset --hard origin/main` (381200b) — main을 Rails 스켈레톤으로 리셋
3. 이 스펙 커밋 (main 위에서)
4. `writing-plans` 스킬로 implementation plan 생성
5. 플랜 대로 TDD 구현
6. Gate 1 수준 달성 시 `git push origin main` — CI 녹색 확인

**안전장치:**
- working tree clean 상태에서만 reset 진행
- archive 브랜치 생성 먼저, reset 나중
- reflog 30일 보존 + 필요 시 `git push origin archive/scorecard`로 원격 백업

## Success Criteria

**Gate 1 (기술 MVP):**
- [ ] 홈 → 집 생성 → 항목 점검 → 요약의 전 플로우 모바일에서 작동
- [ ] `Checklist` YAML 약 50 항목 로드
- [ ] 모든 테스트 통과 (모델/Request/System)
- [ ] RuboCop / Brakeman 클린
- [ ] CI 녹색 (push 후)

**Gate 2 (실 사용 검증 — 베타):**
- [ ] 실사용자 5명 중 3명 이상이 한 번의 이사 사이클에서 2채+ 점검 완료
- [ ] 심각 판정 항목이 실제 이사 결정에 반영되었는지 피드백 수집
- [ ] 항목 리스트에서 "빠진 것" / "필요없는 것" 피드백 3건 이상 수집

**결정 시점 (Gate 2 후):** 사진 / 커스텀 항목 / 이관 코드 중 우선순위 정렬.

## Dependencies

- Rails 8.1.x / Ruby 3.4.8
- TailwindCSS 3.x
- Rack::Attack (rate limit, 기존 재사용)
- Kamal 2 + VPS (Gate 1 후)
- SQLite 백업 스크립트 `bin/backup-sqlite` (기존 재사용, archive 브랜치에서 cherry-pick 또는 재작성)

## Open Questions (구현 중 확정)

1. `config/checklist.yml` 파일 경로 — `config/` 가 Rails 규약에 맞음. 대안: `app/lib/checklist/items.yml`. 구현 시 로드 코드 위치와 함께 확정.
2. `bin/backup-sqlite` 재작성 vs archive cherry-pick — 리셋 후 첫 인프라 커밋 시 결정. 재작성이 리소스 측면에서 저렴.
3. Rack::Attack 설정 — archive에서 cherry-pick (간단). 첫 컨트롤러 보안 커밋에 포함.
4. PWA manifest — v2로 밀 수도 있지만 아이콘/manifest.json만 cherry-pick도 저렴. 선택지로 남김.
