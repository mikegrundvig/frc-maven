#!/usr/bin/env bash
# Fails when a commit since <base> changes what a published version holds (README.md, A published
# version stays as it is). Usage, from anywhere:
#
#   ./check-published.sh <base>    compares <base> with HEAD
#
# A version is published once: a robot build trusts its files, and the checksums beside them are
# written by the same publish, so a replaced jar would come with matching checksums. Allowed: a new
# version's folder, and the maven-metadata.xml files (with their checksums) that list the versions.
# Refused: a changed, deleted, renamed or added file inside a version's folder that <base> has.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <base commit>" >&2
  exit 2
fi
base="$1"
cd "$(dirname "$0")"

# Prints why a path's change is refused, or nothing when it is allowed.
refusal() {
  local status="$1" path="$2"
  # Only the repository's folders hold published versions: com/ (artifacts) and frc/ (plugin markers).
  if [[ "$path" != com/* && "$path" != frc/* ]]; then
    return
  fi
  # An artifact's version list sits beside its version folders and changes with every release.
  if [[ "$(basename "$path")" == maven-metadata.xml* ]]; then
    return
  fi
  if [[ "$status" != A ]]; then
    echo "$path: changed ($status) in a published version"
    return
  fi
  # An added file is a new version's only when its folder holds nothing at the base.
  if [[ -n "$(git ls-tree --name-only "$base" -- "$(dirname "$path")/")" ]]; then
    echo "$path: added to a published version"
  fi
}

problems=()
# --no-renames reports a rename as a deletion and an addition, so both ends are checked.
while IFS=$'\t' read -r status path; do
  problem="$(refusal "${status:0:1}" "$path")"
  if [[ -n "$problem" ]]; then
    problems+=("$problem")
  fi
done < <(git diff --name-status --no-renames "$base" HEAD)

if [[ ${#problems[@]} -eq 0 ]]; then
  echo "No published version changed since $(git rev-parse --short "$base")."
  exit 0
fi
echo "A published version stays as it is: publish a fix as a new version." >&2
printf '  %s\n' "${problems[@]}" >&2
exit 1
