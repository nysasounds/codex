#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
migration_script="$repo_root/snap/local/migrate-codex-home"
marker_name=".codex-home-migration-v1"
tests_run=0
tmp_root=""
last_out=""
last_err=""

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

pass() {
    tests_run=$((tests_run + 1))
    printf 'ok %s - %s\n' "$tests_run" "$1"
}

assert_empty() {
    if [ -s "$1" ]; then
        printf 'unexpected content in %s:\n' "$1" >&2
        sed -n '1,120p' "$1" >&2
        fail "$2"
    fi
}

assert_contains() {
    if ! grep -F "$2" "$1" >/dev/null 2>&1; then
        printf 'expected to find "%s" in %s\n' "$2" "$1" >&2
        sed -n '1,120p' "$1" >&2
        fail "$3"
    fi
}

assert_file_exists() {
    [ -e "$1" ] || fail "$2"
}

assert_file_not_exists() {
    [ ! -e "$1" ] || fail "$2"
}

assert_file_content() {
    [ -e "$1" ] || fail "$3"
    actual=$(cat "$1")
    [ "$actual" = "$2" ] || fail "$3"
}

assert_symlink_target() {
    [ -L "$1" ] || fail "$3"
    target=$(readlink "$1")
    [ "$target" = "$2" ] || fail "$3"
}

run_with_timeout() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 10s "$@"
    else
        "$@"
    fi
}

describe_status() {
    if [ "$1" -eq 124 ]; then
        printf 'timed out after 10 seconds'
    else
        printf 'failed with status %s' "$1"
    fi
}

run_migration() {
    name=$1
    old_home=$2
    new_home=$3
    last_out="$tmp_root/$name.out"
    last_err="$tmp_root/$name.err"

    status=0
    run_with_timeout env SNAP_USER_DATA="$old_home" SNAP_USER_COMMON="$new_home" "$migration_script" </dev/null >"$last_out" 2>"$last_err" || status=$?

    if [ "$status" -eq 0 ]; then
        return 0
    fi
    printf 'migration command %s\n' "$(describe_status "$status")" >&2
    sed -n '1,120p' "$last_err" >&2
    exit "$status"
}

test_migrates_old_home_once() {
    old_home="$tmp_root/migrate with spaces/old home"
    new_home="$tmp_root/migrate with spaces/new home"
    mkdir -p "$old_home/sessions" "$new_home"
    printf 'auth-token\n' >"$old_home/auth.json"
    printf 'model = "gpt-test"\n' >"$old_home/config.toml"
    printf 'session data\n' >"$old_home/sessions/session.jsonl"
    printf 'hidden\n' >"$old_home/.hidden-state"
    ln -s config.toml "$old_home/config-link"

    run_migration migrate_once "$old_home" "$new_home"

    assert_empty "$last_out" "migration should not write to stdout"
    assert_contains "$last_err" "Codex snap has migrated CODEX_HOME." "migration warning should be printed"
    assert_contains "$last_err" "$old_home" "warning should include old home"
    assert_contains "$last_err" "$new_home" "warning should include new home"
    assert_contains "$last_err" 'ln -s "${HOME}/snap/codex/common" "${HOME}/.codex"' "warning should include create-symlink advice"
    assert_contains "$last_err" 'ln -sfnT "${HOME}/snap/codex/common" "${HOME}/.codex"' "warning should include update-symlink advice"
    assert_file_content "$new_home/auth.json" "auth-token" "auth file should be copied"
    assert_file_content "$new_home/config.toml" "model = \"gpt-test\"" "config should be copied"
    assert_file_content "$new_home/sessions/session.jsonl" "session data" "sessions should be copied"
    assert_file_content "$new_home/.hidden-state" "hidden" "hidden files should be copied"
    assert_symlink_target "$new_home/config-link" "config.toml" "symlinks should be preserved"
    assert_file_exists "$new_home/$marker_name" "migration marker should be created"

    printf 'new data\n' >"$old_home/new-after-marker"
    run_migration migrate_again "$old_home" "$new_home"
    assert_empty "$last_out" "second migration should not write to stdout"
    assert_empty "$last_err" "second migration should not warn"
    assert_file_not_exists "$new_home/new-after-marker" "second migration should not copy after marker exists"

    pass "migrates populated old home once"
}

test_already_migrated_marker_skips_copy() {
    old_home="$tmp_root/already-migrated/old"
    new_home="$tmp_root/already-migrated/new"
    mkdir -p "$old_home" "$new_home"
    printf 'old auth\n' >"$old_home/auth.json"
    : >"$new_home/$marker_name"

    run_migration already_migrated "$old_home" "$new_home"

    assert_empty "$last_out" "already migrated run should not write stdout"
    assert_empty "$last_err" "already migrated run should not warn"
    assert_file_not_exists "$new_home/auth.json" "marker should prevent copying old data"

    pass "skips when migration marker already exists"
}

test_first_install_without_old_home() {
    old_home="$tmp_root/first-install/old"
    new_home="$tmp_root/first-install/new"

    run_migration first_install "$old_home" "$new_home"

    assert_empty "$last_out" "first install should not write stdout"
    assert_empty "$last_err" "first install should not warn"
    assert_file_exists "$new_home/$marker_name" "first install should create marker"

    pass "handles first install with nothing to migrate"
}

test_empty_old_home() {
    old_home="$tmp_root/empty-old/old"
    new_home="$tmp_root/empty-old/new"
    mkdir -p "$old_home"

    run_migration empty_old "$old_home" "$new_home"

    assert_empty "$last_out" "empty old home should not write stdout"
    assert_empty "$last_err" "empty old home should not warn"
    assert_file_exists "$new_home/$marker_name" "empty old home should create marker"

    pass "handles empty old home"
}

test_existing_common_home_is_not_overwritten() {
    old_home="$tmp_root/existing-common/old"
    new_home="$tmp_root/existing-common/new"
    mkdir -p "$old_home" "$new_home"
    printf 'old auth\n' >"$old_home/auth.json"
    printf 'existing config\n' >"$new_home/config.toml"

    run_migration existing_common "$old_home" "$new_home"

    assert_empty "$last_out" "existing common home should not write stdout"
    assert_empty "$last_err" "existing common home should not warn"
    assert_file_content "$new_home/config.toml" "existing config" "existing common data should remain"
    assert_file_not_exists "$new_home/auth.json" "old data should not be merged into non-empty common home"
    assert_file_exists "$new_home/$marker_name" "existing common home should create marker"

    pass "does not overwrite or merge into existing common home"
}

test_old_and_common_same_path() {
    home="$tmp_root/same-path/home"
    mkdir -p "$home"
    printf 'auth-token\n' >"$home/auth.json"

    run_migration same_path "$home" "$home"

    assert_empty "$last_out" "same path should not write stdout"
    assert_empty "$last_err" "same path should not warn"
    assert_file_content "$home/auth.json" "auth-token" "same path data should remain"
    assert_file_exists "$home/$marker_name" "same path should create marker"

    pass "handles old and common home being the same path"
}

[ -x "$migration_script" ] || fail "migration helper is not executable: $migration_script"

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

test_migrates_old_home_once
test_already_migrated_marker_skips_copy
test_first_install_without_old_home
test_empty_old_home
test_existing_common_home_is_not_overwritten
test_old_and_common_same_path

printf 'All %s home migration smoke tests passed.\n' "$tests_run"
