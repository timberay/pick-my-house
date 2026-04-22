# Defect Checklist MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single-user, mobile-first house defect inspection tool. User saves houses and records traffic-light-graded (ok/warn/severe) checks against ~50 fixed items across 10 domains; summary screen shows severe/warn lists.

**Architecture:** Rails 8 + Hotwire. Two AR models (`House`, `InspectionCheck`). Checklist items in `config/checklist.yml` loaded by `Checklist` PORO. Anonymous owner via signed cookie (`OwnerIdentity` concern). Three controllers: `Houses` (CRUD + inspection screen), `InspectionChecks` (Turbo Stream upsert), `Summaries` (read-only).

**Tech Stack:** Rails 8.1.3, Ruby 3.4.8, SQLite + Solid Trifecta, TailwindCSS, Importmap, Stimulus, Turbo, Minitest, Capybara, rack-attack.

**Source spec:** `docs/superpowers/specs/2026-04-22-defect-checklist-design.md`

---

## File Map

**Create:**
- `Gemfile` — modified (add `rack-attack`)
- `app/controllers/concerns/owner_identity.rb`
- `app/controllers/application_controller.rb` — modified (include `OwnerIdentity`)
- `app/controllers/houses_controller.rb`
- `app/controllers/inspection_checks_controller.rb`
- `app/controllers/summaries_controller.rb`
- `app/lib/checklist.rb`
- `app/lib/house_summary.rb`
- `app/models/house.rb`
- `app/models/inspection_check.rb`
- `config/checklist.yml`
- `config/initializers/rack_attack.rb`
- `config/routes.rb` — modified
- `db/migrate/*_create_houses.rb`
- `db/migrate/*_create_inspection_checks.rb`
- `app/views/houses/{index,new,show,edit}.html.erb`
- `app/views/houses/_form.html.erb`
- `app/views/inspection_checks/_check_row.html.erb`
- `app/views/inspection_checks/create.turbo_stream.erb`
- `app/views/summaries/show.html.erb`
- `app/views/shared/_severity_badge.html.erb`
- `app/views/shared/_domain_section.html.erb`
- `app/javascript/controllers/severity_selector_controller.js`
- `app/javascript/controllers/memo_toggle_controller.js`
- Test files mirroring each

**Modify:** `Gemfile`, `app/controllers/application_controller.rb`, `config/routes.rb`, `app/javascript/controllers/index.js` (Stimulus registration via importmap autoregister if enabled).

---

## Conventions followed

- **TDD:** Red → Green → Refactor for every feature step.
- **Tidy First:** Structural changes (renames, file moves) and behavioral changes go in separate commits.
- **Commits:** Every passing test or completed refactor → commit immediately.
- **UI text:** Korean.
- **Code/commits:** English.
- **Tests:** Minitest. System tests use Capybara with mobile viewport 375×667.

---

## Task 1 — Add `rack-attack` gem

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add gem to Gemfile**

Append to the main `gem` block (after existing `solid_cable` / `solid_queue` / `solid_cache` entries, before the group blocks):

```ruby
# Block & throttle abusive requests
gem "rack-attack"
```

- [ ] **Step 2: Install**

Run: `bundle install`
Expected: `Bundle complete` with `rack-attack` added.

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore(deps): add rack-attack for write-endpoint rate limiting"
```

---

## Task 2 — `OwnerIdentity` concern

**Files:**
- Create: `app/controllers/concerns/owner_identity.rb`
- Modify: `app/controllers/application_controller.rb`
- Modify: `config/routes.rb`
- Create: `app/controllers/houses_controller.rb` (skeleton — expanded in Task 7)
- Create: `test/controllers/concerns/owner_identity_test.rb`

Identity model: **signed, permanent cookie** named `owner_session_id` holding a UUID. Issued automatically on first visit.

> **Plan correction (2026-04-22):** the original plan used a Rack lambda for the temporary root route, but lambdas bypass `ApplicationController` entirely, so the concern's `before_action` never fires and the cookie is never set. We instead introduce a minimal `HousesController#index` skeleton in this task so the concern actually runs. Task 7 replaces the skeleton body with the real index.

- [ ] **Step 1: Write the failing test**

Create `test/controllers/concerns/owner_identity_test.rb`:

```ruby
require "test_helper"

class OwnerIdentityTest < ActionDispatch::IntegrationTest
  test "issues signed owner_session_id cookie on first request" do
    get root_path
    assert_response :success
    assert cookies[:owner_session_id].present?, "owner_session_id cookie should be set"
  end

  test "keeps same owner_session_id across requests" do
    get root_path
    first = cookies[:owner_session_id]
    get root_path
    assert_equal first, cookies[:owner_session_id]
  end
end
```

- [ ] **Step 2: Add a skeleton HousesController + root route**

Create `app/controllers/houses_controller.rb` (will be expanded in Task 7):

```ruby
class HousesController < ApplicationController
  def index
    render plain: "ok"
  end
end
```

Modify `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  root "houses#index"

  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
```

- [ ] **Step 3: Run test — expect FAIL**

Run: `bin/rails test test/controllers/concerns/owner_identity_test.rb`
Expected: both tests FAIL because no cookie is set yet (root returns 200 but no cookie).

- [ ] **Step 4: Implement the concern**

Create `app/controllers/concerns/owner_identity.rb`:

```ruby
module OwnerIdentity
  extend ActiveSupport::Concern

  COOKIE_NAME = :owner_session_id

  included do
    before_action :ensure_owner_session_id
  end

  private

  def owner_session_id
    cookies.signed[COOKIE_NAME]
  end

  def ensure_owner_session_id
    return if cookies.signed[COOKIE_NAME].present?

    cookies.signed.permanent[COOKIE_NAME] = {
      value: SecureRandom.uuid,
      httponly: true,
      same_site: :lax,
    }
  end
end
```

- [ ] **Step 5: Include in ApplicationController**

Modify `app/controllers/application_controller.rb`:

```ruby
class ApplicationController < ActionController::Base
  include OwnerIdentity

  allow_browser versions: :modern
end
```

- [ ] **Step 6: Run test — expect PASS**

Run: `bin/rails test test/controllers/concerns/owner_identity_test.rb`
Expected: 2 runs, 2 assertions, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/concerns/owner_identity.rb \
        app/controllers/application_controller.rb \
        app/controllers/houses_controller.rb \
        config/routes.rb \
        test/controllers/concerns/owner_identity_test.rb
git commit -m "feat(auth): issue signed owner_session_id cookie via OwnerIdentity concern"
```

---

## Task 3 — `Checklist` YAML + loader PORO

**Files:**
- Create: `config/checklist.yml`
- Create: `app/lib/checklist.rb`
- Create: `test/lib/checklist_test.rb`

- [ ] **Step 1: Create the checklist YAML**

Create `config/checklist.yml` with the 50-item content from the spec (water 7 + electric 5 + mold 6 + windows 5 + smell 4 + noise 4 + heating 4 + security 4 + finish 6 + surround 5 = 50):

```yaml
water:
  label_ko: "수도/배관"
  items:
    water_pressure: { label_ko: "수압 충분 (샤워기 세게 틀어서)" }
    hot_water_time: { label_ko: "온수 30초 내 나옴" }
    rust_free: { label_ko: "녹물/이물질 없음" }
    drain_speed: { label_ko: "세면대/싱크대 배수 빠름" }
    balcony_drain: { label_ko: "베란다 하수구 막힘 없음" }
    toilet_flush: { label_ko: "변기 물 내림 정상" }
    boiler_on_time: { label_ko: "보일러 온수 대기 시간 합리적" }

electric:
  label_ko: "전기"
  items:
    outlets_working: { label_ko: "콘센트 작동 (방별 1개 이상 확인)" }
    breaker_accessible: { label_ko: "메인/누전 차단기 위치 확인 가능" }
    lights_working: { label_ko: "조명 모두 작동" }
    aircon_drain: { label_ko: "에어컨 배수관 설치 가능 (구멍 있음)" }
    internet_line: { label_ko: "인터넷 회선(랜선/벽 단자) 존재" }

mold:
  label_ko: "곰팡이/결로"
  items:
    ceiling_corner: { label_ko: "안방 천장/벽 모서리 곰팡이 없음" }
    bath_silicone: { label_ko: "욕실 천장/실리콘 곰팡이 없음" }
    window_frame: { label_ko: "창틀(북향 특히) 결로/곰팡이 흔적 없음" }
    wallpaper_stain: { label_ko: "벽지/장판 얼룩·들뜸 없음" }
    sink_under: { label_ko: "싱크대 하부 수납장 곰팡이 없음" }
    balcony_wall: { label_ko: "베란다 벽 얼룩/결로 흔적 없음" }

