#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$root/.github/workflows/release-impl.yml"
tmp=$(mktemp -d)
trap 'rm -r -- "$tmp"' EXIT

extract_step() {
  awk -v name="$1" '
    $0 == "      - name: " name { found = 1; next }
    found && /^        run: \|$/ { run = 1; next }
    run && /^          / { print substr($0, 11); next }
    run && /^$/ { print; next }
    run { exit }
  ' "$workflow"
}

extract_step 'Validate unpublished stable release for recovery' > "$tmp/validate.sh"
extract_step 'Get new tag' > "$tmp/new-tag.sh"
extract_step 'Generate incremental CHANGELOG for GitHub release body (stable release)' > "$tmp/changelog.sh"
for script in validate new-tag changelog; do
  test -s "$tmp/$script.sh"
  bash -n "$tmp/$script.sh"
done

mkdir "$tmp/repo"
cd "$tmp/repo"
git init --quiet --initial-branch=main --template=
git config core.autocrlf false
git config core.hooksPath /dev/null
git config user.name 'Recovery workflow test'
git config user.email 'recovery-test@example.invalid'
commit_version() {
  printf '%s\n' "$1" > version.txt
  git add version.txt
  git commit --quiet -m "Version $1"
}
commit_version 0.2.0
git tag v0.2.0
previous_sha=$(git rev-parse HEAD)
git tag v0.8.0
commit_version 0.3.0
git tag -a v0.3.0 -m 'Stable release'
release_sha=$(git rev-parse HEAD)
git tag v0.2.1
git tag v0.4.0
commit_version 0.3.1
git tag v0.3.1
lightweight_sha=$(git rev-parse HEAD)
commit_version 0.5.0
git tag v0.5.0
git update-ref refs/remotes/origin/main HEAD
git checkout --quiet -b unrelated "$previous_sha"
commit_version 0.9.0
git tag v0.9.0
git tag v0.1.1
git checkout --quiet main
refs=$(git for-each-ref)

poetry() {
  test "$*" = version
  printf 'hpcflow %s\n' "$(cat version.txt)"
}
curl() {
  local url="${!#}"
  case "$url" in
    https://api.github.com/repos/hpcflow/hpcflow/releases/tags/*)
      printf '%s' "${GITHUB_STATUS:-404}"
      return "${CURL_EXIT:-0}"
      ;;
    https://pypi.org/pypi/hpcflow/*/json|https://test.pypi.org/pypi/hpcflow/*/json)
      printf '%s' "${PYPI_STATUS:-404}"
      ;;
    *) printf 'Unexpected API URL: %s\n' "$url" >&2; return 1 ;;
  esac
}
export -f poetry curl
export TAG=v0.3.0 PREVIOUS_TAG=v0.2.0 BASE_BRANCH=main RELEASE_BRANCH=main
export REPOSITORY=hpcflow/hpcflow CALLER_REPOSITORY=hpcflow/hpcflow
export PYPI_URL=https://upload.pypi.org/legacy/ GH_TOKEN=test-token GH_API_URL=https://api.github.com
export GITHUB_OUTPUT="$tmp/output"

check_validation() {
  local expected="$1" name="$2" status=0 expected_sha="${EXPECTED_SHA:-$release_sha}"
  shift 2
  git checkout --quiet main
  : > "$GITHUB_OUTPUT"
  env "$@" bash -e "$tmp/validate.sh" > "$tmp/log" 2>&1 || status=$?
  if [[ "$expected" == pass ]]; then
    if [[ "$status" != 0 ]] || ! grep -qx "sha=$expected_sha" "$GITHUB_OUTPUT"; then
      cat "$tmp/log"
      printf 'FAIL: %s\n' "$name" >&2
      exit 1
    fi
    test "$(git rev-parse HEAD)" = "$expected_sha"
  elif [[ "$status" == 0 || -s "$GITHUB_OUTPUT" ]]; then
    cat "$tmp/log"
    printf 'FAIL: %s was not rejected\n' "$name" >&2
    exit 1
  fi
  test "$(git for-each-ref)" = "$refs"
  printf 'PASS: %s\n' "$name"
}

