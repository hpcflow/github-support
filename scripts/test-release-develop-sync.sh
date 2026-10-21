#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$root/.github/workflows/release-impl.yml"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

# Extract every copy of the stable develop-sync step and check they are identical.
awk -v dir="$tmp" '
  $0 == "      - name: Sync release branch into develop branch if exists (stable release)" { n++; found = 1; next }
  found && /^        run: \|$/ { run = 1; next }
  run && /^          / { print substr($0, 11) > (dir "/sync" n ".sh"); next }
  run && /^$/ { print "" > (dir "/sync" n ".sh"); next }
  run { found = 0; run = 0 }
' "$workflow"
test -s "$tmp/sync1.sh"
test -s "$tmp/sync2.sh"
test ! -e "$tmp/sync3.sh"
cmp -s "$tmp/sync1.sh" "$tmp/sync2.sh"
bash -n "$tmp/sync1.sh"
if grep -qE 'git (rebase|push .*(-f|--force))' "$tmp/sync1.sh"; then
  printf 'FAIL: develop sync must not rewrite history\n' >&2
  exit 1
fi
printf 'PASS: both develop sync steps are identical and never rewrite history\n'

sleep() { :; }
export -f sleep
export PRE_BRANCH=develop BASE_BRANCH=main GIT_CONFIG_GLOBAL="$tmp/gitconfig"
git config --global init.templateDir ''
git config --global core.autocrlf false
git config --global core.hooksPath /dev/null
git config --global user.name 'Develop sync test'
git config --global user.email 'develop-sync-test@example.invalid'

commit_file() {
  printf '%s\n' "$2" > "$1"
  git add "$1"
  git commit --quiet -m "$3"
}

# Create a remote where develop was merged into main (the release PR), and a
# runner clone in which main has the release bump commit already pushed.
setup() {
  rm -rf "$tmp/remote.git" "$tmp/seed" "$tmp/runner"
  git init --quiet --bare --initial-branch=main "$tmp/remote.git"
  git clone --quiet "$tmp/remote.git" "$tmp/seed" 2> /dev/null
  cd "$tmp/seed"
  commit_file version.txt 0.4.0a18 'bump: 0.4.0a17 -> 0.4.0a18'
  git push --quiet origin main
  git push --quiet origin main:develop
  git clone --quiet "$tmp/remote.git" "$tmp/runner"
  cd "$tmp/runner"
  commit_file version.txt 0.4.0 'bump: 0.3.0 -> 0.4.0 [skip ci]'
  git push --quiet origin main
}

# Push a commit to develop that is not on main, as a concurrent run would.
advance_develop() {
  cd "$tmp/seed"
  git fetch --quiet origin
  git checkout --quiet -B develop origin/develop
  commit_file "$1" "$2" "$3"
  git push --quiet origin develop
  cd "$tmp/runner"
}

run_sync() {
  local status=0
  bash -e "$tmp/sync1.sh" > "$tmp/log" 2>&1 || status=$?
  return "$status"
}

remote_rev() {
  git --git-dir="$tmp/remote.git" rev-parse "$1"
}

fail() {
  cat "$tmp/log" >&2 || true
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

setup
run_sync || fail 'fast-forward sync'
test "$(remote_rev develop)" = "$(remote_rev main)" || fail 'develop was not fast-forwarded to main'
printf 'PASS: develop fast-forwards to the release commit\n'

setup
advance_develop released_binaries.yml 0.4.0a18 'build: update binary download links file [skip ci]'
extra=$(remote_rev develop)
run_sync || fail 'sync with a concurrent develop commit'
merge=$(remote_rev develop)
test "$(git --git-dir="$tmp/remote.git" rev-list --parents -n 1 "$merge")" = \
  "$merge $extra $(remote_rev main)" || fail 'develop is not a merge of its old tip and main'
git --git-dir="$tmp/remote.git" log -1 --format=%s "$merge" | grep -qF '[skip ci]' ||
  fail 'merge commit does not skip CI'
test "$(git --git-dir="$tmp/remote.git" show develop:version.txt)" = 0.4.0 || fail 'release bump missing'
printf 'PASS: develop commits missing from main are merged, not rewritten\n'

setup
mkdir "$tmp/remote.git/hooks-reject-once"
cat > "$tmp/remote.git/hooks-reject-once/pre-receive" <<'SH'
#!/usr/bin/env bash
if [[ ! -e rejected-once ]]; then
  touch rejected-once
  echo 'simulated concurrent update' >&2
  exit 1
fi
SH
chmod +x "$tmp/remote.git/hooks-reject-once/pre-receive"
git --git-dir="$tmp/remote.git" config core.hooksPath hooks-reject-once
run_sync || fail 'retry after a rejected push'
grep -qF 'rejected (attempt 1)' "$tmp/log" || fail 'first push was not rejected'
test "$(remote_rev develop)" = "$(remote_rev main)" || fail 'develop was not synced after retry'
printf 'PASS: a rejected push is retried\n'

setup
advance_develop version.txt 0.4.0a19 'conflicting develop change'
before=$(remote_rev develop)
if run_sync; then
  fail 'conflicting merge was not rejected'
fi
test "$(remote_rev develop)" = "$before" || fail 'develop changed after a failed merge'
printf 'PASS: conflicting changes fail without updating develop\n'

setup
git --git-dir="$tmp/remote.git" update-ref -d refs/heads/develop
run_sync || fail 'sync without a develop branch'
grep -qF 'No develop branch to merge into.' "$tmp/log" || fail 'missing develop branch not reported'
printf 'PASS: missing develop branch is skipped\n'
