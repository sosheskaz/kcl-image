#!/usr/bin/env bash

set -euo pipefail

check_dependency() {
  local dep=$1
  which "$dep" &>/dev/null || {
    echo "$dep is not installed. Please install it" >&2
    exit 1
  }
}

check_dependency crane
check_dependency docker
check_dependency sed
check_dependency awk
check_dependency git
check_dependency sort
check_dependency grep
export DOCKER_BUILDKIT=1

PLATFORMS=(linux/amd64 linux/arm64)
PLATFORMS_JOINED="$(IFS=,; echo "${PLATFORMS[*]}")"

# Versions can be added here if we decide to break compatibility with this script
SKIP_VERSIONS='^v(0\.[4-9]\..*)$'
ALL_TAGS=($(git ls-remote --tags https://github.com/kcl-lang/kcl | awk '{print $2}' | grep -E '^refs/tags/v[0-9\.]+$' | sed 's/^refs\/tags\///g' | grep -Ev "$SKIP_VERSIONS" | sort -V))

IMAGE_REPO=ghcr.io/sosheskaz/kcl-image

let missing_platforms=0 || true
for tag in "${ALL_TAGS[@]}"; do
  let missing_platforms=0 || true

  for platform in "${PLATFORMS[@]}"; do
    if ! false #crane manifest --platform="$platform" "${IMAGE_REPO}:${tag}" &>/dev/null
    then
      let missing_platforms+=1
    fi
    echo "repo $IMAGE_REPO missing platform $platform for tag $tag" >&2
  done

  if [ $missing_platforms -eq 0 ]; then
    echo "tag $tag has all platforms"
  else
    tags_to_build+=("$tag")
  fi
done
echo "tags to build: ${tags_to_build[*]}"

for tag in "${tags_to_build[@]}"; do
  BUILDKIT_ENABLE=1 docker buildx build --platform "$PLATFORMS_JOINED" -t "${IMAGE_REPO}:${tag}" --pull --push --build-arg KCL_VERSION="${tag}" .
done