check_validation pass 'unpublished annotated tag, even when main has advanced'
EXPECTED_SHA="$lightweight_sha" check_validation pass 'unpublished lightweight tag' TAG=v0.3.1
check_validation pass 'TestPyPI upload endpoint' PYPI_URL=https://test.pypi.org/legacy/
check_validation fail 'wrong base branch' BASE_BRANCH=develop
check_validation fail 'wrong calling repository' CALLER_REPOSITORY=other/repo
check_validation fail 'missing recovery tag' TAG=
check_validation fail 'missing previous tag' PREVIOUS_TAG=
check_validation fail 'prerelease tag' TAG=v0.3.0a1
check_validation fail 'ref injection' TAG='v0.3.0;echo unwanted'
check_validation fail 'identical tag names' PREVIOUS_TAG=v0.3.0
check_validation fail 'different tags on the same commit' PREVIOUS_TAG=v0.2.1
check_validation fail 'missing tag ref' TAG=v8.0.0
check_validation fail 'previous tag is newer' PREVIOUS_TAG=v0.5.0
check_validation fail 'previous version is higher despite earlier commit' PREVIOUS_TAG=v0.8.0
check_validation fail 'unrelated previous tag' PREVIOUS_TAG=v0.1.1
check_validation fail 'release is not on stable branch' TAG=v0.9.0
check_validation fail 'package version mismatch' TAG=v0.4.0
check_validation fail 'unsupported package index' PYPI_URL=https://example.invalid/
check_validation fail 'existing GitHub publication' GITHUB_STATUS=200
check_validation fail 'existing PyPI publication' PYPI_STATUS=200
check_validation fail 'GitHub API permission failure' GITHUB_STATUS=403
check_validation fail 'PyPI API server failure' PYPI_STATUS=503
check_validation fail 'API transport failure' CURL_EXIT=7

: > "$GITHUB_OUTPUT"
RECOVERY_TAG=v0.3.0 bash -e "$tmp/new-tag.sh"
grep -qx 'tag=v0.3.0' "$GITHUB_OUTPUT"
grep -qx 'version=0.3.0' "$GITHUB_OUTPUT"
printf 'PASS: recovery tag and version outputs\n'
git checkout --quiet --detach "$release_sha"
: > "$GITHUB_OUTPUT"
normal_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")
RECOVERY_TAG= bash -e "$tmp/new-tag.sh"
grep -qx "tag=$normal_tag" "$GITHUB_OUTPUT"
printf 'PASS: normal release tag output\n'

cat > git-chglog <<'SH'
#!/usr/bin/env bash
set -eu
if [[ -n "$RECOVERY_TAG" ]]; then
  test "$#" -eq 9
  test "$1" = --tag-filter-pattern
  test "$2" = '^(v0[.]2[.]0|v0[.]3[.]0)$'
  test "$3" = --sort
  test "$4" = semver
  shift 4
fi
test "$#" -eq 5
test "$1" = --template
test "$2" = .chglog/RELEASE.tpl.md
test "$3" = --output
test "$4" = CHANGELOG_increment.md
test "$5" = "$EXPECTED_RANGE"
printf 'Release notes\n' > "$4"
SH
chmod +x git-chglog
RECOVERY_TAG=v0.3.0 PREVIOUS_TAG=v0.2.0 EXPECTED_RANGE=v0.3.0 bash -e "$tmp/changelog.sh"
RECOVERY_TAG= PREVIOUS_TAG= cur_tag=v0.2.0 EXPECTED_RANGE=v0.2.0.. bash -e "$tmp/changelog.sh"
printf 'PASS: recovery and normal stable release notes ranges\n'
test "$(git for-each-ref)" = "$refs"
