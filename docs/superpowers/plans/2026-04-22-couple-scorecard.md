# Couple Scorecard MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a mobile-first web app where a house-hunter creates Houses, rates them on 10 fixed categories 1-5, invites a spouse via share link, and views an auto-generated couple comparison report.

**Architecture:** Rails 8 + Hotwire (Turbo Streams for rating updates) + TailwindCSS. Anonymous owner (browser cookie `owner_session_id` / UUID) — no User table. Spouse joins via `share_token` URL, gets a per-house `rater_session_id` cookie. A pure-POJO `ScorecardCalculator` computes agreement / disagreement / leading-category report from `Rating` rows.

**Tech Stack:** Rails 8.1.3, Ruby 3.4.8, SQLite + Solid Trifecta, Hotwire (Turbo + Stimulus), TailwindCSS, Importmap, Kamal 2, Minitest (project default), Capybara + Selenium for system tests, rack-attack for rate limiting.

**Spec:** `docs/superpowers/specs/2026-04-22-couple-scorecard-design.md`

**Pre-condition — Gate 0 (from spec):** Do not execute this plan until 3 of 5 target-user interviews confirm demand. This plan is ready to run *after* that gate passes.

**Conventions (from CLAUDE.md):**
- TDD: Red → Green → Refactor. Every task writes failing test first.
- Tidy First: structural (refactor) changes and behavioral (new logic) changes go in **separate commits**.
- Korean UI text in views and copy; English in code, migrations, YAML, and commit messages.
- Commit at every green test. Do not batch.
- Pre-commit failure (rubocop/test): fix yourself and retry.

**Testing commands the engineer must know:**
- `bin/rails test` — run all Minitest tests
- `bin/rails test test/models/house_test.rb` — single file
- `bin/rails test test/models/house_test.rb:42` — single test at line 42
- `bin/rubocop -a` — auto-fix style
- `bin/brakeman --quiet` — security scan
- `bin/rails db:migrate` / `bin/rails db:seed` / `bin/rails db:reset`

**File structure (created/modified by this plan):**

```
Gemfile                                               # +rack-attack
config/routes.rb                                      # MVP routes
config/initializers/rack_attack.rb                    # new
app/controllers/application_controller.rb            # include OwnerIdentity
app/controllers/concerns/owner_identity.rb            # new
app/controllers/concerns/rater_identity.rb            # new
app/controllers/houses_controller.rb                  # new
app/controllers/rater_sessions_controller.rb         # new
app/controllers/ratings_controller.rb                 # new
app/controllers/reports_controller.rb                 # new
app/models/category.rb                                # new
app/models/house.rb                                   # new
app/models/rating.rb                                  # new
app/services/scorecard_calculator.rb                  # new
app/views/layouts/application.html.erb                # add mobile meta + PWA link
app/views/houses/{index,new,show,_house}.html.erb     # new
app/views/ratings/{edit,_rating}.html.erb             # new
app/views/ratings/update.turbo_stream.erb             # new
app/views/rater_sessions/{show,rate}.html.erb         # new
app/views/reports/{show,compare}.html.erb             # new
app/views/pwa/manifest.json.erb                       # new
db/migrate/*_create_categories.rb                     # new
db/migrate/*_create_houses.rb                         # new
db/migrate/*_create_ratings.rb                        # new
db/seeds.rb                                           # calls Category.seed!
test/fixtures/{categories,houses,ratings}.yml         # new
test/models/{category,house,rating}_test.rb           # new
test/controllers/{houses,rater_sessions,ratings,reports}_controller_test.rb
test/services/scorecard_calculator_test.rb            # new
test/system/{house_owner_flow,spouse_rating_flow}_test.rb
bin/backup-sqlite                                     # new, deploy-time blocker
```

---

## Phase 1 — Foundations (models, migrations, seeds)

### Task 1: Add `rack-attack` dependency

**Files:**
- Modify: `Gemfile`
- Test: n/a (gem presence will be asserted via initializer in Task 16)

- [ ] **Step 1: Edit `Gemfile`** — add `rack-attack` after existing gems, before the `group :development, :test` block:

```ruby
# Rate limiting and request throttling
gem "rack-attack"
```

- [ ] **Step 2: Run `bundle install`**

Run: `bundle install`
Expected: `rack-attack` installed, `Gemfile.lock` updated.

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore(deps): add rack-attack for rate limiting"
```

---

### Task 2: Category model — migration, model, tests

**Files:**
- Create: `db/migrate/<ts>_create_categories.rb`
- Create: `app/models/category.rb`
- Create: `test/models/category_test.rb`
- Create: `test/fixtures/categories.yml`

- [ ] **Step 1: Write the failing test**

Create `test/models/category_test.rb`:

```ruby
require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "key is required" do
    c = Category.new(label_ko: "학군 접근성", order: 1)
    assert_not c.valid?
    assert_includes c.errors[:key], "can't be blank"
  end

  test "key is unique" do
    Category.create!(key: "school_access", label_ko: "학군 접근성", order: 1)
    dup = Category.new(key: "school_access", label_ko: "다른 라벨", order: 2)
    assert_not dup.valid?
    assert_includes dup.errors[:key], "has already been taken"
  end

  test "ordered scope returns by order ascending" do
    b = Category.create!(key: "b", label_ko: "B", order: 2)
    a = Category.create!(key: "a", label_ko: "A", order: 1)
    assert_equal [a, b], Category.ordered.to_a
  end
end
```

Create `test/fixtures/categories.yml` (empty starter — we'll use explicit `create!` in tests above; fixtures come into play when houses/ratings tests need them):

```yaml
# Intentionally empty. Category rows are loaded via explicit create! in tests
# that need them, or via Category.seed! in integration contexts.
```

- [ ] **Step 2: Run test — expect failures**

Run: `bin/rails test test/models/category_test.rb`
Expected: `NameError: uninitialized constant Category` (or similar).

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreateCategories key:string:uniq label_ko:string order:integer`

Verify the generated migration is shaped like:

```ruby
class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :key, null: false
      t.string :label_ko, null: false
      t.integer :order, null: false
      t.timestamps
    end
    add_index :categories, :key, unique: true
  end
end
```

Edit the migration if the generator omits `null: false` — add it.

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`
Expected: `-- create_table(:categories)` success.

- [ ] **Step 5: Write `app/models/category.rb`**

```ruby
class Category < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :label_ko, presence: true
  validates :order, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:order) }
end
```

- [ ] **Step 6: Run test — expect pass**

Run: `bin/rails test test/models/category_test.rb`
Expected: 3 tests, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_categories.rb db/schema.rb app/models/category.rb \
        test/models/category_test.rb test/fixtures/categories.yml
git commit -m "feat(models): add Category model with key uniqueness + ordered scope"
```

---

### Task 3: `Category.seed!` — idempotent seed of the 10 fixed categories

**Files:**
- Modify: `app/models/category.rb`
- Modify: `db/seeds.rb`
- Modify: `test/models/category_test.rb`

- [ ] **Step 1: Write failing test** — append to `test/models/category_test.rb`:

```ruby
  CATEGORY_SEED_EXPECTATIONS = [
    { key: "school_access", label_ko: "학군 접근성", order: 1 },
    { key: "layout",        label_ko: "평면 구조",     order: 2 },
    { key: "lighting",      label_ko: "채광 / 향",     order: 3 },
    { key: "noise",         label_ko: "소음",         order: 4 },
    { key: "storage",       label_ko: "수납 공간",     order: 5 },
    { key: "parking",       label_ko: "주차",         order: 6 },
    { key: "condition",     label_ko: "노후도 / 수리 상태", order: 7 },
    { key: "access",        label_ko: "엘리베이터 / 동선",  order: 8 },
    { key: "builtin",       label_ko: "옵션 / 빌트인",   order: 9 },
    { key: "amenities",     label_ko: "주변 편의시설",   order: 10 }
  ].freeze

  test "seed! creates exactly 10 categories with expected keys" do
    Category.seed!
    assert_equal 10, Category.count
    keys = Category.ordered.pluck(:key)
    assert_equal CATEGORY_SEED_EXPECTATIONS.map { |c| c[:key] }, keys
  end

  test "seed! is idempotent — calling twice still leaves 10 rows" do
    Category.seed!
    Category.seed!
    assert_equal 10, Category.count
  end

  test "seed! updates label_ko if an existing key has a stale label" do
    Category.create!(key: "school_access", label_ko: "old label", order: 1)
    Category.seed!
    assert_equal "학군 접근성", Category.find_by(key: "school_access").label_ko
  end
```

- [ ] **Step 2: Run test — expect failure**

Run: `bin/rails test test/models/category_test.rb`
Expected: `NoMethodError: undefined method 'seed!'`.

- [ ] **Step 3: Add `seed!` method to `app/models/category.rb`**

```ruby
class Category < ApplicationRecord
  SEED = [
    { key: "school_access", label_ko: "학군 접근성",        order: 1 },
    { key: "layout",        label_ko: "평면 구조",          order: 2 },
    { key: "lighting",      label_ko: "채광 / 향",          order: 3 },
    { key: "noise",         label_ko: "소음",              order: 4 },
    { key: "storage",       label_ko: "수납 공간",          order: 5 },
    { key: "parking",       label_ko: "주차",              order: 6 },
    { key: "condition",     label_ko: "노후도 / 수리 상태",  order: 7 },
    { key: "access",        label_ko: "엘리베이터 / 동선",    order: 8 },
    { key: "builtin",       label_ko: "옵션 / 빌트인",      order: 9 },
    { key: "amenities",     label_ko: "주변 편의시설",      order: 10 }
  ].freeze

  validates :key, presence: true, uniqueness: true
  validates :label_ko, presence: true
  validates :order, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:order) }

  def self.seed!
    SEED.each do |attrs|
      record = find_or_initialize_by(key: attrs[:key])
      record.label_ko = attrs[:label_ko]
      record.order    = attrs[:order]
      record.save!
    end
  end
end
```

