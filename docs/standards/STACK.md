# Architecture

System architecture, technology stack, and implementation patterns.

## Project Overview

Rails monolith with Hotwire (Turbo + Stimulus), SQLite, and Solid Cache/Queue/Cable.
Exact versions: see `Gemfile.lock` (Rails), `.ruby-version` (Ruby).

## Technology Stack

### Backend

- **Framework**: Ruby on Rails
- **Asset Pipeline**: Propshaft (Rails 8 default, replaces Sprockets)
  - **importmap-rails**: Default JS management without Node.js bundling
  - Use `bin/importmap pin <package>` to add JS dependencies

### Frontend

- **Strategy**: Hotwire (Turbo + Stimulus)
  - **Turbo**: SPA-like navigation and partial page updates
  - **Turbo Frames** for pagination/tabs (no full page reloads)
  - **Turbo Streams** for partial updates (e.g., `InspectionChecksController` upserts a row + domain count)
  - **Stimulus**: Pure JavaScript controllers, data-attribute conventions (`data-controller`, `data-action`, `data-*-target`)
  - **No TypeScript** — use only JavaScript
- **Styling**: TailwindCSS
- **Reusable UI**: Plain ERB partials under `app/views/shared/` (e.g., `_severity_badge.html.erb`, `_domain_section.html.erb`). ViewComponent is not used in this MVP.

### Testing

- **Framework**: Minitest (Rails default)
- **System Tests**: Rails built-in system tests with Capybara
- **Fixtures**: Rails fixtures for test data

### Database & Infrastructure

- **SQLite** with Solid Trifecta (no Redis or external services needed):
  - **Solid Cache**: Database-backed cache (replaces Redis/Memcached)
  - **Solid Queue**: Database-backed job backend (replaces Sidekiq/Resque)
  - **Solid Cable**: Database-backed Action Cable adapter (replaces Redis pub/sub)
- **Multi-DB configuration**: Each Solid service uses a separate SQLite file to avoid write lock contention. Configure in `config/database.yml` with `cache:`, `queue:`, and `cable:` entries (Rails 8 default).

### Deployment

- **Proxy**: Thruster (Go-based proxy wrapping Puma on port 80, automatic HTTP/2, compression, X-Sendfile, asset caching)
- **Tool**: Kamal 2 (primary) or Docker Compose (local)
- **Container**: Optimized Dockerfile, mount `/rails/storage` for SQLite/ActiveStorage/Solid services, run as non-root (UID/GID 1000)
- **CI/CD**: GitHub Actions (automated testing, linting, security checks)

### Background Jobs

- **Backend**: Solid Queue (database-backed, no Redis)
- **Worker**: `bin/jobs` (Rails 8 default)
- **Status**: No application jobs in this MVP. Solid Queue is configured and ready when one is needed.
- **Kamal**: Deploy as separate `job` role for resource isolation when introduced.

## Architecture Patterns

### POROs in `app/lib/`

Pure-function value objects live under `app/lib/` (e.g., `Checklist`, `HouseSummary`). Prefer this over service objects for code that doesn't touch the database — `HouseSummary` accepts a House and an array of `InspectionCheck`s and returns counts/lists, which makes it trivial to test in memory.

### Caching Strategy

Solid Cache is the configured backend. Reach for fragment caching when a view component is repeatedly rendered without changing — but do not pre-cache speculatively. None of the current views warrant caching.

## Hotwire Best Practices

### Turbo Frame Usage

```erb
<%= turbo_frame_tag "items" do %>
  <%= render @items %>
<% end %>
```

### Turbo Stream Response

```ruby
# controller
respond_to do |format|
  format.turbo_stream
  format.html
end
```

### Stimulus Controller Naming

- `data-controller="search"`
- `data-action="input->search#submit"`
- `data-search-target="input"`

## UI/Frontend Rules

- **Mobile first**: Designed for the visitor's phone at 375×667. Touch targets ≥ 44×44 px (see `test/system/accessibility_touch_targets_test.rb`).
- **Severity color + text**: Never rely on color alone — every severity badge pairs a color with the Korean label (양호/주의/심각). See `app/views/shared/_severity_badge.html.erb`.
- **Reuse existing partials**: When adding a new section, follow `_domain_section.html.erb` and `_severity_badge.html.erb` for consistency.

## Internationalization (i18n)

UI is Korean only, hardcoded in ERB views. Multi-language is out of scope (see the defect-checklist spec). `config/locales/en.yml` is retained for Rails default validation messages.

## Rails 8 — Do NOT Use (Removed/Deprecated)

- **Classic Autoloader**: Completely removed. Use Zeitwerk only.
- **Rails UJS**: Removed. Use Turbo instead.
- **Sprockets**: Replaced by Propshaft. Do not add `sprockets` gem.
- **Webpack/Webpacker**: Use importmap-rails instead.
- **`params.require().permit()` for new code**: Prefer `params.expect()`.
