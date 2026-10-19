#!/usr/bin/env bash
#
# Run shellcheck and the stubbed tests for every setup script in a Linux
# container. Nothing is installed, cloned or downloaded: brew, git, ssh,
# claude and friends are replaced by stubs in tests/stubs that only log what
# they were asked to do. The container has no network and the repo is
# mounted read-only.
#
# Usage:
#   tests/run.sh             shellcheck + all tests
#   tests/run.sh apps        only tests whose file name contains "apps"
#   tests/run.sh --shell     open a shell in the test image

set -eu

cd "$(dirname "$0")/.."
IMAGE=macsetup-tests

if ! docker info >/dev/null 2>&1; then
  echo "Docker isn't running. Start Docker Desktop and try again." >&2
  exit 1
fi

docker build -q -t "$IMAGE" tests >/dev/null

if [ "${1:-}" = "--shell" ]; then
  exec docker run --rm -it --network none -v "$PWD:/repo:ro" "$IMAGE" bash
fi
exec docker run --rm --network none -v "$PWD:/repo:ro" "$IMAGE" bash tests/suite.sh "$@"