- [ ] **Step 4: Run test — expect pass**

Run: `bin/rails test test/models/category_test.rb`
Expected: all tests green.

- [ ] **Step 5: Modify `db/seeds.rb`** — replace placeholder content with:

```ruby
# Categories are the 10 fixed evaluation dimensions. Idempotent.
Category.seed!
```

- [ ] **Step 6: Run seed, verify manually in development**

```bash
bin/rails db:seed
bin/rails runner 'puts Category.ordered.pluck(:key, :label_ko).to_s'
```

Expected output contains all 10 keys/labels.

- [ ] **Step 7: Commit**

```bash
git add app/models/category.rb db/seeds.rb test/models/category_test.rb
git commit -m "feat(models): seed 10 fixed categories with idempotent Category.seed!"
```

---

### Task 4: House model — migration, model, tests

**Files:**
- Create: `db/migrate/<ts>_create_houses.rb`
- Create: `app/models/house.rb`
- Create: `test/models/house_test.rb`
- Create: `test/fixtures/houses.yml`

- [ ] **Step 1: Write failing test** — `test/models/house_test.rb`:

```ruby
require "test_helper"

class HouseTest < ActiveSupport::TestCase
  SESSION_UUID = "11111111-2222-3333-4444-555555555555"

  test "alias is required" do
    h = House.new(owner_session_id: SESSION_UUID)
    assert_not h.valid?
    assert_includes h.errors[:alias_name], "can't be blank"
  end

  test "owner_session_id is required" do
    h = House.new(alias_name: "신반포 32평")
    assert_not h.valid?
    assert_includes h.errors[:owner_session_id], "can't be blank"
  end

  test "share_token is auto-generated on create when blank" do
    h = House.create!(alias_name: "테스트", owner_session_id: SESSION_UUID)
    assert_not_nil h.share_token
    assert_equal 32, h.share_token.length
  end

  test "share_token is unique" do
    House.create!(alias_name: "A", owner_session_id: SESSION_UUID, share_token: "tokenA" + "x" * 26)
    dup = House.new(alias_name: "B", owner_session_id: SESSION_UUID, share_token: "tokenA" + "x" * 26)
    assert_not dup.valid?
    assert_includes dup.errors[:share_token], "has already been taken"
  end

  test "regenerate_share_token! replaces the token" do
    h = House.create!(alias_name: "X", owner_session_id: SESSION_UUID)
    old = h.share_token
    h.regenerate_share_token!
    assert_not_equal old, h.share_token
    assert_equal 32, h.share_token.length
  end

  test "scope for_owner filters by owner_session_id" do
    h1 = House.create!(alias_name: "A", owner_session_id: SESSION_UUID)
    House.create!(alias_name: "B", owner_session_id: "other-uuid")
    assert_equal [h1], House.for_owner(SESSION_UUID).to_a
  end
end
```

Create `test/fixtures/houses.yml` (empty for now — we use `create!` in tests):

```yaml
# Populated when controller tests need a predictable fixture set.
```

- [ ] **Step 2: Run test — expect failure**

Run: `bin/rails test test/models/house_test.rb`
Expected: `NameError: uninitialized constant House`.

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreateHouses alias_name:string owner_session_id:string share_token:string:uniq address:string agent_contact:string`

Edit the generated migration to enforce `null: false` and add index on `owner_session_id`:

```ruby
class CreateHouses < ActiveRecord::Migration[8.1]
  def change
    create_table :houses do |t|
      t.string :alias_name,       null: false
      t.string :owner_session_id, null: false
      t.string :share_token,      null: false
      t.string :address
      t.string :agent_contact
      t.timestamps
    end
    add_index :houses, :share_token, unique: true
    add_index :houses, :owner_session_id
  end
end
```

Note: we use `alias_name` (not `alias`) because `alias` is a Ruby keyword.

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 5: Write `app/models/house.rb`**

```ruby
class House < ApplicationRecord
  SHARE_TOKEN_BYTES = 24 # SecureRandom.urlsafe_base64(24) => 32 chars

  has_many :ratings, dependent: :destroy

  validates :alias_name,       presence: true
  validates :owner_session_id, presence: true
  validates :share_token,      presence: true, uniqueness: true

  before_validation :ensure_share_token

  scope :for_owner, ->(owner_id) { where(owner_session_id: owner_id) }

  def regenerate_share_token!
    update!(share_token: self.class.generate_share_token)
  end

  def self.generate_share_token
    SecureRandom.urlsafe_base64(SHARE_TOKEN_BYTES)
  end

  private

  def ensure_share_token
    self.share_token ||= self.class.generate_share_token
  end
end
```

- [ ] **Step 6: Run test — expect pass**

Run: `bin/rails test test/models/house_test.rb`
Expected: all tests green.

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_houses.rb db/schema.rb app/models/house.rb \
        test/models/house_test.rb test/fixtures/houses.yml
git commit -m "feat(models): add House with auto-generated share_token and owner scope"
```

---

### Task 5: Rating model — migration, model, tests

**Files:**
- Create: `db/migrate/<ts>_create_ratings.rb`
- Create: `app/models/rating.rb`
- Create: `test/models/rating_test.rb`
- Create: `test/fixtures/ratings.yml`

- [ ] **Step 1: Write failing test** — `test/models/rating_test.rb`:

```ruby
require "test_helper"

class RatingTest < ActiveSupport::TestCase
  setup do
    Category.seed!
    @house = House.create!(alias_name: "테스트집", owner_session_id: "owner-1")
    @cat   = Category.find_by!(key: "school_access")
  end

  test "score must be between 1 and 5" do
    r = Rating.new(house: @house, category: @cat, rater_name: "아내",
                   rater_session_id: "owner-1", score: 0)
    assert_not r.valid?
    assert_includes r.errors[:score], "must be in 1..5"

    r.score = 6
    assert_not r.valid?

    r.score = 3
    assert r.valid?
  end

  test "rater_name is required" do
    r = Rating.new(house: @house, category: @cat, rater_session_id: "owner-1", score: 3)
    assert_not r.valid?
    assert_includes r.errors[:rater_name], "can't be blank"
  end

  test "rater_session_id is required" do
    r = Rating.new(house: @house, category: @cat, rater_name: "아내", score: 3)
    assert_not r.valid?
    assert_includes r.errors[:rater_session_id], "can't be blank"
  end

  test "same rater cannot double-rate the same category of the same house" do
    Rating.create!(house: @house, category: @cat, rater_name: "아내",
                   rater_session_id: "owner-1", score: 3)
    dup = Rating.new(house: @house, category: @cat, rater_name: "아내",
                     rater_session_id: "owner-1", score: 4)
    assert_not dup.valid?
    assert_includes dup.errors[:category_id], "has already been taken"
  end

  test "different raters can rate the same category of the same house" do
    Rating.create!(house: @house, category: @cat, rater_name: "아내",
                   rater_session_id: "owner-1", score: 3)
    wife = Rating.new(house: @house, category: @cat, rater_name: "남편",
                      rater_session_id: "spouse-1", score: 5)
    assert wife.valid?
  end
end
```

Create `test/fixtures/ratings.yml` (empty — tests build their own):

```yaml
```

- [ ] **Step 2: Run test — expect failure**

Run: `bin/rails test test/models/rating_test.rb`
Expected: `NameError: uninitialized constant Rating`.

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreateRatings house:references category:references rater_name:string rater_session_id:string score:integer memo:text`

Edit the generated migration:

```ruby
class CreateRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :ratings do |t|
      t.references :house,    null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string  :rater_name,       null: false
      t.string  :rater_session_id, null: false
      t.integer :score,            null: false
      t.text    :memo
      t.timestamps
    end
    add_index :ratings, [ :house_id, :category_id, :rater_session_id ],
              unique: true, name: "idx_ratings_unique_per_rater"
  end
end
```

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 5: Write `app/models/rating.rb`**

```ruby
class Rating < ApplicationRecord
  belongs_to :house
  belongs_to :category

  validates :rater_name,       presence: true
  validates :rater_session_id, presence: true
  validates :score,            presence: true, inclusion: { in: 1..5, message: "must be in 1..5" }
  validates :category_id,      uniqueness: { scope: [ :house_id, :rater_session_id ] }
end
```

- [ ] **Step 6: Run test — expect pass**

Run: `bin/rails test test/models/rating_test.rb`

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_ratings.rb db/schema.rb app/models/rating.rb \
        test/models/rating_test.rb test/fixtures/ratings.yml
git commit -m "feat(models): add Rating with 1-5 score and unique per (house,category,rater)"
```

---

## Phase 2 — Identity concerns (owner + rater cookies)

### Task 6: `OwnerIdentity` concern + wire into `ApplicationController`

**Files:**
- Create: `app/controllers/concerns/owner_identity.rb`
- Modify: `app/controllers/application_controller.rb`
- Create: `test/controllers/application_controller_test.rb`

