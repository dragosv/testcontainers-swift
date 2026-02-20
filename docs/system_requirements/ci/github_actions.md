# GitHub Actions

Testcontainers for Swift works out of the box on GitHub-hosted Ubuntu runners, which have Docker pre-installed.

## Ubuntu runners

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: "6.1"

      - name: Build
        run: swift build

      - name: Run tests
        run: swift test
```

No additional Docker setup is required — the runner already has Docker installed and running.

## macOS runners

macOS runners do **not** ship with Docker. You must install Docker Desktop (or an alternative like Colima) before running tests:

```yaml
name: Tests (macOS)
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Install Docker
        run: |
          brew install --cask docker
          open /Applications/Docker.app
          # Wait for Docker to start
          while ! docker system info > /dev/null 2>&1; do sleep 1; done

      - name: Build
        run: swift build

      - name: Run tests
        run: swift test
```

## Caching

Cache the `.build` directory to speed up subsequent builds:

```yaml
- uses: actions/cache@v3
  with:
    path: .build
    key: ${{ runner.os }}-spm-${{ hashFiles('Package.resolved') }}
    restore-keys: |
      ${{ runner.os }}-spm-
```

## Tips

- **Timeouts**: Container image pulls and startup can be slow on first run. Set generous job timeouts.
- **Concurrency**: GitHub Actions Ubuntu runners have 2 vCPUs. If running many containers in parallel, consider a larger runner.
- **Docker layer caching**: Use third-party actions like `docker/build-push-action` with caching to speed up image builds if your tests build custom images.