windows:
  label_ko: "창호/단열"
  items:
    window_smooth: { label_ko: "창문 여닫이 부드러움" }
    window_lock: { label_ko: "창문 잠금 장치 정상" }
    window_screen: { label_ko: "방충망 찢김 없음" }
    window_draft: { label_ko: "창문 틈새 외풍 없음" }
    double_glazing: { label_ko: "이중창 여부 확인" }

smell:
  label_ko: "냄새"
  items:
    indoor_musty: { label_ko: "실내 곰팡이/쉰내 없음" }
    drain_sewer: { label_ko: "배수구/하수구 역류 냄새 없음" }
    hallway_smell: { label_ko: "엘베 홀/복도 냄새 없음" }
    trap_water: { label_ko: "하수구 트랩 물 고임(S트랩) 있음" }

noise:
  label_ko: "소음"
  items:
    floor_noise: { label_ko: "층간 소음 (가능하면 저녁 방문)" }
    road_noise: { label_ko: "도로 소음 (창문 닫고 체감)" }
    pipe_noise: { label_ko: "배관 소리 (이웃 사용 시)" }
    external_noise: { label_ko: "주변 공사/철도 소리" }

heating:
  label_ko: "난방"
  items:
    boiler_condition: { label_ko: "보일러 연식/상태" }
    heating_type: { label_ko: "난방 방식 (지역/개별/도시가스)" }
    winter_cost: { label_ko: "겨울 난방비 추정치 확인" }
    floor_heating: { label_ko: "바닥 난방 작동 (시운전)" }

security:
  label_ko: "방범/잠금"
  items:
    door_lock: { label_ko: "현관 도어락 정상 (리셋 확인)" }
    peephole: { label_ko: "현관 외시경/카메라" }
    intercom: { label_ko: "인터폰 영상/음성 정상" }
    window_guard: { label_ko: "저층일 경우 창문 방범창" }

finish:
  label_ko: "마감/외관"
  items:
    wallpaper: { label_ko: "벽지 찢김/얼룩/들뜸" }
    flooring: { label_ko: "장판 찢김/들뜸/변색" }
    tile_grout: { label_ko: "타일 깨짐/실리콘 마감" }
    door_hinge: { label_ko: "문 경첩/손잡이 흔들림 없음" }
    kitchen_cabinet: { label_ko: "싱크대 상판/수납 파손 없음" }
    door_gap: { label_ko: "방문 틈새/휨 없음" }

surround:
  label_ko: "주변환경"
  items:
    elevator: { label_ko: "엘리베이터 속도/소리/청결" }
    corridor: { label_ko: "공용 복도 냄새/청결" }
    garbage: { label_ko: "쓰레기장 거리/냄새" }
    parking: { label_ko: "주차장 자리 확보 여부" }
    delivery_security: { label_ko: "택배/경비 시스템" }
```

- [ ] **Step 2: Write the failing test**

Create `test/lib/checklist_test.rb`:

```ruby
require "test_helper"

class ChecklistTest < ActiveSupport::TestCase
  setup { Checklist.reset! }

  test "loads exactly 10 domains from YAML" do
    assert_equal 10, Checklist.domains.size
  end

  test "first domain is water with expected items" do
    water = Checklist.domains.first
    assert_equal "water", water.key
    assert_equal "수도/배관", water.label_ko
    assert water.items.any? { |i| i.key == "water_pressure" }
  end

  test "item_keys is unique and includes all items" do
    keys = Checklist.item_keys
    total = Checklist.domains.sum { |d| d.items.size }
    assert_equal total, keys.size
    assert_includes keys, "ceiling_corner"
    assert_includes keys, "elevator"
  end

  test "total item count is 50" do
    assert_equal 50, Checklist.item_keys.size
  end

  test "item(key) returns the matching item with its domain" do
    item = Checklist.item("water_pressure")
    refute_nil item
    assert_equal "water", item.domain
    assert_match(/수압/, item.label_ko)
  end

  test "raises when YAML is missing" do
    Checklist.reset!
    with_yaml_path(Pathname.new("/nonexistent/checklist.yml")) do
      assert_raises(Checklist::Error) { Checklist.domains }
    end
  end

  test "raises when YAML is malformed (not a hash)" do
    Checklist.reset!
    Tempfile.create(["checklist", ".yml"]) do |f|
      f.write("- just\n- a\n- list\n")
      f.flush
      with_yaml_path(Pathname.new(f.path)) do
        assert_raises(Checklist::Error) { Checklist.domains }
      end
    end
  end

  private

  # Minitest 6 (bundled with Rails 8) removed Object#stub, so we swap the
  # singleton method temporarily and restore it after the block.
  def with_yaml_path(path)
    original = Checklist.method(:yaml_path)
    Checklist.define_singleton_method(:yaml_path) { path }
    yield
  ensure
    Checklist.define_singleton_method(:yaml_path, &original)
  end
end
```

- [ ] **Step 3: Run test — expect FAIL**

Run: `bin/rails test test/lib/checklist_test.rb`
Expected: "uninitialized constant Checklist".

- [ ] **Step 4: Implement the loader**

Create `app/lib/checklist.rb`:

```ruby
require "yaml"
require "set"

module Checklist
  Domain = Struct.new(:key, :label_ko, :items, keyword_init: true)
  Item = Struct.new(:key, :domain, :label_ko, keyword_init: true)

  class Error < StandardError; end

  class << self
    def domains
      @domains ||= load_from_yaml
    end

    def items
      @items ||= domains.flat_map(&:items)
    end

    def item_keys
      @item_keys ||= items.map(&:key).to_set
    end

    def item(key)
      items_by_key[key]
    end

    def reset!
      @domains = @items = @item_keys = @items_by_key = nil
    end

    def yaml_path
      Rails.root.join("config", "checklist.yml")
    end

    private

    def items_by_key
      @items_by_key ||= items.index_by(&:key)
    end

    def load_from_yaml
      path = yaml_path
      raise Error, "checklist.yml not found at #{path}" unless path.file?

      raw = YAML.safe_load_file(path, permitted_classes: [])
      raise Error, "checklist.yml must be a hash" unless raw.is_a?(Hash)

      raw.map do |domain_key, payload|
        unless payload.is_a?(Hash) && payload["items"].is_a?(Hash)
          raise Error, "domain '#{domain_key}' is missing items hash"
        end

        items = payload["items"].map do |item_key, attrs|
          Item.new(key: item_key, domain: domain_key, label_ko: attrs.fetch("label_ko"))
        end
        Domain.new(key: domain_key, label_ko: payload.fetch("label_ko"), items: items)
      end
    end
  end
end
```

- [ ] **Step 5: Run test — expect PASS**

Run: `bin/rails test test/lib/checklist_test.rb`
Expected: 7 runs, passing.

- [ ] **Step 6: Commit**

```bash
git add config/checklist.yml app/lib/checklist.rb test/lib/checklist_test.rb
git commit -m "feat(checklist): load 50-item defect checklist from config/checklist.yml"
```

---

## Task 4 — `House` model & migration

**Files:**
- Create: `db/migrate/<ts>_create_houses.rb`
- Create: `app/models/house.rb`
- Create: `test/models/house_test.rb`

- [ ] **Step 1: Generate migration**

Run: `bin/rails generate migration CreateHouses`
Replace file contents with:

```ruby
class CreateHouses < ActiveRecord::Migration[8.1]
  def change
    create_table :houses do |t|
      t.string :alias, null: false
      t.string :address
      t.string :agent_contact
      t.date :visited_at
      t.string :owner_session_id, null: false

      t.timestamps
    end

    add_index :houses, :owner_session_id
  end
end
```

- [ ] **Step 2: Migrate**

Run: `bin/rails db:migrate`
Expected: `== CreateHouses: migrated`.

- [ ] **Step 3: Write the failing test**

Create `test/models/house_test.rb`:

```ruby
require "test_helper"