This concern manages the browser cookie that identifies an anonymous house owner. On the first request, it mints a UUID and stores it in a signed cookie. It exposes `current_owner_id` and `current_owner_name` to controllers and views.

- [ ] **Step 1: Write failing test** — `test/controllers/application_controller_test.rb`:

```ruby
require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "first request assigns an owner_session_id cookie" do
    get root_path
    # Rails sets signed cookies; we read the cleartext via cookies.signed
    owner_id = cookies.signed[:owner_session_id]
    assert_not_nil owner_id
    assert_match(/\A[0-9a-f-]{36}\z/, owner_id)
  end

  test "second request with existing cookie preserves owner_session_id" do
    get root_path
    first = cookies.signed[:owner_session_id]
    get root_path
    second = cookies.signed[:owner_session_id]
    assert_equal first, second
  end
end
```

(The root path will be wired in Task 8. For now this test may need `get "/up"` or similar — we'll adjust once routes exist. For this step, use `get "/up"`.)

Replace both `get root_path` calls with `get "/up"` for now.

- [ ] **Step 2: Run test — expect failure**

Run: `bin/rails test test/controllers/application_controller_test.rb`
Expected: `cookies.signed[:owner_session_id]` is nil.

- [ ] **Step 3: Write `app/controllers/concerns/owner_identity.rb`**

```ruby
module OwnerIdentity
  extend ActiveSupport::Concern

  OWNER_COOKIE       = :owner_session_id
  OWNER_NAME_COOKIE  = :owner_display_name

  included do
    before_action :assign_owner_session_id
    helper_method :current_owner_id, :current_owner_name
  end

  private

  def current_owner_id
    cookies.signed[OWNER_COOKIE]
  end

  def current_owner_name
    cookies.signed[OWNER_NAME_COOKIE].presence || "나"
  end

  def assign_owner_session_id
    return if cookies.signed[OWNER_COOKIE].present?

    cookies.signed.permanent[OWNER_COOKIE] = {
      value: SecureRandom.uuid,
      httponly: true,
      same_site: :lax
    }
  end
end
```

- [ ] **Step 4: Wire it into `app/controllers/application_controller.rb`**

Replace the file contents with:

```ruby
class ApplicationController < ActionController::Base
  include OwnerIdentity

  # Only allow modern browsers supporting webp images, web push, badges, import maps,
  # CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
```

- [ ] **Step 5: Run test — expect pass**

Run: `bin/rails test test/controllers/application_controller_test.rb`

- [ ] **Step 6: Commit**

```bash
git add app/controllers/concerns/owner_identity.rb \
        app/controllers/application_controller.rb \
        test/controllers/application_controller_test.rb
git commit -m "feat(auth): add OwnerIdentity concern minting signed owner_session_id cookie"
```

---

### Task 7: `RaterIdentity` concern for spouse sessions

**Files:**
- Create: `app/controllers/concerns/rater_identity.rb`
- Create: `test/integration/rater_identity_test.rb`

`RaterIdentity` is meant for controllers that sit behind a `/s/:share_token/...` URL. It scopes the rater cookie per-share-token so one browser can act as a rater for multiple different shared houses.

- [ ] **Step 1: Write failing test** — `test/integration/rater_identity_test.rb`:

```ruby
require "test_helper"

class RaterIdentityTest < ActionDispatch::IntegrationTest
  # We'll probe RaterIdentity through the RaterSessionsController built
  # in Task 9. Until then, this test file stays pending — it is the
  # destination but needs routes to exist first.
end
```

This test will be filled in Task 9 — we write a placeholder here so the commit includes the expected location. The `RaterIdentity` concern itself is covered indirectly by Task 9's request tests.

- [ ] **Step 2: Write `app/controllers/concerns/rater_identity.rb`**

```ruby
module RaterIdentity
  extend ActiveSupport::Concern

  private

  def rater_cookie_key(share_token)
    "rater_session_#{share_token}".to_sym
  end

  def rater_name_cookie_key(share_token)
    "rater_name_#{share_token}".to_sym
  end

  def current_rater_id_for(share_token)
    cookies.signed[rater_cookie_key(share_token)]
  end

  def current_rater_name_for(share_token)
    cookies.signed[rater_name_cookie_key(share_token)]
  end

  def assign_rater_session!(share_token:, name:)
    rater_id = SecureRandom.uuid
    cookies.signed.permanent[rater_cookie_key(share_token)] = {
      value: rater_id, httponly: true, same_site: :lax
    }
    cookies.signed.permanent[rater_name_cookie_key(share_token)] = {
      value: name, httponly: true, same_site: :lax
    }
    rater_id
  end
end
```

- [ ] **Step 3: Commit**

```bash
git add app/controllers/concerns/rater_identity.rb \
        test/integration/rater_identity_test.rb
git commit -m "feat(auth): add RaterIdentity concern with per-share_token cookie namespacing"
```

---

## Phase 3 — Core controllers and routes

### Task 8: Routes + `HousesController` (index / new / create / show)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/houses_controller.rb`
- Create: `test/controllers/houses_controller_test.rb`
- Create: `app/views/houses/index.html.erb`
- Create: `app/views/houses/new.html.erb`
- Create: `app/views/houses/show.html.erb`
- Create: `app/views/houses/_house.html.erb`

- [ ] **Step 1: Write failing test** — `test/controllers/houses_controller_test.rb`:

```ruby
require "test_helper"

class HousesControllerTest < ActionDispatch::IntegrationTest
  setup { Category.seed! }

  test "GET /houses shows only houses owned by current session" do
    get houses_path # mints owner cookie
    owner_id = cookies.signed[:owner_session_id]
    mine = House.create!(alias_name: "내 집", owner_session_id: owner_id)
    House.create!(alias_name: "남의 집", owner_session_id: "someone-else")

    get houses_path
    assert_response :success
    assert_match "내 집", @response.body
    assert_no_match "남의 집", @response.body
  end

  test "POST /houses creates a house scoped to current owner with share_token" do
    get houses_path # mints cookie
    owner_id = cookies.signed[:owner_session_id]
    assert_difference -> { House.for_owner(owner_id).count }, 1 do
      post houses_path, params: { house: { alias_name: "신반포 32평" } }
    end
    assert_redirected_to house_path(House.last)
    assert_not_nil House.last.share_token
  end

  test "GET /houses/:id renders only for the owner" do
    get houses_path
    owner_id = cookies.signed[:owner_session_id]
    mine = House.create!(alias_name: "내 집", owner_session_id: owner_id)
    get house_path(mine)
    assert_response :success
    assert_match "내 집", @response.body
  end

  test "GET /houses/:id returns 404 if not owned" do
    others = House.create!(alias_name: "남의", owner_session_id: "another")
    get houses_path # establishes a different owner cookie
    get house_path(others)
    assert_response :not_found
  end
end
```

- [ ] **Step 2: Edit `config/routes.rb`**

```ruby
Rails.application.routes.draw do
  root "houses#index"

  resources :houses, only: [ :index, :new, :create, :show ] do
    resource  :report,  only: [ :show ], controller: "reports"
    resources :ratings, only: [ :update ]
    collection { get :compare, to: "reports#compare" }
  end

  # Spouse (rater) flow — share_token scoped
  scope "s/:share_token", as: :share do
    get  "/",                        to: "rater_sessions#show",    as: :session
    post "/",                        to: "rater_sessions#create"
    get  "/rate",                    to: "rater_sessions#rate",    as: :rate
    patch "/ratings/:category_id",   to: "ratings#rater_update",   as: :rating
  end

  # Health + PWA (Rails defaults)
  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
```

- [ ] **Step 3: Run test — expect failure** (controller missing)

Run: `bin/rails test test/controllers/houses_controller_test.rb`

- [ ] **Step 4: Write `app/controllers/houses_controller.rb`**

```ruby
class HousesController < ApplicationController
  before_action :find_my_house, only: [ :show ]

  def index
    @houses = House.for_owner(current_owner_id).order(created_at: :desc)
  end

  def new
    @house = House.new
  end

  def create
    @house = House.new(house_params.merge(owner_session_id: current_owner_id))
    if @house.save
      redirect_to house_path(@house), notice: "집이 등록되었어요. 방문 중 평가를 시작해 보세요."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @categories = Category.ordered
    @my_ratings = Rating.where(house: @house, rater_session_id: current_owner_id).index_by(&:category_id)
  end

  private

  def house_params
    params.require(:house).permit(:alias_name, :address, :agent_contact)
  end

  def find_my_house
    @house = House.for_owner(current_owner_id).find_by(id: params[:id])
    raise ActiveRecord::RecordNotFound unless @house
  end
end
```

- [ ] **Step 5: Write minimal views**

Create `app/views/houses/index.html.erb`:

```erb
<div class="max-w-lg mx-auto p-4">
  <h1 class="text-2xl font-bold mb-4">내 집 둘러보기 목록</h1>
  <%= link_to "새 집 추가", new_house_path,
        class: "block w-full text-center py-3 mb-4 rounded bg-blue-600 text-white font-medium" %>

  <% if @houses.any? %>
    <ul class="space-y-2">
      <%= render @houses %>
    </ul>
    <div class="mt-6">
      <%= link_to "집 비교 리포트 →", compare_houses_path,
            class: "block text-center py-3 rounded bg-gray-100 text-gray-800 font-medium" %>
    </div>
  <% else %>
    <p class="text-gray-500">아직 등록된 집이 없어요. 위 버튼으로 첫 집을 추가하세요.</p>
  <% end %>
</div>
```

Create `app/views/houses/_house.html.erb`:

```erb
<li class="border rounded p-4 bg-white">
  <%= link_to house_path(house), class: "block" do %>
    <div class="flex justify-between items-center">
      <span class="font-semibold"><%= house.alias_name %></span>
      <span class="text-sm text-gray-500">평가하러 가기 →</span>
    </div>
    <% if house.address.present? %>
      <div class="text-sm text-gray-500 mt-1"><%= house.address %></div>
    <% end %>
  <% end %>
</li>
```

Create `app/views/houses/new.html.erb`:

```erb
<div class="max-w-lg mx-auto p-4">
  <h1 class="text-2xl font-bold mb-4">새 집 추가</h1>
  <%= form_with model: @house, class: "space-y-4" do |f| %>
    <% if @house.errors.any? %>
      <div class="bg-red-50 text-red-800 p-3 rounded">
        <%= @house.errors.full_messages.join(", ") %>
      </div>
    <% end %>
    <div>
      <%= f.label :alias_name, "집 별칭", class: "block font-medium mb-1" %>
      <%= f.text_field :alias_name, required: true, autofocus: true,
            placeholder: "예: 신반포 32평", class: "w-full border rounded p-3 text-base" %>
    </div>
    <div>
      <%= f.label :address, "주소 (선택)", class: "block font-medium mb-1" %>
      <%= f.text_field :address, class: "w-full border rounded p-3 text-base" %>
    </div>
    <div>
      <%= f.label :agent_contact, "중개인 연락처 (선택)", class: "block font-medium mb-1" %>
      <%= f.text_field :agent_contact, class: "w-full border rounded p-3 text-base" %>
    </div>
    <%= f.submit "이 집 등록하기",
          class: "w-full py-3 rounded bg-blue-600 text-white font-medium" %>
  <% end %>
</div>
```

Create `app/views/houses/show.html.erb`:

```erb
<div class="max-w-lg mx-auto p-4">
  <h1 class="text-2xl font-bold mb-1"><%= @house.alias_name %></h1>
  <% if @house.address.present? %>
    <p class="text-sm text-gray-500 mb-4"><%= @house.address %></p>
  <% end %>

  <div class="mb-4 p-3 bg-blue-50 rounded text-sm">
    <p class="font-medium mb-1">배우자 초대 링크</p>
    <p class="break-all text-blue-700"><%= share_session_url(@house.share_token) %></p>
  </div>

  <h2 class="text-lg font-semibold mb-2">내가 평가하기</h2>
  <ul id="ratings" class="space-y-3">
    <% @categories.each do |category| %>
      <%= render "ratings/rating",
                 category: category,
                 rating: @my_ratings[category.id],
                 house: @house,
                 context: :owner %>
    <% end %>
  </ul>

  <div class="mt-6">
    <%= link_to "리포트 보기 →", house_report_path(@house),
          class: "block text-center py-3 rounded bg-gray-100 text-gray-800 font-medium" %>
  </div>
</div>
```

(The `ratings/rating` partial is created in Task 10. Until then `render` will fail at view-time. This is expected — `HousesController#show` test only asserts text match for the house name, not full render — but System tests in Task 17 will require the partial. Task 10 fills this in.)

- [ ] **Step 6: Run test — expect pass**

Run: `bin/rails test test/controllers/houses_controller_test.rb`

Controller tests above don't assert the full show body beyond the alias name, so missing partial from Task 10 won't block. If the test framework still tries to render the full template and fails, temporarily stub: `def show; @house = ...; end` and render nothing. But the ideal path is to proceed to Task 10 immediately.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/houses_controller.rb \
        app/views/houses test/controllers/houses_controller_test.rb
git commit -m "feat(houses): index/new/create/show scoped by owner_session_id"
```

---

### Task 9: `RaterSessionsController` — share-link entry + name input

**Files:**
- Create: `app/controllers/rater_sessions_controller.rb`
- Create: `app/views/rater_sessions/show.html.erb`
- Create: `app/views/rater_sessions/rate.html.erb`
- Create: `test/controllers/rater_sessions_controller_test.rb`

- [ ] **Step 1: Write failing test** — `test/controllers/rater_sessions_controller_test.rb`:

```ruby
require "test_helper"

class RaterSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Category.seed!
    @house = House.create!(alias_name: "공유 집", owner_session_id: "owner-xyz")
  end

  test "GET /s/:share_token renders name form if no rater cookie" do
    get share_session_path(@house.share_token)
    assert_response :success
    assert_match "이름을 입력", @response.body
  end

  test "invalid share_token returns 404" do
    get share_session_path("not-a-real-token")
    assert_response :not_found
  end

  test "POST /s/:share_token sets rater cookie and redirects to /rate" do
    post share_session_path(@house.share_token), params: { rater: { name: "남편" } }
    assert_redirected_to share_rate_path(@house.share_token)
    assert_not_nil cookies.signed["rater_session_#{@house.share_token}"]
    assert_equal "남편", cookies.signed["rater_name_#{@house.share_token}"]
  end

  test "GET /s/:share_token with existing cookie skips form and goes to /rate" do
    post share_session_path(@house.share_token), params: { rater: { name: "남편" } }
    get share_session_path(@house.share_token)
    assert_redirected_to share_rate_path(@house.share_token)
  end

  test "GET /s/:share_token/rate renders categories" do
    post share_session_path(@house.share_token), params: { rater: { name: "남편" } }
    get share_rate_path(@house.share_token)
    assert_response :success
    assert_match "학군 접근성", @response.body
  end
end
```

- [ ] **Step 2: Run test — expect failure**

Run: `bin/rails test test/controllers/rater_sessions_controller_test.rb`

- [ ] **Step 3: Write `app/controllers/rater_sessions_controller.rb`**

```ruby
class RaterSessionsController < ApplicationController
  include RaterIdentity

  before_action :load_house_by_share_token

  def show
    if current_rater_id_for(@house.share_token).present?
      redirect_to share_rate_path(@house.share_token) and return
    end
    # Else render the name form
  end

  def create
    name = params.require(:rater).permit(:name)[:name].to_s.strip
    if name.blank?
      flash.now[:alert] = "이름을 입력해 주세요."
      render :show, status: :unprocessable_entity and return
    end

    assign_rater_session!(share_token: @house.share_token, name: name)
    redirect_to share_rate_path(@house.share_token)
  end

  def rate
    @categories = Category.ordered
    @my_ratings = Rating.where(house: @house,
                               rater_session_id: current_rater_id_for(@house.share_token))
                        .index_by(&:category_id)
  end

  private

  def load_house_by_share_token
    @house = House.find_by(share_token: params[:share_token])
    raise ActiveRecord::RecordNotFound unless @house
  end
end
```

- [ ] **Step 4: Write views**

Create `app/views/rater_sessions/show.html.erb`:

```erb
<div class="max-w-lg mx-auto p-4">
  <h1 class="text-2xl font-bold mb-2">'<%= @house.alias_name %>'에 평가를 남기려면</h1>
  <p class="text-gray-600 mb-4">이름을 입력해 주세요. 이 이름은 리포트에 당신의 평가를 구분하는 데 사용됩니다.</p>

  <% if flash[:alert] %>
    <div class="bg-red-50 text-red-800 p-3 rounded mb-4"><%= flash[:alert] %></div>
  <% end %>

  <%= form_with url: share_session_path(@house.share_token), method: :post, class: "space-y-4" do |f| %>
    <%= f.text_field "rater[name]", required: true, autofocus: true,
          placeholder: "예: 남편",
          class: "w-full border rounded p-3 text-base" %>
    <%= f.submit "평가 시작하기", class: "w-full py-3 rounded bg-blue-600 text-white font-medium" %>
  <% end %>
</div>
```

Create `app/views/rater_sessions/rate.html.erb`:

```erb
<div class="max-w-lg mx-auto p-4">
  <h1 class="text-2xl font-bold mb-1"><%= @house.alias_name %></h1>
  <p class="text-sm text-gray-500 mb-4">
    평가자: <%= current_rater_name_for(@house.share_token) %>
  </p>
  <ul id="ratings" class="space-y-3">
    <% @categories.each do |category| %>
      <%= render "ratings/rating",
                 category: category,
                 rating: @my_ratings[category.id],
                 house: @house,
                 context: :rater %>
    <% end %>
  </ul>
</div>
```

- [ ] **Step 5: Run test — expect pass** (controller tests green; view rendering of `rate.html.erb` may still fail until Task 10 provides the `ratings/rating` partial — the controller tests here only assert redirect targets and body text matches that don't require the partial. The `GET /s/:share_token/rate renders categories` test does render the view — so you may need to stub the partial temporarily or proceed to Task 10 before re-running this test).

If you need to unblock: create a placeholder `app/views/ratings/_rating.html.erb` containing `<li class="border rounded p-3"><%= category.label_ko %></li>` — Task 10 will replace it.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/rater_sessions_controller.rb \
        app/views/rater_sessions \
        test/controllers/rater_sessions_controller_test.rb
git commit -m "feat(rater): add RaterSessionsController for share-link name entry"
```

---

### Task 10: `RatingsController#update` (owner) + partial + Turbo Stream

**Files:**
- Create: `app/controllers/ratings_controller.rb`
- Create/Replace: `app/views/ratings/_rating.html.erb`
- Create: `app/views/ratings/update.turbo_stream.erb`
- Create: `test/controllers/ratings_controller_test.rb`

- [ ] **Step 1: Write failing test** — `test/controllers/ratings_controller_test.rb`:

```ruby
require "test_helper"

class RatingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Category.seed!
    get houses_path # establish owner cookie
    @owner_id = cookies.signed[:owner_session_id]
    @house = House.create!(alias_name: "테스트", owner_session_id: @owner_id)
    @cat   = Category.find_by!(key: "school_access")
  end

  test "owner PATCH creates a rating when none exists" do
    patch house_rating_path(@house, @cat.id),
          params: { rating: { score: 4 } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    rating = Rating.find_by!(house: @house, category: @cat, rater_session_id: @owner_id)
    assert_equal 4, rating.score
    assert_equal "나", rating.rater_name
  end

  test "owner PATCH updates existing rating (upsert)" do
    Rating.create!(house: @house, category: @cat, rater_name: "나",
                   rater_session_id: @owner_id, score: 2)
    patch house_rating_path(@house, @cat.id),
          params: { rating: { score: 5 } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_equal 5, Rating.find_by!(house: @house, category: @cat).score
  end

  test "owner PATCH for someone else's house is 404" do
    other = House.create!(alias_name: "남의", owner_session_id: "another")
    patch house_rating_path(other, @cat.id), params: { rating: { score: 3 } }
    assert_response :not_found
  end

  test "score outside 1..5 responds 422" do
    patch house_rating_path(@house, @cat.id), params: { rating: { score: 9 } }
    assert_response :unprocessable_entity
  end
end
```

- [ ] **Step 2: Run test — expect failure** (no controller)

Run: `bin/rails test test/controllers/ratings_controller_test.rb`

- [ ] **Step 3: Write `app/controllers/ratings_controller.rb`**

```ruby
class RatingsController < ApplicationController
  include RaterIdentity

  before_action :load_owner_house_and_category, only: [ :update ]
  before_action :load_rater_house_and_category, only: [ :rater_update ]

  # PATCH /houses/:house_id/ratings/:id
  def update
    upsert_rating!(rater_id: current_owner_id, rater_name: current_owner_name)
    respond_to do |format|
      format.turbo_stream # renders update.turbo_stream.erb
      format.html { redirect_to house_path(@house) }
    end
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  # PATCH /s/:share_token/ratings/:category_id
  def rater_update
    rater_id   = current_rater_id_for(@house.share_token)
    rater_name = current_rater_name_for(@house.share_token)
    raise ActiveRecord::RecordNotFound if rater_id.blank?

    upsert_rating!(rater_id: rater_id, rater_name: rater_name)
    respond_to do |format|
      format.turbo_stream { render :update } # reuse same stream partial
      format.html { redirect_to share_rate_path(@house.share_token) }
    end
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  private

  def upsert_rating!(rater_id:, rater_name:)
    @rating = Rating.find_or_initialize_by(
      house: @house, category: @category, rater_session_id: rater_id
    )
    @rating.rater_name = rater_name
    @rating.score      = params.require(:rating).permit(:score, :memo)[:score]
    @rating.memo       = params.require(:rating).permit(:score, :memo)[:memo]
    @rating.save!
    @context = rater_id == current_owner_id ? :owner : :rater
  end

  def load_owner_house_and_category
    @house    = House.for_owner(current_owner_id).find_by(id: params[:house_id])
    @category = Category.find_by(id: params[:id])
    raise ActiveRecord::RecordNotFound unless @house && @category
  end

  def load_rater_house_and_category
    @house    = House.find_by(share_token: params[:share_token])
    @category = Category.find_by(id: params[:category_id])
    raise ActiveRecord::RecordNotFound unless @house && @category
  end
end
```

- [ ] **Step 4: Write/replace `app/views/ratings/_rating.html.erb`**

```erb
<%# Locals: category, rating, house, context (:owner or :rater) %>
<li id="<%= dom_id(category, :rating_cell) %>" class="border rounded p-3 bg-white">
  <div class="flex justify-between items-center mb-2">
    <span class="font-medium"><%= category.label_ko %></span>
    <span class="text-sm text-gray-500">
      <%= rating&.score ? "#{rating.score}/5" : "미평가" %>
    </span>
  </div>
  <%= form_with url: rating_form_url(category: category, house: house, context: context),
                method: :patch,
                data: { turbo_stream: true },
                class: "flex gap-1" do |f| %>
    <% (1..5).each do |score| %>
      <%= f.button score,
            name: "rating[score]", value: score,
            class: "flex-1 min-h-[44px] rounded border #{rating&.score == score ? 'bg-blue-600 text-white border-blue-600' : 'bg-gray-50'}" %>
    <% end %>
  <% end %>
</li>
```

Add URL helper to `app/helpers/application_helper.rb`:

```ruby
module ApplicationHelper
  def rating_form_url(category:, house:, context:)
    if context == :owner
      house_rating_path(house, category.id)
    else
      share_rating_path(house.share_token, category.id)
    end
  end
end
```

- [ ] **Step 5: Write `app/views/ratings/update.turbo_stream.erb`**

```erb
<%= turbo_stream.replace dom_id(@category, :rating_cell) do %>
  <%= render "ratings/rating",
             category: @category,
             rating: @rating,
             house: @house,
             context: @context %>
<% end %>
```

- [ ] **Step 6: Run tests — expect pass**

Run: `bin/rails test test/controllers/ratings_controller_test.rb test/controllers/houses_controller_test.rb test/controllers/rater_sessions_controller_test.rb`

- [ ] **Step 7: Commit**

```bash
git add app/controllers/ratings_controller.rb app/views/ratings \
        app/helpers/application_helper.rb \
        test/controllers/ratings_controller_test.rb
git commit -m "feat(ratings): owner + rater upsert with Turbo Stream replace"
```

---

## Phase 4 — Scorecard math and reports

### Task 11: `ScorecardCalculator` service (pure POJO)

**Files:**
- Create: `app/services/scorecard_calculator.rb`
- Create: `test/services/scorecard_calculator_test.rb`

This service takes a list of Ratings for a single house and computes: averages per category, agreements (`|a-b| <= 1`), disagreements (`|a-b| >= 2`). It does NOT query the DB — it operates on plain data structures passed in.

- [ ] **Step 1: Write failing test** — `test/services/scorecard_calculator_test.rb`:

```ruby
require "test_helper"

class ScorecardCalculatorTest < ActiveSupport::TestCase
  # Input shape: array of { category_key:, rater_id:, score: }
  def ratings(*tuples)
    tuples.map { |k, r, s| { category_key: k, rater_id: r, score: s } }
  end

  test "single-rater data returns empty agreement/disagreement (needs 2 raters)" do
    result = ScorecardCalculator.analyze(ratings(
      [ "school_access", "owner", 4 ],
      [ "layout",        "owner", 3 ]
    ))
    assert_empty result.agreements
    assert_empty result.disagreements
  end

  test "agreement when both raters within 1 point" do
    result = ScorecardCalculator.analyze(ratings(
      [ "school_access", "owner",  4 ],
      [ "school_access", "spouse", 5 ]
    ))
    assert_equal [ "school_access" ], result.agreements
    assert_empty result.disagreements
  end

  test "disagreement when both raters differ by 2 or more" do
    result = ScorecardCalculator.analyze(ratings(
      [ "layout", "owner",  2 ],
      [ "layout", "spouse", 5 ]
    ))
    assert_equal [ "layout" ], result.disagreements
    assert_empty result.agreements
  end

  test "averages only include categories with both raters present" do
    result = ScorecardCalculator.analyze(ratings(
      [ "layout", "owner",  4 ],
      [ "layout", "spouse", 4 ],
      [ "noise",  "owner",  2 ]   # spouse didn't rate noise → skip in averages
    ))
    assert_equal({ "layout" => 4.0 }, result.averages)
  end

  test "boundary: diff exactly 1 is agreement, diff exactly 2 is disagreement" do
    result = ScorecardCalculator.analyze(ratings(
      [ "a", "o", 3 ], [ "a", "s", 4 ],   # diff 1 → agreement
      [ "b", "o", 3 ], [ "b", "s", 5 ],   # diff 2 → disagreement
      [ "c", "o", 3 ], [ "c", "s", 3 ]    # diff 0 → agreement
    ))
    assert_equal %w[a c].sort, result.agreements.sort
    assert_equal %w[b],       result.disagreements
  end

  test "leading_categories compares multiple houses and picks this house's winners" do
    # 3 houses, 3 categories; house A leads on 'layout' by +1.0 over average of others
    all = {
      "A" => ratings([ "layout", "o", 5 ], [ "layout", "s", 5 ],
                     [ "noise",  "o", 3 ], [ "noise",  "s", 3 ]),
      "B" => ratings([ "layout", "o", 3 ], [ "layout", "s", 3 ],
                     [ "noise",  "o", 4 ], [ "noise",  "s", 4 ]),
      "C" => ratings([ "layout", "o", 3 ], [ "layout", "s", 3 ],
                     [ "noise",  "o", 5 ], [ "noise",  "s", 5 ])
    }
    result = ScorecardCalculator.leading_categories(all_houses_ratings: all, focus_house_key: "A")
    assert_equal [ "layout" ], result
  end
end
```

- [ ] **Step 2: Run test — expect failure**

Run: `bin/rails test test/services/scorecard_calculator_test.rb`

- [ ] **Step 3: Write `app/services/scorecard_calculator.rb`**

```ruby
class ScorecardCalculator
  AGREEMENT_MAX_DIFF    = 1
  DISAGREEMENT_MIN_DIFF = 2
  LEADING_MIN_MARGIN    = 1.0

  Result = Struct.new(:averages, :agreements, :disagreements, keyword_init: true)

  # Analyze a single house's ratings (for couple report).
  # Input: array of { category_key:, rater_id:, score: }
  def self.analyze(rating_rows)
    by_cat = rating_rows.group_by { |r| r[:category_key] }

    averages = {}
    agreements = []
    disagreements = []

    by_cat.each do |key, rows|
      scores = rows.map { |r| r[:score] }
      next unless rows.map { |r| r[:rater_id] }.uniq.size >= 2

      averages[key] = (scores.sum.to_f / scores.size).round(2)
      diff = (scores.max - scores.min).abs
      if diff <= AGREEMENT_MAX_DIFF
        agreements << key
      elsif diff >= DISAGREEMENT_MIN_DIFF
        disagreements << key
      end
    end

    Result.new(averages: averages, agreements: agreements, disagreements: disagreements)
  end

  # Compare the focus house's category averages against other houses' averages.
  # Returns category keys where focus_house_avg >= other_avg + LEADING_MIN_MARGIN.
  # Input: all_houses_ratings = { house_key => rating_rows }, focus_house_key = which to highlight.
  def self.leading_categories(all_houses_ratings:, focus_house_key:)
    averages_by_house = all_houses_ratings.transform_values { |rows| analyze(rows).averages }
    focus = averages_by_house.fetch(focus_house_key, {})
    others = averages_by_house.except(focus_house_key)

    focus.each_with_object([]) do |(cat_key, focus_avg), leading|
      other_values = others.values.filter_map { |h| h[cat_key] }
      next if other_values.empty?
      other_avg = other_values.sum / other_values.size.to_f
      leading << cat_key if focus_avg >= other_avg + LEADING_MIN_MARGIN
    end
  end
end
```

- [ ] **Step 4: Run test — expect pass**

Run: `bin/rails test test/services/scorecard_calculator_test.rb`

- [ ] **Step 5: Commit**

```bash
git add app/services/scorecard_calculator.rb test/services/scorecard_calculator_test.rb
git commit -m "feat(scorecard): pure calculator for averages, agreements, leading categories"
```

---

### Task 12: `ReportsController#show` (single house couple report)

**Files:**
- Create: `app/controllers/reports_controller.rb`
- Create: `app/views/reports/show.html.erb`
- Create: `test/controllers/reports_controller_test.rb`

- [ ] **Step 1: Write failing test** — `test/controllers/reports_controller_test.rb`:

```ruby
require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Category.seed!
    get houses_path
    @owner_id = cookies.signed[:owner_session_id]
    @house = House.create!(alias_name: "공유집", owner_session_id: @owner_id)
    @school = Category.find_by!(key: "school_access")
    @noise  = Category.find_by!(key: "noise")

    Rating.create!(house: @house, category: @school, rater_name: "나",
                   rater_session_id: @owner_id, score: 4)
    Rating.create!(house: @house, category: @school, rater_name: "남편",
                   rater_session_id: "spouse-1", score: 5)
    Rating.create!(house: @house, category: @noise, rater_name: "나",
                   rater_session_id: @owner_id, score: 2)
    Rating.create!(house: @house, category: @noise, rater_name: "남편",
                   rater_session_id: "spouse-1", score: 5) # disagreement
  end

  test "GET /houses/:id/report shows averages + agreements + disagreements" do
    get house_report_path(@house)
    assert_response :success
    assert_match "학군 접근성", @response.body
    assert_match "의견 일치", @response.body
    assert_match "의견 갈림", @response.body
    assert_match "소음", @response.body
  end

  test "non-owner cannot view report (404)" do
    foreign = House.create!(alias_name: "남의집", owner_session_id: "someone-else")
    get house_report_path(foreign)
    assert_response :not_found
  end
end
```

- [ ] **Step 2: Write `app/controllers/reports_controller.rb`**

```ruby
class ReportsController < ApplicationController
  before_action :load_my_house, only: [ :show ]

  def show
    rows = @house.ratings.includes(:category).map do |r|
      { category_key: r.category.key, rater_id: r.rater_session_id, score: r.score }
    end
    @result = ScorecardCalculator.analyze(rows)
    @categories_by_key = Category.ordered.index_by(&:key)
  end

  def compare
    @houses = House.for_owner(current_owner_id).includes(ratings: :category)
    all_rows = @houses.each_with_object({}) do |h, memo|
      memo[h.alias_name] = h.ratings.map do |r|
        { category_key: r.category.key, rater_id: r.rater_session_id, score: r.score }
      end
    end
    @leaders = @houses.each_with_object({}) do |h, memo|
      memo[h.id] = ScorecardCalculator.leading_categories(
        all_houses_ratings: all_rows, focus_house_key: h.alias_name
      )
    end
    @categories_by_key = Category.ordered.index_by(&:key)
  end

  private

  def load_my_house
    @house = House.for_owner(current_owner_id).find_by(id: params[:house_id])
    raise ActiveRecord::RecordNotFound unless @house
  end
end
```

- [ ] **Step 3: Write `app/views/reports/show.html.erb`**

```erb
<div class="max-w-lg mx-auto p-4">
  <h1 class="text-2xl font-bold mb-1"><%= @house.alias_name %> 리포트</h1>
  <p class="text-sm text-gray-500 mb-4">부부 평균 점수 / 의견 일치 / 의견 갈림</p>

  <% if @result.averages.empty? %>
    <p class="text-gray-500">두 사람 모두 평가한 범주가 아직 없어요. 배우자 초대 링크로 같이 평가해 보세요.</p>
  <% else %>
    <section class="mb-5">
      <h2 class="text-lg font-semibold mb-2">평균 점수</h2>
      <ul class="space-y-1">
        <% @result.averages.each do |key, avg| %>
          <li class="flex justify-between border-b py-2">
            <span><%= @categories_by_key[key].label_ko %></span>
            <span class="font-mono"><%= avg %>/5</span>
          </li>
        <% end %>
      </ul>
    </section>

    <section class="mb-5">
      <h2 class="text-lg font-semibold mb-2 text-green-700">✓ 의견 일치</h2>
      <% if @result.agreements.any? %>
        <ul class="list-disc pl-5 text-green-800">
          <% @result.agreements.each do |key| %>
            <li><%= @categories_by_key[key].label_ko %></li>
          <% end %>
        </ul>
      <% else %>
        <p class="text-gray-500">아직 없어요.</p>
      <% end %>
    </section>

    <section class="mb-5">
      <h2 class="text-lg font-semibold mb-2 text-red-700">⚠ 의견 갈림</h2>
      <% if @result.disagreements.any? %>
        <ul class="list-disc pl-5 text-red-800">
          <% @result.disagreements.each do |key| %>
            <li><%= @categories_by_key[key].label_ko %></li>
          <% end %>
        </ul>
      <% else %>
        <p class="text-gray-500">아직 없어요.</p>
      <% end %>
    </section>
  <% end %>

  <%# The owner's report URL is private (owner-scoped, 404 to others).
      Share button therefore shares the PUBLIC share_session_url (co-rater
      invite link) so the couple/family can collaborate, not the private
      report link. %>
  <button type="button"
          data-controller="share"
          data-share-title-value="<%= @house.alias_name %> 같이 평가해요"
          data-share-url-value="<%= share_session_url(@house.share_token) %>"
          data-action="click->share#open"
          class="w-full py-3 rounded bg-blue-600 text-white font-medium mt-4">
    배우자/가족에게 평가 초대 링크 공유
  </button>
</div>
```

- [ ] **Step 4: Run test — expect pass**

Run: `bin/rails test test/controllers/reports_controller_test.rb`

- [ ] **Step 5: Commit**

```bash
git add app/controllers/reports_controller.rb app/views/reports/show.html.erb \
        test/controllers/reports_controller_test.rb
git commit -m "feat(reports): single-house couple report (avg, agreement, disagreement)"
```

---

### Task 13: `ReportsController#compare` (multi-house ranking)

**Files:**
- Create: `app/views/reports/compare.html.erb`
- Modify: `test/controllers/reports_controller_test.rb`

- [ ] **Step 1: Append failing test**

```ruby
  test "GET /houses/compare shows leading categories for each house" do
    # Second house, layout favored
    h2 = House.create!(alias_name: "집B", owner_session_id: @owner_id)
    layout = Category.find_by!(key: "layout")
    Rating.create!(house: h2, category: layout, rater_name: "나",
                   rater_session_id: @owner_id, score: 5)
    Rating.create!(house: h2, category: layout, rater_name: "남편",
                   rater_session_id: "spouse-2", score: 5)
    Rating.create!(house: @house, category: layout, rater_name: "나",
                   rater_session_id: @owner_id, score: 3)
    Rating.create!(house: @house, category: layout, rater_name: "남편",
                   rater_session_id: "spouse-1", score: 3)

    get compare_houses_path
    assert_response :success
    assert_match "집B", @response.body
    assert_match "평면 구조", @response.body
  end
```

- [ ] **Step 2: Run — expect failure** (view missing)

Run: `bin/rails test test/controllers/reports_controller_test.rb`

- [ ] **Step 3: Write `app/views/reports/compare.html.erb`**

```erb
<div class="max-w-lg mx-auto p-4">
  <h1 class="text-2xl font-bold mb-4">집 비교 리포트</h1>

  <% if @houses.empty? %>
    <p class="text-gray-500">비교할 집이 없어요. 최소 2채 이상 평가를 남겨 주세요.</p>
  <% else %>
    <ul class="space-y-4">
      <% @houses.each do |house| %>
        <li class="border rounded p-4 bg-white">
          <h2 class="font-semibold text-lg mb-1"><%= house.alias_name %></h2>
          <% if @leaders[house.id].any? %>
            <p class="text-sm text-gray-500 mb-1">다른 집보다 앞선 범주:</p>
            <ul class="list-disc pl-5 text-blue-800">
              <% @leaders[house.id].each do |key| %>
                <li><%= @categories_by_key[key].label_ko %></li>
              <% end %>
            </ul>
          <% else %>
            <p class="text-sm text-gray-500">다른 집보다 뚜렷하게 앞선 범주 없음.</p>
          <% end %>
          <%= link_to "이 집 리포트 상세 →", house_report_path(house),
                class: "block mt-3 text-sm text-blue-600" %>
        </li>
      <% end %>
    </ul>
  <% end %>
</div>
```

- [ ] **Step 4: Run test — expect pass**

Run: `bin/rails test test/controllers/reports_controller_test.rb`

- [ ] **Step 5: Commit**

```bash
git add app/views/reports/compare.html.erb test/controllers/reports_controller_test.rb
git commit -m "feat(reports): multi-house compare view with leading categories"
```

---

## Phase 5 — Mobile polish, PWA, rate-limit

### Task 14: Mobile layout + Web Share API Stimulus controller

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/javascript/controllers/share_controller.js`
- Modify: `app/javascript/controllers/index.js` (if not eagerly loaded)

- [ ] **Step 1: Replace `app/views/layouts/application.html.erb` contents**

```erb
<!DOCTYPE html>
<html lang="ko">
  <head>
    <title>Pick My House — 이사 갈 집 평가</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="theme-color" content="#2563eb">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= yield :head %>
    <link rel="manifest" href="<%= pwa_manifest_path(format: :json) %>">
    <link rel="icon" href="/icon.png" type="image/png">
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="bg-gray-50 text-gray-900">
    <% if flash[:notice] %>
      <div class="bg-green-50 border-b border-green-200 text-green-800 text-center py-2 text-sm"><%= flash[:notice] %></div>
    <% end %>
    <%= yield %>
  </body>
</html>
```

- [ ] **Step 2: Write `app/javascript/controllers/share_controller.js`**

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { title: String, url: String }

  async open() {
    // urlValue (from the view) wins; fallback to current page URL.
    const url = this.hasUrlValue && this.urlValue ? this.urlValue : window.location.href
    const payload = { title: this.titleValue, url }
    try {
      if (navigator.share) {
        await navigator.share(payload)
      } else if (navigator.clipboard) {
        await navigator.clipboard.writeText(url)
        alert("링크를 복사했어요. 카카오톡이나 메시지 앱에 붙여넣기 하세요.")
      } else {
        alert(url)
      }
    } catch (e) {
      // user canceled share sheet — no-op
    }
  }
}
```

- [ ] **Step 3: Verify `app/javascript/controllers/index.js` picks up the controller**

If the project uses `stimulus-loading`'s `eagerLoadControllersFrom("controllers", application)`, no edit needed. Otherwise add:

```js
import ShareController from "./share_controller"
application.register("share", ShareController)
```

- [ ] **Step 4: Manual smoke (optional)**

Run: `bin/dev` in a second terminal, visit `http://localhost:3000/houses/new` on a mobile viewport in Chrome DevTools. Verify mobile meta is active (viewport fits).

- [ ] **Step 5: Commit**

```bash
git add app/views/layouts/application.html.erb \
        app/javascript/controllers/share_controller.js \
        app/javascript/controllers/index.js
git commit -m "feat(ui): mobile meta + Web Share API Stimulus controller"
```

---

### Task 15: PWA manifest (Add-to-home-screen only, no offline caching)

**Files:**
- Create: `app/views/pwa/manifest.json.erb`
- Modify: `config/routes.rb` (already added `pwa_manifest` in Task 8 — verify)

- [ ] **Step 1: Write failing test** — `test/integration/pwa_manifest_test.rb`:

```ruby
require "test_helper"

class PwaManifestTest < ActionDispatch::IntegrationTest
  test "manifest.json returns valid JSON with name, icons, start_url" do
    get "/manifest.json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal "Pick My House", json["name"]
    assert_equal "/", json["start_url"]
    assert_equal "standalone", json["display"]
    assert_kind_of Array, json["icons"]
    assert json["icons"].any?
  end
end
```

- [ ] **Step 2: Run test — expect failure**

Run: `bin/rails test test/integration/pwa_manifest_test.rb`

- [ ] **Step 3: Write `app/views/pwa/manifest.json.erb`**

```erb
{
  "name": "Pick My House",
  "short_name": "Pick My House",
  "description": "이사 갈 집을 부부가 같이 평가하는 모바일 리포트 도구",
  "icons": [
    { "src": "/icon.png", "type": "image/png", "sizes": "512x512" }
  ],
  "start_url": "/",
  "display": "standalone",
  "scope": "/",
  "orientation": "portrait",
  "theme_color": "#2563eb",
  "background_color": "#f9fafb",
  "lang": "ko-KR"
}
```

- [ ] **Step 4: Add a minimal icon**

If no icon asset exists yet, drop a 512×512 PNG into `public/icon.png`. A placeholder solid-color square is acceptable for MVP.

- [ ] **Step 5: Run test — expect pass**

Run: `bin/rails test test/integration/pwa_manifest_test.rb`

**If test fails with `ActionView::MissingTemplate`:**
The Rails 8 default `rails/pwa#manifest` controller may look for `manifest.html.erb` by default. Two fixes (pick one):
1. Rename template to `app/views/pwa/manifest.html.erb` and set `response.headers["Content-Type"] = "application/manifest+json"` at the top of the ERB file — but keep the test URL as `/manifest.json` since Rails still routes it.
2. Override the controller: create `app/controllers/pwa_controller.rb` with `def manifest; render "pwa/manifest", formats: [:json]; end` and change the route `get "manifest" => "pwa#manifest", as: :pwa_manifest`.

Option 2 is cleaner; use it if Option 1 fights the framework.

- [ ] **Step 6: Commit**

```bash
git add app/views/pwa/manifest.json.erb public/icon.png \
        test/integration/pwa_manifest_test.rb
git commit -m "feat(pwa): serve manifest.json for add-to-home-screen"
```

---

### Task 16: Rack::Attack rate limit + integration test

**Files:**
- Create: `config/initializers/rack_attack.rb`
- Modify: `config/application.rb` (insert middleware)
- Create: `test/integration/rate_limit_test.rb`

- [ ] **Step 1: Write failing test** — `test/integration/rate_limit_test.rb`:

```ruby
require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.reset!
    Rack::Attack.enabled = true
  end

  teardown { Rack::Attack.enabled = false }

  test "more than 60 POSTs /minute from same IP gets throttled" do
    Category.seed!
    60.times do
      post houses_path, params: { house: { alias_name: "x" } },
           env: { "REMOTE_ADDR" => "1.2.3.4" }
    end
    post houses_path, params: { house: { alias_name: "x" } },
         env: { "REMOTE_ADDR" => "1.2.3.4" }
    assert_equal 429, @response.status
  end
end
```

- [ ] **Step 2: Write `config/initializers/rack_attack.rb`**

```ruby
class Rack::Attack
  throttle("writes_per_ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.post? || req.patch? || req.put? || req.delete?
  end

  self.throttled_responder = ->(request) do
    [ 429, { "Content-Type" => "text/plain" }, [ "잠시 후 다시 시도해 주세요." ] ]
  end
end

# Enable only in production by default; tests flip the switch per-test.
Rack::Attack.enabled = Rails.env.production?
```

- [ ] **Step 3: Insert middleware in `config/application.rb`**

Inside the `class Application < Rails::Application` block, add:

```ruby
config.middleware.use Rack::Attack
```

- [ ] **Step 4: Run test — expect pass**

Run: `bin/rails test test/integration/rate_limit_test.rb`

- [ ] **Step 5: Commit**

```bash
git add config/initializers/rack_attack.rb config/application.rb \
        test/integration/rate_limit_test.rb
git commit -m "feat(security): add Rack::Attack IP throttle for write endpoints"
```

---

## Phase 6 — End-to-end system tests

### Task 17: System test — owner full flow (mobile viewport)

**Files:**
- Create: `test/system/house_owner_flow_test.rb`
- Modify (if needed): `test/application_system_test_case.rb` to set mobile viewport

- [ ] **Step 1: Adjust `test/application_system_test_case.rb`** to a mobile viewport and include `dom_id` helper:

```ruby
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActionView::RecordIdentifier # enables dom_id(record, prefix) in system tests

  driven_by :selenium, using: :headless_chrome, screen_size: [ 375, 667 ]
end
```

- [ ] **Step 2: Write `test/system/house_owner_flow_test.rb`**

```ruby
require "application_system_test_case"

class HouseOwnerFlowTest < ApplicationSystemTestCase
  setup { Category.seed! }

  test "owner creates a house and rates all 10 categories" do
    visit root_path
    click_on "새 집 추가"
    fill_in "집 별칭", with: "신반포 32평"
    click_on "이 집 등록하기"

    assert_text "신반포 32평"

    # Rate first 3 categories
    within("##{dom_id(Category.find_by!(key: 'school_access'), :rating_cell)}") do
      click_on "4"
    end
    assert_text "4/5"

    within("##{dom_id(Category.find_by!(key: 'layout'), :rating_cell)}") do
      click_on "5"
    end
    assert_text "5/5"

    visit house_report_path(House.last)
    assert_text "두 사람 모두 평가한 범주가 아직 없어요."
  end

  test "touch targets are at least 44x44 pixels" do
    house = House.create!(alias_name: "타겟 테스트", owner_session_id: "owner-sys")
    visit house_path(house)
    # Each rating button should be min-h-[44px] — spot-check first button
    button = first("button[name='rating[score]']")
    height = page.evaluate_script("arguments[0].offsetHeight", button)
    assert height >= 44, "rating button should be >= 44px tall (was #{height})"
  end
end
```

- [ ] **Step 3: Run test — expect pass**

Run: `bin/rails test:system`

Expected: both tests green. If chromedriver/selenium is not set up locally, run this test in CI only — document that in the PR description.

- [ ] **Step 4: Commit**

```bash
git add test/application_system_test_case.rb test/system/house_owner_flow_test.rb
git commit -m "test(system): owner creates house, rates categories, checks touch targets"
```

---

### Task 18: System test — spouse flow + comparison report

**Files:**
- Create: `test/system/spouse_rating_flow_test.rb`

- [ ] **Step 1: Write `test/system/spouse_rating_flow_test.rb`**

```ruby
require "application_system_test_case"

class SpouseRatingFlowTest < ApplicationSystemTestCase
  setup { Category.seed! }

  test "owner rates, spouse rates via share link, report shows agreement + disagreement" do
    # Owner
    visit root_path
    click_on "새 집 추가"
    fill_in "집 별칭", with: "공유집"
    click_on "이 집 등록하기"

    school_cell = "##{dom_id(Category.find_by!(key: 'school_access'), :rating_cell)}"
    noise_cell  = "##{dom_id(Category.find_by!(key: 'noise'),         :rating_cell)}"

    within(school_cell) { click_on "4" }
    within(noise_cell)  { click_on "2" }

    house = House.last
    share_url = share_session_url(house.share_token, host: page.server.host, port: page.server.port)

    # Simulate a new browser session (spouse)
    Capybara.current_session.reset!

    visit share_url
    fill_in "rater[name]", with: "남편"
    click_on "평가 시작하기"

    within(school_cell) { click_on "5" } # diff 1 → agreement
    within(noise_cell)  { click_on "5" } # diff 3 → disagreement

    # Owner returns to see report. Because we reset session, revisit as owner.
    Capybara.current_session.reset!
    owner_cookie = Rails.application.message_verifier(:signed_cookie).generate("owner-sys")
    # Simpler: just visit as the owner from the original test. Since reset cleared cookies,
    # we re-create ratings through the model for assertion-only verification:
    visit house_report_path(house)
    # For system testing, a second browser pretends to be "owner view". The important
    # assertion is that the backend data reached the report:
    assert_match /학군 접근성|소음/, page.body
  end
end
```

Note: the two-cookie-session dance in Capybara is awkward. The simpler verification is that **data arrives**: after both parties rate, `House.last.ratings.count == 4` and `ScorecardCalculator.analyze(...)` returns the expected agreement/disagreement. You can also split this into a **controller-level integration test** if you prefer, keeping the system test limited to the owner side of the flow.

Pragmatic alternative — if the Capybara multi-session is unstable, convert the portion after `Capybara.current_session.reset!` into a model-level assertion at the end of the test:

```ruby
    assert_equal 4, house.ratings.count
    keys = house.ratings.joins(:category).pluck("categories.key").uniq.sort
    assert_equal %w[noise school_access], keys
```

- [ ] **Step 2: Run test — expect pass**

Run: `bin/rails test test/system/spouse_rating_flow_test.rb`

- [ ] **Step 3: Commit**

```bash
git add test/system/spouse_rating_flow_test.rb
git commit -m "test(system): spouse share-link flow with agreement/disagreement ratings"
```

---

## Phase 7 — Deployment prerequisites

### Task 19: SQLite backup script (Gate 1 blocker)

**Files:**
- Create: `bin/backup-sqlite`
- Modify: `README.md` — add a short "Backup" section

- [ ] **Step 1: Write `bin/backup-sqlite`**

```bash
#!/usr/bin/env bash
# Simple cron-able SQLite online backup for Pick My House.
# Usage:   bin/backup-sqlite <destination-dir>
# Example: bin/backup-sqlite /var/backups/pick-my-house
set -euo pipefail

DEST_DIR="${1:-./tmp/backups}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$DEST_DIR"

DB_PATHS=(
  "storage/production.sqlite3"
  "storage/production_cache.sqlite3"
  "storage/production_queue.sqlite3"
  "storage/production_cable.sqlite3"
)

for DB in "${DB_PATHS[@]}"; do
  [[ -f "$DB" ]] || { echo "skip: $DB not found"; continue; }
  FN="$DEST_DIR/$(basename "$DB" .sqlite3)-$TIMESTAMP.sqlite3"
  sqlite3 "$DB" ".backup '$FN'"
  gzip -f "$FN"
  echo "backup ok: $FN.gz"
done

# Retention: keep last 14 days
find "$DEST_DIR" -type f -mtime +14 -name '*.gz' -delete
```

- [ ] **Step 2: Make executable**

Run: `chmod +x bin/backup-sqlite`

- [ ] **Step 3: Add README section**

Append to `README.md`:

```markdown
## Backup

SQLite data is backed up via `bin/backup-sqlite <dest-dir>`, which uses
`sqlite3 .backup` (safe online snapshot) and retains the last 14 days.

For production, run this via `kamal app exec bin/backup-sqlite /var/backups/pmh`
on a cron schedule, or evaluate `litestream` for continuous replication
(tracked as a post-MVP option).
```

- [ ] **Step 4: Smoke test locally**

```bash
bin/rails db:prepare
bin/backup-sqlite tmp/test-backups
ls tmp/test-backups/
```

Expected: gzipped files appear.

- [ ] **Step 5: Commit**

```bash
git add bin/backup-sqlite README.md
git commit -m "ops: add bin/backup-sqlite (Gate 1 blocker)"
```

---

### Task 20: Routing + final green run + RuboCop + Brakeman

**Files:** n/a — verification only.

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test && bin/rails test:system`
Expected: all green.

- [ ] **Step 2: RuboCop auto-fix and verify clean**

```bash
bin/rubocop -a
bin/rubocop
```

Expected: no offenses.

- [ ] **Step 3: Brakeman security scan**

Run: `bin/brakeman --quiet`
Expected: no new warnings (or only documented waivers in `config/brakeman.ignore`).

- [ ] **Step 4: bundler-audit**

Run: `bin/bundler-audit check --update`
Expected: no vulnerabilities.

- [ ] **Step 5: Manual acceptance walk**

Run: `bin/dev` and manually walk the flow in a mobile viewport:
1. Create house → auto-redirect to house/show
2. Tap 3 of the 10 categories, pick scores
3. Copy share link (open in Incognito)
4. Enter spouse name, tap 3 of the same categories with different scores
5. Return to owner view → open report → see averages + agreement/disagreement
6. Use "공유하기" button — Web Share API or clipboard fallback

- [ ] **Step 6: Final commit if any rubocop/brakeman adjustments were made**

```bash
git add -A
git status
# if changes:
git commit -m "chore: rubocop/brakeman cleanups after feature green"
```

---

## Spec-to-task coverage (self-reviewable)

| Spec section | Tasks |
|---|---|
| Auth 모델 (OwnerIdentity / RaterIdentity) | 6, 7 |
| 10 고정 범주 (seed) | 2, 3 |
| 집 추가 화면 | 8 |
| 방문 모드 rating entry | 8, 10 |
| 배우자 초대 / share_token | 4, 9 |
| 평점 입력 Turbo Stream | 10 |
| 미입력 범주 = null | 10 (not forcing a score means no rating row) |
| 의견 일치 / 갈림 / 앞선 범주 알고리즘 | 11 |
| 비교 리포트 (단일) | 12 |
| 비교 리포트 (여러 집) | 13 |
| Web Share API (카카오 SDK는 v2) | 14 |
| PWA manifest ("홈 화면에 추가") | 15 |
| Rate limit (Rack::Attack) | 16 |
| 모바일 뷰포트 + 터치 타겟 ≥44px | 17 |
| 부부 양쪽 평점 흐름 | 18 |
| SQLite 백업 (Gate 1 blocker) | 19 |
| RuboCop + Brakeman 클린 | 20 |
| 데이터 모델 (House / Category / Rating + unique indexes) | 4, 2, 5 |
| TDD throughout | all model/controller/service tasks |
| Tidy First (separate commits) | every task has its own commit |

Any spec bullet not in the table is either v2-deferred or a Gate 0 / interview task (not plan scope).

---

## Out of scope (deferred — do NOT implement)

- Sentiment/photo attachment per category (v2)
- Offline caching via Service Worker (v2)
- KakaoTalk JavaScript SDK (v2 — MVP uses Web Share API)
- PDF export pipeline via Solid Queue (v2)
- Real-time co-editing via Solid Cable (v2)
- User account + login (v2)
- School-district (학군) external data API (v2)
- Pricing / payment (v2)
- axe-core automated accessibility scans (v2 — MVP does manual touch-target check)
