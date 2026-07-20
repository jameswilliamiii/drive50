# Contributing to Drive50

Thanks for your interest in Drive50! This is a small Rails app for tracking
supervised driving hours. Contributions — bug reports, fixes, and features — are
welcome.

## Getting set up

```bash
bin/setup            # installs dependencies, prepares the DB, starts the server
bin/dev              # start the server (default port 3000)
```

Ruby version is pinned in `.ruby-version` (currently 3.3.6). The database is
SQLite3, so there's nothing extra to install.

## Before you open a pull request

CI runs the checks below on every PR, and `main` requires them all to pass
before merging. Run them locally first to get a fast green light:

```bash
bin/rails test            # unit + integration tests
bin/rails test:system     # system tests (browser)
bin/rubocop               # style (Omakase Ruby); bin/rubocop -a to autofix
bin/brakeman --no-pager   # Rails security scan
bin/bundler-audit         # known-vulnerable gem check
bin/importmap audit       # JS dependency vulnerabilities
```

## Pull request workflow

- Branch off `main` — direct pushes to `main` are blocked.
- Keep each PR focused on one change; add tests for new behavior or fixes.
- Open a PR and let CI run. Once all checks are green you can merge (squash is
  preferred to keep history readable).
- Follow the existing code conventions — see [CLAUDE.md](CLAUDE.md) for an
  overview of the architecture (Hotwire, Turbo Streams, Action Cable) and the
  patterns this project follows.

## Reporting bugs and requesting features

Use the issue templates when opening an issue — they prompt for the details that
make a report actionable. For **security** issues, do not open a public issue;
follow [SECURITY.md](SECURITY.md) instead.

## License

By contributing, you agree that your contributions will be licensed under the
project's [O'Saasy License](LICENSE.md).