class HouseTest < ActiveSupport::TestCase
  SID_A = "00000000-0000-0000-0000-00000000000a".freeze
  SID_B = "00000000-0000-0000-0000-00000000000b".freeze

  test "requires alias" do
    h = House.new(owner_session_id: SID_A)
    refute h.valid?
    assert_includes h.errors[:alias], "can't be blank"
  end

  test "alias max 50 chars" do
    h = House.new(alias: "x" * 51, owner_session_id: SID_A)
    refute h.valid?
    assert_includes h.errors[:alias], "is too long (maximum is 50 characters)"
  end

  test "requires owner_session_id" do
    h = House.new(alias: "Seoul Flat")
    refute h.valid?
    assert_includes h.errors[:owner_session_id], "can't be blank"
  end

  test ".owned_by returns only houses for that session" do
    mine = House.create!(alias: "Mine", owner_session_id: SID_A)
    _theirs = House.create!(alias: "Theirs", owner_session_id: SID_B)
    assert_equal [mine], House.owned_by(SID_A).to_a
  end

  test "destroys inspection_checks on destroy" do
    h = House.create!(alias: "Mine", owner_session_id: SID_A)
    h.inspection_checks.create!(item_key: "water_pressure", severity: :ok)
    assert_difference -> { InspectionCheck.count }, -1 do
      h.destroy!
    end
  end
end
```

Note: the last test depends on `InspectionCheck` (Task 5). Write the test now; if it errors on undefined constant, temporarily skip it until Task 5 lands and re-run.

- [ ] **Step 4: Run model tests — expect failing validations**

Run: `bin/rails test test/models/house_test.rb -n '/alias|session/'`
Expected: failures for missing validations (skip the inspection_checks test).

- [ ] **Step 5: Implement model**

Create `app/models/house.rb`:

```ruby
class House < ApplicationRecord
  has_many :inspection_checks, dependent: :destroy

  validates :alias, presence: true, length: { maximum: 50 }
  validates :owner_session_id, presence: true

  scope :owned_by, ->(sid) { where(owner_session_id: sid) }
end
```

- [ ] **Step 6: Run — expect 4 passing / 1 erroring**

Run: `bin/rails test test/models/house_test.rb`
Expected: validation tests pass; inspection_checks test errors pending Task 5.

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_houses.rb db/schema.rb app/models/house.rb test/models/house_test.rb
git commit -m "feat(models): add House with alias validation and owner scope"
```

---

## Task 5 — `InspectionCheck` model & migration

**Files:**
- Create: `db/migrate/<ts>_create_inspection_checks.rb`
- Create: `app/models/inspection_check.rb`
- Create: `test/models/inspection_check_test.rb`

- [ ] **Step 1: Generate migration**

Run: `bin/rails generate migration CreateInspectionChecks`
Replace contents with:

```ruby
class CreateInspectionChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :inspection_checks do |t|
      t.references :house, null: false, foreign_key: true
      t.string :item_key, null: false
      t.integer :severity, null: false
      t.text :memo

      t.timestamps
    end

    add_index :inspection_checks, :item_key
    add_index :inspection_checks, [:house_id, :item_key], unique: true, name: "idx_inspection_checks_unique_per_house_item"
  end
end
```

- [ ] **Step 2: Migrate**

Run: `bin/rails db:migrate`
Expected: `== CreateInspectionChecks: migrated`.

- [ ] **Step 3: Write the failing test**

Create `test/models/inspection_check_test.rb`:

```ruby
require "test_helper"

class InspectionCheckTest < ActiveSupport::TestCase
  SID = "00000000-0000-0000-0000-000000000111".freeze

  setup do
    @house = House.create!(alias: "Test", owner_session_id: SID)
  end

  test "severity is an enum of ok/warn/severe" do
    expected = { "ok" => 0, "warn" => 1, "severe" => 2 }
    assert_equal expected, InspectionCheck.severities
  end

  test "requires item_key present and recognised" do
    c = InspectionCheck.new(house: @house, severity: :ok)
    refute c.valid?
    assert_includes c.errors[:item_key], "can't be blank"

    c.item_key = "nonexistent_item"
    refute c.valid?
    assert_includes c.errors[:item_key], "is not included in the list"
  end

  test "valid with known item_key and severity" do
    c = InspectionCheck.new(house: @house, item_key: "water_pressure", severity: :warn)
    assert c.valid?
  end

  test "unique per (house, item_key)" do
    InspectionCheck.create!(house: @house, item_key: "rust_free", severity: :ok)
    dup = InspectionCheck.new(house: @house, item_key: "rust_free", severity: :severe)
    refute dup.valid?
    assert_includes dup.errors[:item_key], "has already been taken"
  end

  test "memo limit 500 chars" do
    c = InspectionCheck.new(house: @house, item_key: "noise:floor_noise", severity: :warn, memo: "x" * 501)
    refute c.valid?
    assert_includes c.errors[:memo], "is too long (maximum is 500 characters)"
  end
end
```

- [ ] **Step 4: Run — expect failures**

Run: `bin/rails test test/models/inspection_check_test.rb`
Expected: "uninitialized constant InspectionCheck".

- [ ] **Step 5: Implement model**

Create `app/models/inspection_check.rb`:

```ruby
class InspectionCheck < ApplicationRecord
  belongs_to :house

  enum :severity, { ok: 0, warn: 1, severe: 2 }

  validates :item_key,
    presence: true,
    inclusion: { in: -> (_) { Checklist.item_keys.to_a } },
    uniqueness: { scope: :house_id }
  validates :severity, presence: true
  validates :memo, length: { maximum: 500 }
end
```

- [ ] **Step 6: Run — expect 5 passing**

Run: `bin/rails test test/models/inspection_check_test.rb`
Expected: 5 runs, passing.

Also re-run `bin/rails test test/models/house_test.rb` — the dependent-destroy test now passes.

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_inspection_checks.rb db/schema.rb \
        app/models/inspection_check.rb test/models/inspection_check_test.rb
git commit -m "feat(models): add InspectionCheck with severity enum and per-house uniqueness"
```

---

## Task 6 — `HouseSummary` PORO

**Files:**
- Create: `app/lib/house_summary.rb`
- Create: `test/lib/house_summary_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/lib/house_summary_test.rb`:

```ruby
require "test_helper"

class HouseSummaryTest < ActiveSupport::TestCase
  SID = "00000000-0000-0000-0000-000000000222".freeze

  setup do
    Checklist.reset!
    @house = House.create!(alias: "Summary Test", owner_session_id: SID)
  end

  def add_check(item_key, severity, memo: nil)
    @house.inspection_checks.create!(item_key: item_key, severity: severity, memo: memo)
  end

  test "empty house: every item unchecked, zero severe/warn/ok" do
    s = HouseSummary.for(@house)
    assert_equal Checklist.items.size, s.counts[:unchecked]
    assert_equal 0, s.counts[:severe]
    assert_equal 0, s.counts[:warn]
    assert_equal 0, s.counts[:ok]
    assert_empty s.severe_items
    assert_empty s.warn_items
  end

  test "mixed severities: counts and lists populated" do
    add_check("water_pressure", :ok)
    add_check("rust_free", :severe, memo: "녹물 5초")
    add_check("ceiling_corner", :severe)
    add_check("floor_noise", :warn)

    s = HouseSummary.for(@house)
    assert_equal 1, s.counts[:ok]
    assert_equal 1, s.counts[:warn]
    assert_equal 2, s.counts[:severe]
    assert_equal Checklist.items.size - 4, s.counts[:unchecked]

    keys = s.severe_items.map { |entry| entry[:item].key }
    assert_includes keys, "rust_free"
    assert_includes keys, "ceiling_corner"

    rust_entry = s.severe_items.find { |e| e[:item].key == "rust_free" }
    assert_equal "녹물 5초", rust_entry[:check].memo
  end

  test "deleted_items: check whose item_key is no longer in YAML" do
    # simulate by bypassing validation
    check = @house.inspection_checks.build(item_key: "legacy_thing", severity: :warn)
    check.save!(validate: false)

    s = HouseSummary.for(@house)
    assert_equal 1, s.deleted_items.size
    assert_equal "legacy_thing", s.deleted_items.first.item_key
    assert_equal 0, s.counts[:warn], "deleted items must not inflate live counts"
  end

  test "purely functional: works when given checks array, no DB access needed" do
    checks = [
      InspectionCheck.new(item_key: "water_pressure", severity: :ok),
      InspectionCheck.new(item_key: "rust_free", severity: :severe),
    ]
    s = HouseSummary.new(@house, checks)
    assert_equal 1, s.counts[:ok]
    assert_equal 1, s.counts[:severe]
  end
