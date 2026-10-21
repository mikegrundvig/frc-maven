#!/usr/bin/env bash
# Publishes a release of the FRC libraries into this repository and commits it (README.md, Making a
# release). Usage, from anywhere:
#
#   ./release.sh <folder>           the libraries' clones are <folder>/model, localization, pitwall, runtime
#   ./release.sh --push <folder>    the same, then git push
#
# Each library runs its own publishToFrcMaven (every check, then the publication into this clone),
# in dependency order, reading the ones before it from this clone rather than from Pages.
# GRADLEW=<command> runs another wrapper around ./gradlew in each clone (one that caps memory, say).
set -euo pipefail
gradlew="${GRADLEW:-./gradlew}"

push=false
if [[ "${1:-}" == "--push" ]]; then
  push=true
  shift
fi
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 [--push] <folder holding model/, localization/, pitwall/, runtime/>" >&2
  exit 2
fi
libs="$(cd "$1" && pwd)"
repo="$(cd "$(dirname "$0")" && pwd)"

version=""
for name in model localization pitwall runtime; do
  catalog="$libs/$name/gradle/libs.versions.toml"
  if [[ ! -f "$catalog" ]]; then
    echo "No $name clone at $libs/$name" >&2
    exit 1
  fi
  theirs="$(sed -n 's/^frc-libs *= *"\(.*\)"/\1/p' "$catalog")"
  if [[ -z "$version" ]]; then
    version="$theirs"
  elif [[ "$theirs" != "$version" ]]; then
    echo "$name's frc-libs is $theirs, the model's $version: a release is one version for all of them" >&2
    exit 1
  fi
done
echo "Releasing $version from $libs into $repo"

for name in model localization pitwall runtime; do
  echo "== $name"
  (cd "$libs/$name" && $gradlew publishToFrcMaven "-PfrcMavenDir=$repo" "-PfrcMaven=file://$repo")
done

cd "$repo"
git add com frc
if git diff --cached --quiet; then
  echo "Nothing changed: $version is published as it was."
else
  git commit -q -m "Release $version"
  echo "Committed: $(git log --oneline -1)"
fi
if $push; then
  git push
else
  echo "Not pushed. To put it online: git -C $repo push"
fi
