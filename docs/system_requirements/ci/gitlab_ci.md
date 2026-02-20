# GitLab CI/CD

Testcontainers for Swift works in GitLab CI/CD using the Docker-in-Docker (DinD) service.

## Basic configuration

```yaml
test:
  image: swift:6.1
  services:
    - docker:dind
  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
  script:
    - swift build
    - swift test
```

The `docker:dind` service runs a Docker daemon alongside your build container. Setting `DOCKER_HOST` tells Testcontainers for Swift where to find it.

## With TLS

For secure communication with the DinD service:

```yaml
test:
  image: swift:6.1
  services:
    - docker:dind
  variables:
    DOCKER_HOST: tcp://docker:2376
    DOCKER_TLS_CERTDIR: "/certs"
    DOCKER_CERT_PATH: "/certs/client"
    DOCKER_TLS_VERIFY: "1"
  script:
    - swift build
    - swift test
```

## Caching

Cache Swift packages to speed up builds:

```yaml
test:
  image: swift:6.1
  services:
    - docker:dind
  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
  cache:
    key: spm-$CI_COMMIT_REF_SLUG
    paths:
      - .build/
  script:
    - swift build
    - swift test
```

## Tips

- **Docker image caching**: DinD starts with an empty Docker cache on each job. Pre-pull frequently used images or use a Docker registry mirror.
- **Timeouts**: Set appropriate job timeouts — container image pulls are uncached in DinD.
- **Shared runners**: Shared GitLab runners may have limited resources. Consider using dedicated runners for container-heavy test suites.