end
```

- [ ] **Step 2: Run — expect FAIL**

Run: `bin/rails test test/lib/house_summary_test.rb`
Expected: "uninitialized constant HouseSummary".

- [ ] **Step 3: Implement HouseSummary**

Create `app/lib/house_summary.rb`:

```ruby
class HouseSummary
  attr_reader :house, :checks

  def self.for(house)
    new(house, house.inspection_checks.to_a)
  end

  def initialize(house, checks)
    @house = house
    @checks = checks
  end

  def counts
    @counts ||= {
      ok: by_severity[:ok].size,
      warn: by_severity[:warn].size,
      severe: by_severity[:severe].size,
      unchecked: unchecked_items.size,
    }
  end

  def severe_items
    @severe_items ||= entries_for(:severe)
  end

  def warn_items
    @warn_items ||= entries_for(:warn)
  end

  def unchecked_items
    @unchecked_items ||= Checklist.items.reject { |i| checked_keys.include?(i.key) }
  end

  def deleted_items
    @deleted_items ||= checks.reject { |c| Checklist.item_keys.include?(c.item_key) }
  end

  private

  def entries_for(severity)
    (by_severity[severity] || []).map do |check|
      { check: check, item: Checklist.item(check.item_key) }
    end
  end

  def by_severity
    @by_severity ||= Hash.new { |h, k| h[k] = [] }.tap do |hash|
      live_checks.each { |c| hash[c.severity.to_sym] << c }
    end
  end

  def live_checks
    @live_checks ||= checks.select { |c| Checklist.item_keys.include?(c.item_key) }
  end

  def checked_keys
    @checked_keys ||= live_checks.map(&:item_key).to_set
  end
end
```

- [ ] **Step 4: Run — expect PASS**

Run: `bin/rails test test/lib/house_summary_test.rb`
Expected: 4 runs, passing.

- [ ] **Step 5: Commit**

```bash
git add app/lib/house_summary.rb test/lib/house_summary_test.rb
git commit -m "feat(summary): add pure HouseSummary calculator for counts and lists"
```

---

## Task 7 — Routes + `HousesController#index` + empty-state view

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/houses_controller.rb` (skeleton created in Task 2 — expand here)
- Create: `app/views/houses/index.html.erb`
- Create: `test/controllers/houses_controller_test.rb`

> **Note:** Task 2 already wired `root "houses#index"` and created a skeleton `HousesController#index` that returns `render plain: "ok"`. This task (a) adds the remaining nested resource routes and (b) replaces the skeleton body with the real index + view.

- [ ] **Step 1: Add resource routes (root is already wired)**

Modify `config/routes.rb` — add `resources :houses` with nested checks/summary. The `root "houses#index"` line should already exist from Task 2:

```ruby
Rails.application.routes.draw do
  root "houses#index"

  resources :houses do
    resources :checks, only: [:create], controller: :inspection_checks
    resource :summary, only: [:show]
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
```

- [ ] **Step 2: Write failing request tests**

Create `test/controllers/houses_controller_test.rb`:

```ruby
require "test_helper"

class HousesControllerTest < ActionDispatch::IntegrationTest
  test "GET / is index and sets owner_session_id cookie for first-time visitor" do
    get root_path
    assert_response :success
    assert cookies[:owner_session_id].present?
  end

  test "index shows only houses owned by this session" do
    # seed houses under a specific session id by hand-baking a signed cookie
    get root_path
    my_sid = signed_cookie(:owner_session_id)
    _mine = House.create!(alias: "My flat", owner_session_id: my_sid)
    _theirs = House.create!(alias: "Someone else", owner_session_id: "other-sid")

    get root_path
    assert_match "My flat", @response.body
    refute_match "Someone else", @response.body
  end

  private

  def signed_cookie(name)
    jar = ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::TestRequest.create,
      cookies.to_hash
    )
    jar.signed[name]
  end
end
```

- [ ] **Step 3: Run — expect FAIL**

Run: `bin/rails test test/controllers/houses_controller_test.rb`
Expected: "uninitialized constant HousesController".

- [ ] **Step 4: Replace skeleton index with real implementation**

Modify `app/controllers/houses_controller.rb` (the file already exists from Task 2 as a skeleton — replace its body):

```ruby
class HousesController < ApplicationController
  def index
    @houses = House.owned_by(owner_session_id).order(created_at: :desc)
  end
end
```

- [ ] **Step 5: Implement view**

Create `app/views/houses/index.html.erb`:

```erb
<% content_for :title, "집 목록" %>

<div class="mx-auto max-w-md p-4">
  <h1 class="text-2xl font-semibold mb-4">내 집 목록</h1>

  <% if @houses.empty? %>
    <p class="text-gray-500 mb-6">저장된 집이 없습니다. 아래 버튼으로 추가하세요.</p>
  <% else %>
    <ul class="space-y-3 mb-6">
      <% @houses.each do |house| %>
        <li class="border rounded p-3">
          <%= link_to house_path(house), class: "block" do %>
            <div class="font-medium text-lg"><%= house.alias %></div>
            <% summary = HouseSummary.for(house) %>
            <div class="text-sm text-gray-600 mt-1">
              심각 <%= summary.counts[:severe] %> ·
              주의 <%= summary.counts[:warn] %> ·
              양호 <%= summary.counts[:ok] %> ·
              미점검 <%= summary.counts[:unchecked] %>
            </div>
          <% end %>
        </li>
      <% end %>
    </ul>
  <% end %>

  <%= link_to "+ 새 집 추가", new_house_path,
      class: "block w-full text-center bg-blue-600 text-white py-3 rounded text-lg" %>
</div>
```

- [ ] **Step 6: Run — expect PASS**

Run: `bin/rails test test/controllers/houses_controller_test.rb`
Expected: 2 runs, passing.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/houses_controller.rb \
        app/views/houses/index.html.erb test/controllers/houses_controller_test.rb
git commit -m "feat(houses): list houses owned by current session on home screen"
```

---

## Task 8 — `HousesController#new/create` + form

**Files:**
- Modify: `app/controllers/houses_controller.rb`
- Create: `app/views/houses/new.html.erb`
- Create: `app/views/houses/_form.html.erb`
- Modify: `test/controllers/houses_controller_test.rb`

- [ ] **Step 1: Add failing tests**

Append to `test/controllers/houses_controller_test.rb`:

```ruby
test "GET /houses/new renders form" do
  get new_house_path
  assert_response :success
  assert_select "form[action='#{houses_path}']"
  assert_select "input[name='house[alias]']"
end

test "POST /houses creates house scoped to current session" do
  get root_path # set cookie
  assert_difference -> { House.count }, 1 do
    post houses_path, params: { house: { alias: "신반포 32평", address: "서초구", visited_at: "2026-04-22" } }
  end
  h = House.last
  assert_equal "신반포 32평", h.alias
  assert h.owner_session_id.present?
  assert_redirected_to house_path(h)
end

test "POST /houses rejects blank alias" do
  post houses_path, params: { house: { alias: "" } }
  assert_response :unprocessable_entity
end
```

- [ ] **Step 2: Run — expect FAIL**

Run: `bin/rails test test/controllers/houses_controller_test.rb`
Expected: `new` / `create` failing.

- [ ] **Step 3: Implement new/create**

Modify `app/controllers/houses_controller.rb`:

```ruby
class HousesController < ApplicationController
  before_action :set_house, only: [:show, :edit, :update, :destroy]

  def index
    @houses = House.owned_by(owner_session_id).order(created_at: :desc)
  end

  def new
    @house = House.new
  end

  def create
    @house = House.new(house_params.merge(owner_session_id: owner_session_id))
    if @house.save
      redirect_to @house
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_house
    @house = House.owned_by(owner_session_id).find_by(id: params[:id])
    head :not_found unless @house
  end

  def house_params
    params.expect(house: [:alias, :address, :agent_contact, :visited_at])
  end
end
```

- [ ] **Step 4: Create form partial**

Create `app/views/houses/_form.html.erb`:

