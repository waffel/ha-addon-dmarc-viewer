# ADR-0001: Use Git flow for branches and releases

- Status: Accepted
- Date: 2026-10-14

## Context

Until now every change went from a short-lived branch straight into `main`, and the branch prefixes were `feature/`,
`fix/` and `chore/`. `main` was at the same time the integration branch and the branch releases are tagged on, so
an unreleased change and the last release could not be told apart by branch. The prefixes also differed from the
Git flow names the maintainer uses in all other projects, which makes the rules harder to guess for contributors.

## Decision

The repository uses [Git flow](https://nvie.com/posts/a-successful-git-branching-model/).

| Branch | Created from | Merged into | Purpose |
|---|---|---|---|
| `main` | - | - | Released code only. Every release is a tag `vX.Y.Z` on `main`. |
| `develop` | `main` | - | Integration branch and default branch of the repository. |
| `feature/<short-description>` | `develop` | `develop` | Features, documentation, tests, CI and other non-bugfix changes. |
| `bugfix/<short-description>` | `develop` | `develop` | Fixes for bugs that are not released yet or can wait for the next release. |
| `release/X.Y.Z` | `develop` | `main` | Release preparation: changelog section and add-on version. |
| `hotfix/X.Y.Z` | `main` | `main` | Urgent fix for the released version. |
| `release/X.Y.Z-merge-back` | `main` | `develop` | Brings a release or hotfix back into `develop` and sets the next `-dev` version. |

- Every merge goes through a pull request. `main` and `develop` are protected the same way; the exact settings are
  listed in [CONTRIBUTING.md](../../CONTRIBUTING.md#repository-settings), the release steps under
  [Releasing](../../CONTRIBUTING.md#releasing).
- `<short-description>` is lowercase words joined by hyphens, for example `feature/readme-pitch`.
- Commit messages keep following Conventional Commits. The prefix of the commit type (`docs:`, `chore:`, ...) is
  independent of the branch prefix: a `docs:` commit lives on a `feature/` branch.
- Dependabot branches (`dependabot/...`) are generated and target `develop`.
- Merged branches are deleted automatically.

## Consequences

- `main` always matches the latest release, `develop` shows what the next release contains.
- A release needs two pull requests: `release/X.Y.Z` into `main`, and a merge-back branch into `develop` (`main` is
  protected, so the merge-back cannot come from `main` directly).
- The release workflow is unchanged: it already refuses tags that are not on `main`.
- The prefixes `fix/` and `chore/` are no longer used for new branches. CI builds pushes to `main` and `develop` and
  every pull request, whatever its branch name.
