# Pick My House

A Rails 8 application for house picking/selection.

## Tech Stack

- **Ruby** 3.4.8 / **Rails** ~> 8.1.3
- **Database**: SQLite with Solid Trifecta (Solid Cache, Solid Queue, Solid Cable)
- **Frontend**: Hotwire (Turbo + Stimulus), TailwindCSS, Importmap
- **Asset Pipeline**: Propshaft
- **Deployment**: Kamal 2, Thruster, Docker

## Getting Started

```bash
bin/setup    # Install dependencies, prepare database
bin/dev      # Start development server
```

## Development

```bash
bin/rails test               # Run all tests
bin/rubocop                  # Lint check
bin/rubocop -a               # Auto-fix lint
bin/brakeman --quiet         # Security audit
bin/bundler-audit            # Dependency audit
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

## Backup

SQLite data is backed up via `bin/backup-sqlite <dest-dir>`, which uses
`sqlite3 .backup` (safe online snapshot) and retains the last 14 days.

For production, run this via `kamal app exec bin/backup-sqlite /var/backups/pmh`
on a cron schedule, or evaluate `litestream` for continuous replication
(tracked as a post-MVP option).