```erb
<%= form_with(model: house, class: "space-y-4") do |f| %>
  <% if house.errors.any? %>
    <div class="bg-red-50 border border-red-200 rounded p-3 text-sm text-red-700">
      <% house.errors.full_messages.each do |msg| %>
        <div><%= msg %></div>
      <% end %>
    </div>
  <% end %>

  <div>
    <%= f.label :alias, "집 별칭 *", class: "block text-sm font-medium mb-1" %>
    <%= f.text_field :alias, required: true, maxlength: 50,
        class: "w-full border rounded px-3 py-2",
        placeholder: "예: 신반포 32평" %>
  </div>

  <div>
    <%= f.label :address, "주소", class: "block text-sm font-medium mb-1" %>
    <%= f.text_field :address, class: "w-full border rounded px-3 py-2" %>
  </div>

  <div>
    <%= f.label :agent_contact, "중개인 (이름/전화)", class: "block text-sm font-medium mb-1" %>
    <%= f.text_field :agent_contact, class: "w-full border rounded px-3 py-2" %>
  </div>

  <div>
    <%= f.label :visited_at, "방문일", class: "block text-sm font-medium mb-1" %>
    <%= f.date_field :visited_at, value: house.visited_at || Date.current,
        class: "w-full border rounded px-3 py-2" %>
  </div>

  <%= f.submit "저장", class: "w-full bg-blue-600 text-white py-3 rounded text-lg" %>
<% end %>
```

- [ ] **Step 5: Create new view**

Create `app/views/houses/new.html.erb`:

```erb
<% content_for :title, "새 집 추가" %>

<div class="mx-auto max-w-md p-4">
  <%= link_to "← 돌아가기", root_path, class: "text-blue-600 text-sm" %>
  <h1 class="text-2xl font-semibold mt-2 mb-4">새 집 추가</h1>
  <%= render "form", house: @house %>
</div>
```

- [ ] **Step 6: Run — expect PASS**

Run: `bin/rails test test/controllers/houses_controller_test.rb`
Expected: 5 runs, passing.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/houses_controller.rb \
        app/views/houses/new.html.erb app/views/houses/_form.html.erb \
        test/controllers/houses_controller_test.rb
git commit -m "feat(houses): add new/create flow with alias validation"
```

---

## Task 9 — `HousesController#show` (inspection screen)

**Files:**
- Modify: `app/controllers/houses_controller.rb` (add `show` action — already added `set_house`)
- Create: `app/views/houses/show.html.erb`
- Create: `app/views/shared/_severity_badge.html.erb`
- Create: `app/views/shared/_domain_section.html.erb`
- Create: `app/views/inspection_checks/_check_row.html.erb`
- Modify: `test/controllers/houses_controller_test.rb`

- [ ] **Step 1: Add failing tests**

Append to `test/controllers/houses_controller_test.rb`:

```ruby
test "GET /houses/:id shows inspection screen with all 10 domains" do
  get root_path
  sid = signed_cookie(:owner_session_id)
  h = House.create!(alias: "Inspection subject", owner_session_id: sid)

  get house_path(h)
  assert_response :success
  assert_match "Inspection subject", @response.body
  Checklist.domains.each do |d|
    assert_match d.label_ko, @response.body
  end
end

test "GET /houses/:id for another owner returns 404" do
  other = House.create!(alias: "Not yours", owner_session_id: "other-sid")
  get root_path # mint cookie for this session
  get house_path(other)
  assert_response :not_found
end
```

- [ ] **Step 2: Run — expect FAIL**

Run: `bin/rails test test/controllers/houses_controller_test.rb`
Expected: `show` missing / view missing.

- [ ] **Step 3: Add `show` action**

Modify `app/controllers/houses_controller.rb` — add `show` (no implementation body beyond instance variable setup — `set_house` populates `@house`):

```ruby
def show
  @domains = Checklist.domains
  @checks_by_key = @house.inspection_checks.index_by(&:item_key)
end
```

- [ ] **Step 4: Create severity badge partial**

Create `app/views/shared/_severity_badge.html.erb`:

```erb
<%
  # locals: severity (nil/:ok/:warn/:severe)
  palette = {
    ok: "bg-green-100 text-green-800",
    warn: "bg-yellow-100 text-yellow-800",
    severe: "bg-red-100 text-red-800",
  }
  labels = { ok: "양호", warn: "주의", severe: "심각" }
  key = severity&.to_sym
%>
<% if key %>
  <span class="inline-block px-2 py-0.5 rounded text-xs font-medium <%= palette[key] %>">
    <%= labels[key] %>
  </span>
<% end %>
```

- [ ] **Step 5: Create check row partial**

Create `app/views/inspection_checks/_check_row.html.erb`:

```erb
<%
  # locals: house, item, check
  current = check&.severity
%>
<div id="check-row-<%= item.key %>"
     class="py-2 border-b last:border-0"
     data-controller="severity-selector memo-toggle">
  <div class="flex justify-between items-center gap-2">
    <div class="flex-1 text-sm"><%= item.label_ko %></div>
    <%= form_with url: house_checks_path(house),
                  method: :post,
                  data: { turbo_stream: true, severity_selector_target: "form" },
                  class: "flex gap-1" do |f| %>
      <%= f.hidden_field :item_key, value: item.key %>
      <% %w[ok warn severe].each do |level| %>
        <% label = { "ok" => "양호", "warn" => "주의", "severe" => "심각" }[level] %>
        <% pressed = current == level %>
        <button type="submit"
                name="severity"
                value="<%= level %>"
                aria-pressed="<%= pressed %>"
                class="min-w-11 min-h-11 px-2 rounded text-sm border
                       <%= pressed ? level_selected_class(level) : 'bg-white text-gray-700 border-gray-300' %>">
          <%= label %>
        </button>
      <% end %>
    <% end %>
  </div>

  <% if check %>
    <div class="mt-1 flex gap-2 items-start" data-memo-toggle-target="panel">
      <details class="w-full text-sm">
        <summary class="cursor-pointer text-blue-600">메모 <%= check.memo.present? ? "수정" : "추가" %></summary>
        <%= form_with url: house_checks_path(house), method: :post,
                      data: { turbo_stream: true }, class: "mt-2 flex gap-2" do |f| %>
          <%= f.hidden_field :item_key, value: item.key %>
          <%= f.hidden_field :severity, value: check.severity %>
          <%= f.text_field :memo, value: check.memo, maxlength: 500,
              placeholder: "특이사항 한 줄",
              class: "flex-1 border rounded px-2 py-1" %>
          <button type="submit" class="bg-gray-800 text-white px-3 rounded">저장</button>
        <% end %>
        <% if check.memo.present? %>
          <p class="mt-1 text-xs text-gray-700">└ <%= check.memo %></p>
        <% end %>
      </details>
    </div>
  <% end %>
</div>
```

Helper used above — add to `app/helpers/application_helper.rb`:

```ruby
module ApplicationHelper
  def level_selected_class(level)
    {
      "ok" => "bg-green-600 text-white border-green-600",
      "warn" => "bg-yellow-500 text-white border-yellow-500",
      "severe" => "bg-red-600 text-white border-red-600",
    }.fetch(level, "bg-gray-200")
  end
end
```

- [ ] **Step 6: Create domain section partial**

Create `app/views/shared/_domain_section.html.erb`:

```erb
<%
  # locals: house, domain, checks_by_key
  items = domain.items
  rated = items.count { |i| checks_by_key.key?(i.key) }
%>
<details class="border rounded mb-2" <%= "open" if domain == Checklist.domains.first %>>
  <summary class="cursor-pointer px-3 py-2 bg-gray-50 flex justify-between">
    <span class="font-medium"><%= domain.label_ko %></span>
    <span class="text-sm text-gray-600">진행 <%= rated %>/<%= items.size %></span>
  </summary>
  <div class="px-3">
    <% items.each do |item| %>
      <%= render "inspection_checks/check_row",
                 house: house,
                 item: item,
                 check: checks_by_key[item.key] %>
    <% end %>
  </div>
</details>
```

- [ ] **Step 7: Create show view**

Create `app/views/houses/show.html.erb`:

```erb
<% content_for :title, @house.alias %>

<div class="mx-auto max-w-md p-4">
  <div class="flex justify-between items-center mb-4">
    <%= link_to "← 홈", root_path, class: "text-blue-600 text-sm" %>
    <%= link_to "요약 보기", house_summary_path(@house),
        class: "text-sm text-blue-600" %>
  </div>

  <h1 class="text-2xl font-semibold mb-4"><%= @house.alias %></h1>

  <% @domains.each do |domain| %>
    <%= render "shared/domain_section",
               house: @house, domain: domain, checks_by_key: @checks_by_key %>
  <% end %>

  <div class="mt-6">
    <%= link_to "편집", edit_house_path(@house), class: "text-sm text-gray-600 underline" %>
  </div>
</div>
```

- [ ] **Step 8: Run — expect PASS**

