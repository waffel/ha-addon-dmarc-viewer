# Contributing

Issues and pull requests are welcome.

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`).
- Run the checks before opening a pull request (all of them run in Docker, nothing is installed locally):

  ```sh
  docker run --rm -v "$PWD":/data cytopia/yamllint:1 -c .yamllint.yaml .
  docker run --rm -v "$PWD":/mnt koalaman/shellcheck:v0.10.0 dmarc-viewer/run.sh
  docker run --rm -i hadolint/hadolint:v2.12.0 < dmarc-viewer/Dockerfile
  ```

- Updating the upstream viewer means reviewing the upstream diff first, then changing `COMMIT` in
  `dmarc-viewer/Dockerfile` and the add-on `version` in `dmarc-viewer/config.yaml`, and adding a changelog entry.
