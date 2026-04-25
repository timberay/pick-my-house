# Pick My House

A mobile-first Rails 8 app for inspecting potential homes during site visits. Walk through 50 fixed defect-check items across 10 domains (water, electric, mold, windows, smell, noise, heating, security, finish, surround) and rate each as 양호 / 주의 / 심각 with an optional one-line memo. The summary screen surfaces severe and warning items so the visitor can compare candidate homes after the visit.

The UI is Korean only. Owners are identified by a signed `owner_session_id` cookie — no login, no sharing — so a single device equals a single owner.

The defect checklist itself lives in [`config/checklist.yml`](config/checklist.yml).

## Tech Stack

- **Ruby** 3.4.8 / **Rails** ~> 8.1.3
- **Database**: SQLite with Solid Trifecta (Solid Cache, Solid Queue, Solid Cable)
- **Frontend**: Hotwire (Turbo + Stimulus), TailwindCSS, Importmap
- **Asset Pipeline**: Propshaft
- **Rate Limiting**: rack-attack (write endpoints, 10/min/IP)
- **Deployment**: Kamal 2, Thruster, Docker

## Getting Started

```bash
bin/setup    # Install dependencies, prepare database
bin/dev      # Start development server (Puma + Tailwind watcher)
```

## Development

```bash
bin/ci                       # Full pipeline: setup, lint, security, tests, seed check
bin/rails test               # Unit / request / integration tests
bin/rails test:system        # System tests (Capybara + Selenium, mobile viewport)
bin/rubocop                  # Lint check
bin/rubocop -a               # Auto-fix lint
bin/brakeman --quiet         # Security audit
bin/bundler-audit            # Dependency audit
bin/importmap audit          # JS dependency audit
```

## Deployment

Deployed via [Kamal 2](https://kamal-deploy.org). See `config/deploy.yml` for configuration.

```bash
bin/kamal setup    # First deploy
bin/kamal deploy   # Subsequent deploys
```

## Documentation

Detailed standards are in [`docs/standards/`](docs/standards/):

| Document | Description |
|----------|-------------|
| [RULES.md](docs/standards/RULES.md) | DRY, Tidy First, documentation rules |
| [STACK.md](docs/standards/STACK.md) | Architecture, tech stack, patterns |
| [TOOLS.md](docs/standards/TOOLS.md) | Dev commands, environment config |
| [QUALITY.md](docs/standards/QUALITY.md) | Testing, security, accessibility |
| [WORKFLOW.md](docs/standards/WORKFLOW.md) | 4-Phase pipeline for new feature work |
