#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

work_dir="$repo_root/.ci-smoke-$$"
mkdir -p "$work_dir"
trap 'rm -rf "$work_dir"' EXIT

old_interface="fixtures/v1/pkg.generated.mbti"
new_interface="fixtures/v2/pkg.generated.mbti"

echo "Checking JSON compatibility summary"
moon run cmd/main -- diff "$old_interface" "$new_interface" --format json \
  > "$work_dir/diff.json"
grep -q '"has_breaking": true' "$work_dir/diff.json"
grep -q '"breaking": 4' "$work_dir/diff.json"

echo "Checking breaking gate exit status"
set +e
moon run cmd/main -- diff "$old_interface" "$new_interface" --fail-on-breaking \
  > "$work_dir/gate.log" 2>&1
gate_status=$?
set -e
if [ "$gate_status" -ne 2 ]; then
  echo "expected breaking gate exit 2, got $gate_status"
  cat "$work_dir/gate.log"
  exit 1
fi
grep -q "breaking API change" "$work_dir/gate.log"

echo "Checking dry-run migration plan"
moon run cmd/main -- plan "$old_interface" "$new_interface" --format diff \
  > "$work_dir/plan.diff"
grep -q -- "-get_user" "$work_dir/plan.diff"
grep -q -- "+fetch_user" "$work_dir/plan.diff"

echo "Checking successful migration"
cp -R fixtures/demo-project "$work_dir/success"
moon run cmd/main -- migrate "$work_dir/success" "$old_interface" "$new_interface" --apply \
  > "$work_dir/success.log"
grep -q "pub fn fetch_user" "$work_dir/success/main.mbt"
grep -q "fetch_user(7)" "$work_dir/success/main_test.mbt"
grep -q "Migration applied successfully" "$work_dir/success.log"

echo "Checking test failure rollback"
cp -R fixtures/demo-project "$work_dir/failure"
sed -i 's/assert_eq(get_user(7), 7)/assert_eq(get_user(7), 8)/' \
  "$work_dir/failure/main_test.mbt"
set +e
moon run cmd/main -- migrate "$work_dir/failure" "$old_interface" "$new_interface" --apply \
  > "$work_dir/failure.log" 2>&1
rollback_status=$?
set -e
if [ "$rollback_status" -eq 0 ]; then
  echo "expected migration to fail"
  cat "$work_dir/failure.log"
  exit 1
fi
grep -q "moon test failed; changes were rolled back" "$work_dir/failure.log"
grep -q "pub fn get_user" "$work_dir/failure/main.mbt"
grep -q "get_user(7), 8" "$work_dir/failure/main_test.mbt"

echo "CLI smoke tests passed"
