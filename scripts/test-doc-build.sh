#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
docs="$root/.github/workflows/doc-build-impl.yml"
release="$root/.github/workflows/release-impl.yml"
tmp=$(mktemp -d)
trap 'rm -r -- "$tmp"' EXIT

extract_job() {
  awk -v name="$2" '
    $0 == "  " name ":" { found = 1; next }
    found && /^  [a-zA-Z0-9_-]+:/ { exit }
    found { print }
  ' "$1"
}

extract_step() {
  awk -v name="$1" '
    $0 == "      - name: " name { found = 1; next }
    found && /^        run: \|$/ { run = 1; next }
    run && /^          / { print substr($0, 11); next }
    run && /^$/ { print; next }
    run { exit }
  ' "$docs"
}

cleanup=$(extract_job "$release" cleanup-cache)
for consumer in cache-app-data build-executables build-executables-linux build-documentation; do
  grep -qx "      - $consumer" <<< "$cleanup"
done
grep -qF 'always()' <<< "$cleanup"
! grep -q 'failOnError: false' <<< "$cleanup"
! extract_job "$release" make-workflow-benchmark-upload | grep -q cleanup-cache
extract_job "$release" build-documentation | grep -qF 'uses: ./.github/workflows/doc-build-impl.yml'
extract_job "$release" build-documentation | grep -q app-data-cache-name
extract_job "$release" release-github-PyPI | grep -qF 'pattern: "!*-app-data-cache"'
extract_job "$release" make-workflow-benchmark-upload | grep -qF 'pattern: benchmark_make_workflow_*'
printf 'PASS: release retains its cache for docs without including it in publication or benchmarks\n'

cleanup=$(extract_job "$docs" cleanup-cache)
grep -qF 'needs: [cache-app-data, sphinx]' <<< "$cleanup"
grep -qF "always() && needs.cache-app-data.outputs.artifact-id != ''" <<< "$cleanup"
! grep -q 'failOnError: false' <<< "$cleanup"
extract_job "$docs" cache-app-data | grep -qF "inputs.app-data-cache-name == ''"
extract_job "$docs" sphinx | grep -qF "needs.cache-app-data.result == 'skipped'"
printf 'PASS: standalone cleanup runs after failed builds; caller-owned caches skip preparation and deletion\n'

extract_step 'Install cached app data' > "$tmp/install.sh"
test -s "$tmp/install.sh"
bash -n "$tmp/install.sh"
cd "$tmp"
mkdir -p app-data-cache/data app-data-cache/programs docs/source bin
cat > bin/poetry <<'SH'
#!/usr/bin/env bash
set -eu
test "$1" = run
test "$2" = example-app
shift 2
printf '%s\n' "$*" >> "$CALLS"
if [[ "$*" == 'data install-cache app-data-cache/data' ]]; then
  test -d "$3"
  exit "${INSTALL_STATUS:-0}"
elif [[ "$*" == 'program install-cache app-data-cache/programs' ]]; then
  test -d "$3"
else
  test "$*" = 'data --list' || test "$*" = 'program --list'
fi
SH
chmod +x bin/poetry
export PATH="$tmp/bin:$PATH" EXE_NAME=example-app CALLS="$tmp/calls"
bash -e install.sh
printf '%s\n' \
  'data install-cache app-data-cache/data' 'data --list' \
  'program install-cache app-data-cache/programs' 'program --list' > expected
cmp expected calls
printf 'PASS: docs install both prepared data and programs through the application CLI\n'

: > calls
if INSTALL_STATUS=1 bash -e install.sh; then
  printf 'FAIL: cache installation errors must stop the docs build\n' >&2
  exit 1
fi
test "$(wc -l < calls)" -eq 1
printf 'PASS: cache installation failures propagate without continuing the build\n'

links_step=$(awk '
  $0 == "      - name: Write release binary links" { found = 1; next }
  found && /^        run: / { print substr($0, 14); exit }
' "$docs")
test -n "$links_step"
export BIN_LINKS=$'example-app-linux: https://example.invalid/app\nexample-app-win.exe: https://example.invalid/app.exe'
bash -e -c "$links_step"
printf '%s\n' "$BIN_LINKS" > expected
cmp expected docs/source/released_binaries.yml
printf 'PASS: release and recovery docs receive binary links without relying on uncommitted changes\n'
