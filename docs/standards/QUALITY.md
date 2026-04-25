# Evaluation Criteria

Testing strategy, security standards, code quality, accessibility, and performance guidelines.

## Testing Strategy

### Framework

- **Unit / request / integration**: Minitest (Rails 8 default)
- **System tests**: Capybara + Selenium, mobile viewport 375×667 (`test/application_system_test_case.rb`)

### Test Pyramid (maintain this ratio)

- **Unit** (majority): Models, POROs in `app/lib/`, helpers
- **Request / Integration** (moderate): Controller behavior, rate-limit integration
- **System** (few): Major user scenarios only — currently inspection flow, deletion, touch targets

### Test Coverage

- Every new feature must include corresponding tests
- Bug fixes must include a regression test

## Code Style

- **Ruby**: rubocop-rails-omakase (`bin/rubocop`, auto-fix with `-a`)
- **CSS**: Tailwind utility classes; avoid hand-written CSS

## Security Best Practices

### CSRF Protection

Maintain Rails default settings. Never disable CSRF.

### Parameter Handling

```ruby
# Rails 8 recommended — raises if key is missing
params.expect(article: [:title, :body, :published])

# For optional parameters, use permit or fetch with default
params.permit(:sort_by, :page)
params.fetch(:page, 1)
```

### ReDoS Prevention

`Regexp.timeout = 1` is set by default in Rails 8.

### XSS Prevention

- Use `sanitize` helper for user-generated content
- Configure `content_security_policy.rb`
- Never use `raw` or `html_safe` on untrusted input

### Rate Limiting

`Rack::Attack` is configured in `config/initializers/rack_attack.rb`. The MVP throttles every write endpoint (POST/PATCH/PUT/DELETE) at 10/min/IP and returns a Korean 429 page.

### Credentials

- Use `rails credentials:edit` for secrets
- Never commit `.env` files with real credentials

## Accessibility Standards

### Status Indicators

Severity badges pair color with the Korean label (양호/주의/심각). Never rely on color alone to convey status. Add ARIA labels for screen readers where the label is not visible text.

### Keyboard Navigation

Ensure all interactive elements (severity buttons, form inputs, links) are reachable via Tab key.

### Responsive Design

Mobile-first using TailwindCSS breakpoints. Touch targets must be at least 44×44 px — enforced by `test/system/accessibility_touch_targets_test.rb`.

## Performance Guidelines

### Prevent N+1 Queries

Use `includes`, `preload`, or `eager_load` when iterating associations. The summary screen renders one query per house — keep it that way.

### Database Indexing

Add indexes for columns used in lookup or uniqueness. Current indexes: `houses(owner_session_id)`, unique `inspection_checks(house_id, item_key)`.

### Fragment Caching

Reach for fragment caching only when a view is repeatedly rendered without changing. Not currently warranted.

## Evidence-Driven Self-Diagnosis

You have no eyes or memory beyond what you explicitly capture. Logs and screenshots
are the only evidence you can use to diagnose problems autonomously — if you didn't
record it, it doesn't exist for you.

### Why This Matters

- You cannot re-observe a past UI state or a transient error after it disappears.
- Detailed evidence lets you form hypotheses and verify fixes without asking humans.
- Vague or missing logs force you to guess, which violates the TDD principle of
  working from facts.

### What to Capture

| Situation | What to Record |
|-----------|---------------|
| Running a command | Full stdout/stderr output, not a summary |
| UI change | Screenshot before AND after |
| Test failure | Complete error message, stack trace, and the test command used |
| Unexpected behavior | Steps to reproduce, expected vs. actual result |
| External API call | Request payload, response status, and response body |

For diagnosis workflow, follow the `systematic-debugging` skill.

## Code Review Checklist

### Automated (by `bin/ci`)

- [ ] All tests pass (`bin/rails test`)
- [ ] No linting errors (`bin/rubocop`)
- [ ] No security warnings (`bin/brakeman`)
- [ ] No dependency vulnerabilities (`bin/bundler-audit`)
- [ ] No JS advisories (`bin/importmap audit`)

### Manual Review

- [ ] Structural and behavioral changes are in separate commits
- [ ] System tests pass for any UI change (`bin/rails test:system`)
- [ ] New features have corresponding tests
- [ ] Accessibility (≥44×44 px touch targets, color+text) for UI changes
- [ ] No N+1 queries introduced

## Pre-commit Failure Recovery

When a pre-commit hook (rubocop, test, etc.) fails, fix it yourself and retry — do not stop and ask the user.

- **Rubocop violation**: Run `bin/rubocop -a` to auto-fix, then re-stage and re-commit
- **Test failure**: Diagnose the failing test, fix the code, verify with `bin/rails test`, then re-commit
- **Multiple issues**: Fix rubocop first, then tests, then re-commit
