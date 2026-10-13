# Contributing

Issues and pull requests are welcome.

## Workflow

- Work on a branch named `feature/...`, `fix/...` or `chore/...` and open a pull request against `main`.
  Do not push to `main` directly.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`,
  `test:`, `chore:`).
- CI must be green before a pull request is merged: lint, tests and the image build.
- Add or update tests in `tests/` together with every change to `run.sh` or `push-states.sh`.

## Checks

All checks run in Docker, nothing is installed locally:

```sh
docker run --rm -v "$PWD":/data cytopia/yamllint:1 -c .yamllint.yaml .
docker run --rm -v "$PWD":/mnt koalaman/shellcheck:v0.10.0 dmarc-viewer/run.sh dmarc-viewer/push-states.sh scripts/changelog-section.sh tests/run.sh
docker run --rm -v "$PWD":/mnt koalaman/shellcheck:v0.10.0 -s bats tests/*.bats
docker run --rm -v "$PWD":/mnt koalaman/shellcheck:v0.10.0 -s bash -e SC2034 tests/helpers.bash
docker run --rm -i hadolint/hadolint:v2.12.0 < dmarc-viewer/Dockerfile
docker run --rm -i hadolint/hadolint:v2.12.0 < tests/Dockerfile
docker run --rm -v "$PWD":/repo:ro zricethezav/gitleaks:v8.21.2 detect --source /repo --no-banner
docker run --rm -v "$PWD":/repo:ro aquasec/trivy:0.58.0 fs --scanners secret,misconfig --severity LOW,MEDIUM,HIGH,CRITICAL --ignorefile /repo/.trivyignore --exit-code 1 /repo
sh tests/run.sh
```

## Updating the upstream viewer

Review the upstream diff first. Then change `COMMIT` in `dmarc-viewer/Dockerfile`, refresh the JSON fixtures in
`tests/helpers.bash` against the new upstream code and add a changelog entry. The add-on version only changes at a release.

## Releasing

1. Move the `[Unreleased]` entries in `CHANGELOG.md` under a new heading `## [X.Y.Z] - YYYY-MM-DD`.
2. Set `version: "X.Y.Z"` in `dmarc-viewer/config.yaml` (during development it is `X.Y.Z-dev`).
3. Merge that through a pull request.
4. Tag the merge commit on `main` as `vX.Y.Z` and push the tag. The release workflow checks the tag format, that it is on
   `main`, that it matches the add-on version and that the tests pass,
   and then publishes the GitHub release with the changelog section as notes.

## Repository settings

These settings live on GitHub, not in the repository. They are listed here so they can be restored:

- `main` is protected: pull request required (0 approvals), the checks `lint`, `test` and `build` must pass and be up
  to date, conversations must be resolved, no force pushes, no deletion, and the rules apply to administrators too.
- Tags `v*` cannot be deleted or moved (ruleset "release tags are immutable").
- Only merge commits are allowed, and merged branches are deleted automatically.
- Actions: the default workflow token is read-only, workflows cannot approve pull requests, and only GitHub's own
  actions plus `docker/setup-buildx-action` and `docker/build-push-action` are allowed.
- Dependabot alerts and security updates, secret scanning with push protection, and private vulnerability reporting
  are enabled.