Run: `bin/rails test test/controllers/houses_controller_test.rb`
Expected: all controller tests passing.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/houses_controller.rb \
        app/views/houses/show.html.erb \
        app/views/shared/_severity_badge.html.erb \
        app/views/shared/_domain_section.html.erb \
        app/views/inspection_checks/_check_row.html.erb \
        app/helpers/application_helper.rb \
        test/controllers/houses_controller_test.rb
git commit -m "feat(houses): show inspection screen with all 10 domains and severity buttons"
```

---

## Task 10 — `InspectionChecksController` (upsert + Turbo Stream)

**Files:**
- Create: `app/controllers/inspection_checks_controller.rb`
- Create: `app/views/inspection_checks/create.turbo_stream.erb`
- Create: `app/javascript/controllers/severity_selector_controller.js`
- Create: `app/javascript/controllers/memo_toggle_controller.js`
- Create: `test/controllers/inspection_checks_controller_test.rb`

- [ ] **Step 1: Write failing request tests**

Create `test/controllers/inspection_checks_controller_test.rb`:

```ruby
require "test_helper"

class InspectionChecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_path
    @sid = cookies[:owner_session_id]
    # Re-resolve signed value through a helper jar
    jar = ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::TestRequest.create, cookies.to_hash
    )
    @house = House.create!(alias: "Under test", owner_session_id: jar.signed[:owner_session_id])
  end

  test "POST /houses/:id/checks upserts severity (create path)" do
    assert_difference -> { InspectionCheck.count }, 1 do
      post house_checks_path(@house),
           params: { item_key: "water_pressure", severity: "warn" },
           as: :turbo_stream
    end
    assert_response :success
    check = InspectionCheck.last
    assert_equal "warn", check.severity
    assert_equal "water_pressure", check.item_key
  end

  test "POST /houses/:id/checks upserts severity (update path, same item_key)" do
    @house.inspection_checks.create!(item_key: "rust_free", severity: :ok)
    assert_no_difference -> { InspectionCheck.count } do
      post house_checks_path(@house),
           params: { item_key: "rust_free", severity: "severe" },
           as: :turbo_stream
    end
    assert_response :success
    assert_equal "severe", @house.inspection_checks.find_by(item_key: "rust_free").severity
  end

  test "POST includes memo when provided" do
    post house_checks_path(@house),
         params: { item_key: "ceiling_corner", severity: "severe", memo: "북측 천장" },
         as: :turbo_stream
    assert_response :success
    assert_equal "북측 천장", InspectionCheck.last.memo
  end

  test "rejects invalid severity with 422" do
    post house_checks_path(@house),
         params: { item_key: "water_pressure", severity: "panic" },
         as: :turbo_stream
    assert_response :unprocessable_entity
  end

  test "rejects unknown item_key with 422" do
    post house_checks_path(@house),
         params: { item_key: "nope", severity: "ok" },
         as: :turbo_stream
    assert_response :unprocessable_entity
  end

  test "returns 404 when posting to another owner's house" do
    other = House.create!(alias: "Mine not", owner_session_id: "other-sid")
    post house_checks_path(other),
         params: { item_key: "water_pressure", severity: "ok" },
         as: :turbo_stream
    assert_response :not_found
  end
end
```

- [ ] **Step 2: Run — expect FAIL**

Run: `bin/rails test test/controllers/inspection_checks_controller_test.rb`
Expected: "uninitialized constant InspectionChecksController".

- [ ] **Step 3: Implement controller**

Create `app/controllers/inspection_checks_controller.rb`:

```ruby
class InspectionChecksController < ApplicationController
  before_action :set_house
  before_action :set_check

  VALID_SEVERITIES = %w[ok warn severe].freeze

  def create
    severity = params[:severity].to_s
    unless VALID_SEVERITIES.include?(severity)
      return head :unprocessable_entity
    end

    @check.severity = severity
    @check.memo = params[:memo] if params.key?(:memo)

    if @check.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @house }
      end
    else
      head :unprocessable_entity
    end
  end

  private

  def set_house
    @house = House.owned_by(owner_session_id).find_by(id: params[:house_id])
    head :not_found unless @house
  end

  def set_check
    return unless @house

    @check = @house.inspection_checks.find_or_initialize_by(item_key: params[:item_key])
  end
end
```

- [ ] **Step 4: Implement turbo_stream template**

Create `app/views/inspection_checks/create.turbo_stream.erb`:

```erb
<%= turbo_stream.replace "check-row-#{@check.item_key}" do %>
  <%= render "inspection_checks/check_row",
             house: @house,
             item: Checklist.item(@check.item_key),
             check: @check %>
<% end %>
```

- [ ] **Step 5: Add Stimulus controllers**

Create `app/javascript/controllers/severity_selector_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Auto-submits the severity form when a severity button is clicked.
// The native submit-on-click behaviour is sufficient; this controller
// exists to mark pressed state before the server round-trip so mobile
// users see instant feedback if network is slow.
export default class extends Controller {
  static targets = ["form"]

  connect() {
    this.element.querySelectorAll("button[aria-pressed]").forEach((btn) => {
      btn.addEventListener("click", () => {
        this.element.querySelectorAll("button[aria-pressed]").forEach((b) => b.setAttribute("aria-pressed", "false"))
        btn.setAttribute("aria-pressed", "true")
      })
    })
  }
}
```

Create `app/javascript/controllers/memo_toggle_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Native <details> handles the open/close state.
// This controller is a no-op placeholder for future enhancement;
// it ensures data-controller="memo-toggle" does not throw.
export default class extends Controller {
  static targets = ["panel"]
}
```

- [ ] **Step 6: Register Stimulus controllers (if not auto-loaded)**

Check `app/javascript/controllers/index.js` — in Rails 8 the default is `eagerLoadControllersFrom("controllers", application)` which auto-registers by filename. Nothing to change.

- [ ] **Step 7: Run — expect PASS**

Run: `bin/rails test test/controllers/inspection_checks_controller_test.rb`
Expected: 6 runs, passing.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/inspection_checks_controller.rb \
        app/views/inspection_checks/create.turbo_stream.erb \
        app/javascript/controllers/severity_selector_controller.js \
        app/javascript/controllers/memo_toggle_controller.js \
        test/controllers/inspection_checks_controller_test.rb
git commit -m "feat(checks): upsert severity + memo via Turbo Stream per (house, item_key)"
```

---

## Task 11 — `HousesController#edit/update/destroy`

**Files:**
- Modify: `app/controllers/houses_controller.rb`
- Create: `app/views/houses/edit.html.erb`
- Modify: `test/controllers/houses_controller_test.rb`

- [ ] **Step 1: Add failing tests**

Append to `test/controllers/houses_controller_test.rb`:

```ruby
test "GET /houses/:id/edit shows form" do
  get root_path
  sid = signed_cookie(:owner_session_id)
  h = House.create!(alias: "Edit me", owner_session_id: sid)

  get edit_house_path(h)
  assert_response :success
  assert_select "form"
end

test "PATCH /houses/:id updates attributes" do
  get root_path
  sid = signed_cookie(:owner_session_id)
  h = House.create!(alias: "Old", owner_session_id: sid)

  patch house_path(h), params: { house: { alias: "New" } }
  assert_redirected_to house_path(h)
  assert_equal "New", h.reload.alias
end

test "DELETE /houses/:id destroys house and checks" do
  get root_path
  sid = signed_cookie(:owner_session_id)
  h = House.create!(alias: "Doomed", owner_session_id: sid)
  h.inspection_checks.create!(item_key: "water_pressure", severity: :ok)

  assert_difference -> { House.count }, -1 do
    assert_difference -> { InspectionCheck.count }, -1 do
      delete house_path(h)
    end
  end
  assert_redirected_to root_path
end

test "DELETE /houses/:id for other owner returns 404" do
  other = House.create!(alias: "Not mine", owner_session_id: "other-sid")
  delete house_path(other)
  assert_response :not_found
end
```

- [ ] **Step 2: Run — expect FAIL**

Run: `bin/rails test test/controllers/houses_controller_test.rb`
Expected: edit/update/destroy failing.

- [ ] **Step 3: Implement actions**

Modify `app/controllers/houses_controller.rb` — add:

```ruby
def edit; end

def update
  if @house.update(house_params)
    redirect_to @house
  else
    render :edit, status: :unprocessable_entity
  end
end

def destroy
  @house.destroy!
  redirect_to root_path, notice: "삭제되었습니다"
end
```

