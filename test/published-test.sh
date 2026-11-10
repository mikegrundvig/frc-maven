#!/usr/bin/env bash
# Tests that a published version stays as it is: check-published.sh against a commit of each kind,
# and release.sh against a version that is there or not. Each row runs in a fresh repository holding
# one published version (1.0) of one artifact, a plugin marker, and Visor at the same date.
# Usage, from anywhere: test/published-test.sh
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "${HOME}/.cache"
work="$(mktemp -d "${HOME}/.cache/frc-maven-test.XXXXXX")"
trap 'rm -r -- "$work"' EXIT

artifact=com/michaelgrundvig/frc/frc-robot-model
marker=frc/visor/frc.visor.gradle.plugin
visor=com/michaelgrundvig/frc/visor

git_test() {
  git -c user.name=test -c user.email=test@example.invalid "$@"
}

# A repository with this checkout's scripts and version 1.0 published; it becomes the current folder.
fresh() {
  local repo="$work/$1"
  mkdir -p "$repo"
  cd "$repo"
  git init -q
  cp "$here/release.sh" "$here/check-published.sh" .
  mkdir -p "$artifact/1.0" "$marker/1.0" "$visor/2.0"
  echo jar > "$artifact/1.0/frc-robot-model-1.0.jar"
  echo sum > "$artifact/1.0/frc-robot-model-1.0.jar.sha256"
  echo "<versions>1.0</versions>" > "$artifact/maven-metadata.xml"
  echo sum > "$artifact/maven-metadata.xml.sha256"
  echo pom > "$marker/1.0/frc.visor.gradle.plugin-1.0.pom"
  echo tar > "$visor/2.0/visor-2.0-linux-arm64.tar.gz"
  echo readme > README.md
  git add .
  git_test commit -q -m base
}

commit() {
  git add -A
  git_test commit -q -m change
}

# check-published.sh: each change, committed, and whether the check accepts it (0) or refuses it (1).
new_version() {
  mkdir -p "$artifact/1.1"
  echo jar > "$artifact/1.1/frc-robot-model-1.1.jar"
  echo "<versions>1.0 1.1</versions>" > "$artifact/maven-metadata.xml"
}
metadata_update() {
  echo "<versions>1.0</versions><lastUpdated/>" > "$artifact/maven-metadata.xml"
  echo other > "$artifact/maven-metadata.xml.sha256"
}
outside_versions() { echo changed > README.md; }
overwrite() { echo other > "$artifact/1.0/frc-robot-model-1.0.jar"; }
deleted_file() { rm "$artifact/1.0/frc-robot-model-1.0.jar.sha256"; }
added_to_published() { echo extra > "$artifact/1.0/frc-robot-model-1.0-extra.jar"; }
renamed_version() { git mv "$artifact/1.0" "$artifact/1.0.1"; }
marker_overwrite() { echo other > "$marker/1.0/frc.visor.gradle.plugin-1.0.pom"; }

check_rows=(
  "new_version 0"
  "metadata_update 0"
  "outside_versions 0"
  "overwrite 1"
  "deleted_file 1"
  "added_to_published 1"
  "renamed_version 1"
  "marker_overwrite 1"
)

# release.sh: the version the libraries' catalogs give, whether it is accepted (0) or refused (1),
# and so whether the libraries' builds ran.
release_rows=(
  "1.1 0"
  "1.0 1"
  "2.0 0"
)

failures=0
fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

for row in "${check_rows[@]}"; do
  read -r change expected <<< "$row"
  fresh "check-$change"
  base="$(git rev-parse HEAD)"
  "$change"
  commit
  actual=0
  ./check-published.sh "$base" > out.log 2>&1 || actual=$?
  if [[ "$actual" != "$expected" ]]; then
    fail "check-published.sh, $change: exit $actual, expected $expected ($(cat out.log))"
  fi
done

for row in "${release_rows[@]}"; do
  read -r version expected <<< "$row"
  fresh "release-$version"
  for name in model localization pitwall runtime; do
    mkdir -p "$work/libs-$version/$name/gradle"
    echo "frc-libs = \"$version\"" > "$work/libs-$version/$name/gradle/libs.versions.toml"
  done
  # Stands in for each library's Gradle build: it records that it ran and publishes nothing.
  # shellcheck disable=SC2016 # $PWD is the stand-in's own, expanded when it runs.
  printf '#!/usr/bin/env bash\necho "$PWD" >> "%s"\n' "$work/ran-$version" > "$work/gradlew-$version"
  chmod +x "$work/gradlew-$version"
  actual=0
  GRADLEW="$work/gradlew-$version" ./release.sh "$work/libs-$version" > out.log 2>&1 || actual=$?
  if [[ "$actual" != "$expected" ]]; then
    fail "release.sh, version $version: exit $actual, expected $expected ($(cat out.log))"
  fi
  ran=0
  if [[ -f "$work/ran-$version" ]]; then
    ran="$(wc -l < "$work/ran-$version")"
  fi
  if [[ "$expected" == 0 && "$ran" != 4 ]] || [[ "$expected" == 1 && "$ran" != 0 ]]; then
    fail "release.sh, version $version: $ran library builds ran"
  fi
done

total=$((${#check_rows[@]} + ${#release_rows[@]}))
if [[ $failures -ne 0 ]]; then
  echo "$failures of $total rows failed" >&2
  exit 1
fi
echo "All $total rows passed"
