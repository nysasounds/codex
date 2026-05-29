#!/bin/sh
set -eu

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
        sed -n '1,160p' "$1" >&2
        fail "$3"
    fi
}

require_codex_snap() {
    [ "${SNAP_NAME:-}" = "codex" ] || fail "must be run inside the codex snap environment"
    [ -n "${SNAP:-}" ] || fail "SNAP is not set"
    [ -d "$SNAP" ] || fail "SNAP does not point to a directory: $SNAP"

    pass "running inside codex snap"
}

test_yq_family() {
    assert_command yq
    assert_command tomlq
    assert_command xq-python

    cat >"$tmp_root/yq-input.yaml" <<'EOF'
name: codex
tools:
  rust: true
  go: true
EOF
    yq -r '.name' "$tmp_root/yq-input.yaml" >"$tmp_root/yq.out"
    assert_contains "$tmp_root/yq.out" "codex" "yq should parse YAML with the Python component installed"

    printf 'name = "codex"\n' >"$tmp_root/tomlq-input.toml"
    tomlq -r '.name' "$tmp_root/tomlq-input.toml" >"$tmp_root/tomlq.out"
    assert_contains "$tmp_root/tomlq.out" "codex" "tomlq should parse TOML with the Python component installed"

    printf '<root><name>codex</name></root>\n' >"$tmp_root/xq-input.xml"
    xq-python -r '.root.name' "$tmp_root/xq-input.xml" >"$tmp_root/xq.out"
    assert_contains "$tmp_root/xq.out" "codex" "xq-python should parse XML with the Python component installed"

    pass "yq, tomlq, and xq-python use isolated packaged modules"
}

test_argcomplete_helpers() {
    assert_command activate-global-python-argcomplete
    assert_command register-python-argcomplete
    assert_command python-argcomplete-check-easy-install-script

    activate-global-python-argcomplete --help >"$tmp_root/activate-help.out"
    assert_contains "$tmp_root/activate-help.out" "usage: activate-global-python-argcomplete" \
        "activate-global-python-argcomplete should print help"

    register-python-argcomplete --help >"$tmp_root/register-help.out"
    assert_contains "$tmp_root/register-help.out" "usage: register-python-argcomplete" \
        "register-python-argcomplete should print help"

    status=0
    python-argcomplete-check-easy-install-script --help >"$tmp_root/check-help.out" 2>&1 || status=$?
    [ "$status" -ne 127 ] || fail "python-argcomplete-check-easy-install-script should execute"
    assert_contains "$tmp_root/check-help.out" "Usage:" \
        "python-argcomplete-check-easy-install-script should print usage"

    pass "argcomplete helper utilities execute with isolated packaged modules"
}

test_rrsync() {
    assert_command rrsync

    rrsync -h >"$tmp_root/rrsync-help.out"
    assert_contains "$tmp_root/rrsync-help.out" "usage: rrsync" "rrsync should print help"

    pass "rrsync executes through the Python utility wrapper"
}

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

require_codex_snap
test_yq_family
test_argcomplete_helpers
test_rrsync

printf 'All %s Python utility smoke tests passed.\n' "$tests_run"