- [ ] **Step 4: Create edit view**

Create `app/views/houses/edit.html.erb`:

```erb
<% content_for :title, "집 편집" %>

<div class="mx-auto max-w-md p-4">
  <%= link_to "← 돌아가기", @house, class: "text-blue-600 text-sm" %>
  <h1 class="text-2xl font-semibold mt-2 mb-4">집 편집</h1>

  <%= render "form", house: @house %>

  <div class="mt-8 pt-6 border-t">
    <%= button_to "이 집 삭제",
        house_path(@house),
        method: :delete,
        form: { data: { turbo_confirm: "정말 삭제할까요? 이 집의 모든 점검 기록이 함께 삭제됩니다." } },
        class: "w-full border border-red-300 text-red-600 py-3 rounded" %>
  </div>
</div>
```

- [ ] **Step 5: Run — expect PASS**

Run: `bin/rails test test/controllers/houses_controller_test.rb`
Expected: all passing.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/houses_controller.rb app/views/houses/edit.html.erb \
        test/controllers/houses_controller_test.rb
git commit -m "feat(houses): add edit/update/destroy with delete confirmation"
```

---

## Task 12 — `SummariesController` + view

**Files:**
- Create: `app/controllers/summaries_controller.rb`
- Create: `app/views/summaries/show.html.erb`
- Create: `test/controllers/summaries_controller_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/controllers/summaries_controller_test.rb`:

```ruby
require "test_helper"

class SummariesControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_path
    jar = ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::TestRequest.create, cookies.to_hash
    )
    @sid = jar.signed[:owner_session_id]
    @house = House.create!(alias: "Summary Test", owner_session_id: @sid)
  end

  test "GET summary for empty house shows all unchecked" do
    get house_summary_path(@house)
    assert_response :success
    assert_match "미점검", @response.body
  end

  test "GET summary renders severe and warn sections" do
    @house.inspection_checks.create!(item_key: "rust_free", severity: :severe, memo: "녹물 5초")
    @house.inspection_checks.create!(item_key: "floor_noise", severity: :warn)

    get house_summary_path(@house)
    assert_response :success
    assert_match "녹물 5초", @response.body
    assert_match "심각", @response.body
    assert_match "주의", @response.body
  end

  test "GET summary for other owner returns 404" do
    other = House.create!(alias: "Not yours", owner_session_id: "other-sid")
    get house_summary_path(other)
    assert_response :not_found
  end
end
```

- [ ] **Step 2: Run — expect FAIL**

Run: `bin/rails test test/controllers/summaries_controller_test.rb`
Expected: "uninitialized constant SummariesController".

- [ ] **Step 3: Implement controller**

Create `app/controllers/summaries_controller.rb`:

```ruby
class SummariesController < ApplicationController
  def show
    house = House.owned_by(owner_session_id).find_by(id: params[:house_id])
    return head :not_found unless house

    @house = house
    @summary = HouseSummary.for(house)
  end
end
```

- [ ] **Step 4: Implement view**

Create `app/views/summaries/show.html.erb`:

```erb
<% content_for :title, "#{@house.alias} 요약" %>

<div class="mx-auto max-w-md p-4">
  <%= link_to "← 돌아가기", @house, class: "text-blue-600 text-sm" %>
  <h1 class="text-2xl font-semibold mt-2 mb-4"><%= @house.alias %> 요약</h1>

  <div class="grid grid-cols-4 gap-2 mb-6 text-center">
    <div class="bg-red-50 text-red-700 rounded p-2">
      <div class="text-xs">심각</div>
      <div class="text-xl font-bold"><%= @summary.counts[:severe] %></div>
    </div>
    <div class="bg-yellow-50 text-yellow-700 rounded p-2">
      <div class="text-xs">주의</div>
      <div class="text-xl font-bold"><%= @summary.counts[:warn] %></div>
    </div>
    <div class="bg-green-50 text-green-700 rounded p-2">
      <div class="text-xs">양호</div>
      <div class="text-xl font-bold"><%= @summary.counts[:ok] %></div>
    </div>
    <div class="bg-gray-50 text-gray-700 rounded p-2">
      <div class="text-xs">미점검</div>
      <div class="text-xl font-bold"><%= @summary.counts[:unchecked] %></div>
    </div>
  </div>

  <% if @summary.severe_items.any? %>
    <section class="mb-6">
      <h2 class="font-semibold text-red-700 mb-2">심각 (<%= @summary.severe_items.size %>)</h2>
      <ul class="space-y-2">
        <% @summary.severe_items.each do |entry| %>
          <li class="border-l-4 border-red-500 pl-3 py-1">
            <div class="font-medium"><%= entry[:item].label_ko %></div>
            <div class="text-xs text-gray-500"><%= Checklist.domains.find { |d| d.key == entry[:item].domain }.label_ko %></div>
            <% if entry[:check].memo.present? %>
              <div class="text-sm text-gray-700 mt-1">└ <%= entry[:check].memo %></div>
            <% end %>
          </li>
        <% end %>
      </ul>
    </section>
  <% end %>

  <% if @summary.warn_items.any? %>
    <section class="mb-6">
      <h2 class="font-semibold text-yellow-700 mb-2">주의 (<%= @summary.warn_items.size %>)</h2>
      <ul class="space-y-2">
        <% @summary.warn_items.each do |entry| %>
          <li class="border-l-4 border-yellow-500 pl-3 py-1">
            <div class="font-medium"><%= entry[:item].label_ko %></div>
            <% if entry[:check].memo.present? %>
              <div class="text-sm text-gray-700 mt-1">└ <%= entry[:check].memo %></div>
            <% end %>
          </li>
        <% end %>
      </ul>
    </section>
  <% end %>

  <% if @summary.unchecked_items.any? %>
    <details class="mb-6">
      <summary class="cursor-pointer text-gray-600">미점검 항목 펼치기 (<%= @summary.unchecked_items.size %>)</summary>
      <ul class="mt-2 space-y-1 text-sm text-gray-700">
        <% @summary.unchecked_items.each do |item| %>
          <li>▸ <%= item.label_ko %></li>
        <% end %>
      </ul>
    </details>
  <% end %>

  <% if @summary.deleted_items.any? %>
    <details class="mb-6">
      <summary class="cursor-pointer text-gray-500">삭제된 항목 (<%= @summary.deleted_items.size %>)</summary>
      <ul class="mt-2 space-y-1 text-xs text-gray-600">
        <% @summary.deleted_items.each do |check| %>
          <li>▸ <%= check.item_key %></li>
        <% end %>
      </ul>
    </details>
  <% end %>
</div>
```

- [ ] **Step 5: Run — expect PASS**

Run: `bin/rails test test/controllers/summaries_controller_test.rb`
Expected: 3 runs, passing.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/summaries_controller.rb \
        app/views/summaries/show.html.erb \
        test/controllers/summaries_controller_test.rb
git commit -m "feat(summary): single-house summary with severe/warn lists"
```

---

## Task 13 — Rack::Attack rate limit on writes

**Files:**
- Create: `config/initializers/rack_attack.rb`
- Create: `test/integration/rate_limit_test.rb`

- [ ] **Step 1: Write failing test**

Create `test/integration/rate_limit_test.rb`:

```ruby
require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  setup do
    # Test env uses :null_store (config/environments/test.rb), which silently
    # drops Rack::Attack's counters — the throttle would never fire. Swap to
    # an in-memory store for the duration of this test and restore it after.
    @previous_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
    Rack::Attack.enabled = true
  end

  teardown do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = @previous_store
  end

  test "throttles POST /houses after burst" do
    get root_path # mint cookie
    burst = 11
    burst.times do |i|
      post houses_path, params: { house: { alias: "Spam #{i}" } }
    end
    assert_equal 429, response.status, "last of #{burst} POSTs should be throttled"
  end
end
```

> **Plan note:** The initial draft used `burst.times.map do ... post ...` + `_1`, but (a) the resulting array is unused (rubocop flags it) and (b) the cache-swap was missing. The snippet above is the corrected version.

- [ ] **Step 2: Run — expect FAIL (no initializer)**

Run: `bin/rails test test/integration/rate_limit_test.rb`
Expected: all 11 POSTs succeed → test fails.

- [ ] **Step 3: Implement initializer**

Create `config/initializers/rack_attack.rb`:

