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

Repository settings (not stored in the repo): protect `main`, require a pull request and the CI checks `lint`, `test`
and `build`.
