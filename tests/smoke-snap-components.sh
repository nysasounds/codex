#!/bin/sh
set -eu

if [ -n "${SNAP:-}" ]; then
    PATH="$SNAP/usr/sbin:$SNAP/usr/bin:$SNAP/sbin:$SNAP/bin:$PATH"
    export PATH
fi

tests_run=0
tmp_root=""

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

pass() {
    tests_run=$((tests_run + 1))
    printf 'ok %s - %s\n' "$tests_run" "$1"
}

assert_command() {
    command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

assert_contains() {
    if ! grep -F "$2" "$1" >/dev/null 2>&1; then
        printf 'expected to find "%s" in %s\n' "$2" "$1" >&2
        sed -n '1,220p' "$1" >&2
        fail "$3"
    fi
}

assert_not_contains() {
    if grep -F "$2" "$1" >/dev/null 2>&1; then
        printf 'did not expect to find "%s" in %s\n' "$2" "$1" >&2
        sed -n '1,220p' "$1" >&2
        fail "$3"
    fi
}

require_codex_snap() {
    [ "${SNAP_NAME:-}" = "codex" ] || fail "must be run inside the codex snap environment"
    [ -n "${SNAP:-}" ] || fail "SNAP is not set"
    [ -n "${SNAP_REVISION:-}" ] || fail "SNAP_REVISION is not set"
    [ -d "$SNAP" ] || fail "SNAP does not point to a directory: $SNAP"

    pass "running inside codex snap revision $SNAP_REVISION"
}

test_wrapper_diagnostics() {
    diag="$tmp_root/wrapper-diagnostic.out"
    CODEX_WRAPPER_DIAGNOSTIC=1 codex-wrapper >"$diag"

    assert_not_contains "$diag" "components_root=" "classic snap diagnostics should not expose component roots"
    assert_not_contains "$diag" "tools-python-3-12=" "classic snap should not report tool components"
    assert_contains "$diag" "bwrap=" "bubblewrap should be visible for Codex sandboxing"

    pass "wrapper diagnostics pass for classic snap runtime"
}

test_bwrap_available() {
    assert_command bwrap
    bwrap --version >"$tmp_root/bwrap-version.out"
    assert_contains "$tmp_root/bwrap-version.out" "bubblewrap" "bwrap should report its version"

    pass "bubblewrap is packaged and executable"
}

test_codex_helpers() {
    assert_command codex
    assert_command codex-linux-sandbox
    assert_command codex-execve-wrapper
    assert_command apply_patch

    codex --version >"$tmp_root/codex-version.out"
    assert_contains "$tmp_root/codex-version.out" "codex-cli" "codex should report its version"

    pass "codex argv0 helpers are available"
}

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

require_codex_snap
test_wrapper_diagnostics
test_bwrap_available
test_codex_helpers

printf 'All %s classic snap smoke tests passed.\n' "$tests_run"