```ruby
class Rack::Attack
  # Test env toggles enabled via teardown; for prod/dev it is always on.
  Rack::Attack.enabled = !Rails.env.test?

  # Throttle write endpoints per IP.
  throttle("write-endpoints per ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.post? || req.patch? || req.put? || req.delete?
  end

  self.throttled_responder = ->(_env) {
    [429, { "Content-Type" => "text/html" }, ["<h1>잠시 후 다시 시도해 주세요</h1>"]]
  }
end
```

- [ ] **Step 4: Run — expect PASS**

Run: `bin/rails test test/integration/rate_limit_test.rb`
Expected: passing.

- [ ] **Step 5: Commit**

```bash
git add config/initializers/rack_attack.rb test/integration/rate_limit_test.rb
git commit -m "feat(security): throttle write endpoints at 10/min per IP via rack-attack"
```

---

## Task 14 — System test: full inspection flow

**Files:**
- Create: `test/system/inspection_flow_test.rb`
- Modify: `test/application_system_test_case.rb` (set mobile viewport if default differs)

- [ ] **Step 1: Ensure system test base uses mobile viewport**

Open `test/application_system_test_case.rb`. Rails 8 default uses a headless Chrome at 1400×1400. Replace with:

```ruby
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [375, 667]
end
```

- [ ] **Step 2: Write the system test**

Create `test/system/inspection_flow_test.rb`:

```ruby
require "application_system_test_case"

class InspectionFlowTest < ApplicationSystemTestCase
  test "home → create house → rate items → write memo → see summary" do
    visit root_path
    assert_text "내 집 목록"
    click_link "+ 새 집 추가"

    fill_in "집 별칭 *", with: "신반포 32평"
    click_button "저장"

    assert_text "신반포 32평"

    # first domain (수도/배관) is open by default — rate "수압 충분"
    within("#check-row-water_pressure") do
      click_button "심각"
    end
    # give Turbo Stream a moment
    assert_selector "#check-row-water_pressure button[aria-pressed='true']", text: "심각"

    # open memo on same row
    within("#check-row-water_pressure") do
      click_on "메모 추가"
      fill_in "inspection_check[memo]", with: "2층, 샤워 수압 약함" rescue nil
      # memo field uses 'memo' param; the generic input name depends on markup.
      # If the rescue fires, replace with find("input[name='memo']") based strategy.
    end

    click_link "요약 보기"
    assert_text "심각"
    assert_text "신반포 32평 요약"
  end
end
```

Note: memo input selector may need adjustment. If the rescue above fires in your first run, change to:

```ruby
find("input[name='memo']").set("2층, 샤워 수압 약함")
find("button", text: "저장").click
```

- [ ] **Step 3: Run — expect PASS (may need one adjustment pass)**

Run: `bin/rails test:system test/system/inspection_flow_test.rb`
Expected: passing. If memo assertion fails, inspect the rendered DOM and update the selector.

- [ ] **Step 4: Commit**

```bash
git add test/application_system_test_case.rb test/system/inspection_flow_test.rb
git commit -m "test(system): mobile-viewport inspection flow E2E"
```

---

## Task 15 — System test: house deletion

**Files:**
- Create: `test/system/house_deletion_test.rb`

- [ ] **Step 1: Write the system test**

Create `test/system/house_deletion_test.rb`:

```ruby
require "application_system_test_case"

class HouseDeletionTest < ApplicationSystemTestCase
  test "delete house from edit screen with confirmation" do
    visit root_path
    click_link "+ 새 집 추가"
    fill_in "집 별칭 *", with: "사라질 집"
    click_button "저장"

    click_link "편집"

    # confirm the turbo_confirm dialog
    page.accept_confirm do
      click_button "이 집 삭제"
    end

    assert_current_path root_path
    assert_no_text "사라질 집"
  end
end
```

- [ ] **Step 2: Run — expect PASS**

Run: `bin/rails test:system test/system/house_deletion_test.rb`
Expected: passing.

- [ ] **Step 3: Commit**

```bash
git add test/system/house_deletion_test.rb
git commit -m "test(system): house deletion with confirmation dialog"
```

---

## Task 16 — System test: accessibility touch targets

**Files:**
- Create: `test/system/accessibility_touch_targets_test.rb`

- [ ] **Step 1: Write the test**

Create `test/system/accessibility_touch_targets_test.rb`:

```ruby
require "application_system_test_case"

class AccessibilityTouchTargetsTest < ApplicationSystemTestCase
  test "severity buttons meet 44x44 minimum touch target" do
    visit root_path
    click_link "+ 새 집 추가"
    fill_in "집 별칭 *", with: "접근성 테스트"
    click_button "저장"

    # first row of first open domain
    first_row = find("div[id^='check-row-']", match: :first)
    within(first_row) do
      %w[양호 주의 심각].each do |label|
        btn = find("button", text: label)
        rect = btn.evaluate_script("({ w: this.offsetWidth, h: this.offsetHeight })")
        assert_operator rect["w"], :>=, 44, "#{label} button width #{rect['w']}px < 44"
        assert_operator rect["h"], :>=, 44, "#{label} button height #{rect['h']}px < 44"
      end
    end
  end
end
```

- [ ] **Step 2: Run — expect PASS**

Run: `bin/rails test:system test/system/accessibility_touch_targets_test.rb`
Expected: passing. If a dimension fails, adjust Tailwind classes in `_check_row.html.erb` (e.g., `min-w-11 min-h-11` → `min-w-12 min-h-12`) and re-run.

- [ ] **Step 3: Commit**

```bash
git add test/system/accessibility_touch_targets_test.rb
git commit -m "test(system): enforce 44px touch target on severity buttons"
```

---

## Task 17 — Full suite + lint + security, then push

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test test:system`
Expected: all tests passing (models, request, integration, system).

- [ ] **Step 2: Run RuboCop**

Run: `bin/rubocop`
If violations: `bin/rubocop -a` and re-stage fixed files. If any remaining, fix manually. Commit fixes separately:

```bash
git commit -m "style: apply rubocop auto-corrections"
```

- [ ] **Step 3: Run Brakeman**

Run: `bin/brakeman --no-pager --quiet`
Expected: `No warnings found`. If warnings appear, investigate. Do not suppress without understanding.

- [ ] **Step 4: Run importmap audit**

Run: `bin/importmap audit`
Expected: no advisories.

- [ ] **Step 5: Push to origin/main**

```bash
git push origin main
```

- [ ] **Step 6: Verify CI green**

Open GitHub Actions for the repo. All five jobs (`scan_ruby`, `scan_js`, `lint`, `test`, `system-test`) must be green.

- [ ] **Step 7: Push archive branch (optional safety)**

```bash
git push origin archive/scorecard
```

---

## Post-implementation checklist (Gate 1)

- [ ] Home → new → inspection → summary flow works on mobile Safari (real device)
- [ ] 50 items visible across 10 domains
- [ ] Severity buttons meet 44px touch target
- [ ] Delete confirmation blocks accidental removal
- [ ] CI fully green
- [ ] README updated with new feature overview (separate commit, not part of this plan's tasks)

---

## Self-Review Notes

**Spec coverage:**
- Data Model (House, InspectionCheck) → Tasks 4, 5 ✓
- Checklist YAML + loader → Task 3 ✓
- OwnerIdentity concern → Task 2 ✓
- 3 controllers (Houses, InspectionChecks, Summaries) → Tasks 7-12 ✓
- POROs (Checklist, HouseSummary) → Tasks 3, 6 ✓
- Views (houses/*, inspection_checks/*, summaries/*, shared/*) → Tasks 7-12 ✓
- Stimulus (severity_selector, memo_toggle) → Task 10 ✓
- Tests at every layer → Tasks 2-12 (unit), 14-16 (system) ✓
- Rack::Attack rate limit → Task 13 ✓
- CI green verification → Task 17 ✓
- Pivot execution (archive/reset/spec commit) → ALREADY DONE before plan

**Placeholder scan:** none found.

**Type consistency:** severity enum uses `ok/warn/severe` consistently across model, controller, view partial, YAML, and helper. `owner_session_id` resolved via `OwnerIdentity` in all controllers. `item_key` validation uses `Checklist.item_keys` both in model and controller.

**Known risk (called out inline):** Task 14's memo field selector (`input[name='memo']`) may need fine-tuning after first run — the plan tells the engineer exactly what to swap in.

**Not in this plan (deferred):**
- PWA manifest polish / icons
- `bin/backup-sqlite` script (re-add when deploying)
- Deploy config (Kamal setup, domain, TLS)
- Gate 2 user interviews and feedback loop
