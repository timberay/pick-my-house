# Tool Definition

Development tools, commands, and environment configuration.

## Common Commands

### Setup & Server

```bash
bin/setup                    # Full project setup
bin/dev                      # Run dev server (Puma + CSS/JS watchers)
bin/rails console            # Rails console
```

### Database

```bash
bin/rails db:prepare         # Create/migrate DB
bin/rails db:reset           # Reset DB (dev only)
bin/rails db:seed            # Load seed data
bin/rails db:migrate         # Run pending migrations
bin/rails db:rollback        # Rollback last migration
```

### Linting & Code Quality

```bash
bin/rubocop                  # Check style (rubocop-rails-omakase)
bin/rubocop -a               # Auto-fix
```

### Security Audits

```bash
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit
bin/importmap audit
```

### Testing

```bash
bin/rails test                              # Unit / request / integration
bin/rails test:system                       # Capybara + Selenium system tests (mobile viewport 375×667)
bin/rails test test/models/foo_test.rb      # Single file
bin/rails test test/models/foo_test.rb:42   # Single test by line
```

### CI Pipeline

```bash
bin/ci    # Runs: setup, rubocop, security audits, tests, seed check
```

`bin/ci` is included by Rails 8 `rails new`. Customize it to add project-specific checks (e.g., seed validation).

### Assets & Dependencies

```bash
bin/rails assets:precompile  # Build production assets
bin/importmap pin <package>  # Add JS dependency via importmap
```

### Cache & Background Jobs

```bash
bin/rails solid_cache:clear  # Clear Solid Cache
bin/jobs                     # Start Solid Queue worker (Rails 8 default)
```

### Deployment

```bash
bin/kamal setup              # Initial server provisioning
bin/kamal deploy             # Zero-downtime deployment
bin/kamal app logs           # View application logs
bin/backup-sqlite <dir>      # Online SQLite backup of all 4 production DBs (primary/cache/queue/cable) with gzip + 14-day retention
```

## Environment Configuration

This MVP has no `.env` file or environment-driven feature flags — Rails reads `RAILS_ENV` from the runtime, and secrets live in Rails credentials.

### Credentials Management

```bash
rails credentials:edit --environment development
```

- Never commit sensitive information to `.env` file
- Use Rails credentials for API keys, secrets, and sensitive configuration
