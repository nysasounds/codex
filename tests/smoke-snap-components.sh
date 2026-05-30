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

    assert_contains "$diag" "components_root=/snap/codex/components/$SNAP_REVISION" "components root should use normalized path"
    assert_not_contains "$diag" "/../components/" "components root should not contain relative parent traversal"
    assert_contains "$diag" "tools-python-3-12=installed" "Python component should be installed"
    assert_contains "$diag" "tools-go-1-23=installed" "Go 1.23 component should be installed"
    assert_contains "$diag" "tools-go-1-24=installed" "Go 1.24 component should be installed"
    assert_contains "$diag" "tools-rust-1-80=installed" "Rust 1.80 component should be installed"
    assert_contains "$diag" "tools-rust-1-82=installed" "Rust 1.82 component should be installed"
    assert_contains "$diag" "tools-native-build=installed" "native build component should be installed"
    assert_contains "$diag" "tools-python-3-12_smoke_test=pass" "Python diagnostic smoke test should pass"
    assert_contains "$diag" "tools-go-1-23_smoke_test=pass" "Go 1.23 diagnostic smoke test should pass"
    assert_contains "$diag" "tools-go-1-24_smoke_test=pass" "Go 1.24 diagnostic smoke test should pass"
    assert_contains "$diag" "tools-rust-1-80_smoke_test=pass" "Rust 1.80 diagnostic smoke test should pass"
    assert_contains "$diag" "tools-rust-1-82_smoke_test=pass" "Rust 1.82 diagnostic smoke test should pass"
    assert_contains "$diag" "tools-native-build_smoke_test=pass" "native build diagnostic smoke test should pass"

    pass "wrapper diagnostics pass for installed components"
}

test_python_component() {
    assert_command python3
    assert_command pip3

    venv_dir="$tmp_root/python-venv"
    python3 -m venv "$venv_dir" >/dev/null
    "$venv_dir/bin/python" -m pip --version >/dev/null
    "$venv_dir/bin/python" -c 'import pip, ssl, sqlite3, venv, zlib; print("python ok")' >"$tmp_root/python.out"
    assert_contains "$tmp_root/python.out" "python ok" "Python imports should work from venv"

    pass "Python component creates and runs a pip-seeded venv"
}

test_go_components() {
    assert_command go
    assert_command go1.23
    assert_command go1.24

    go_dir="$tmp_root/go"
    mkdir -p "$go_dir"
    cat >"$go_dir/main.go" <<'EOF'
package main

import "fmt"

func main() { fmt.Println("go ok") }
EOF

    go run "$go_dir/main.go" >"$tmp_root/go.out"
    assert_contains "$tmp_root/go.out" "go ok" "go run should execute a simple program"
    go1.23 version | grep -F 'go1.23' >/dev/null || fail "go1.23 should report Go 1.23"
    go1.24 version | grep -F 'go1.24' >/dev/null || fail "go1.24 should report Go 1.24"

    pass "Go components run unversioned and versioned tools"
}

test_cgo_with_native_build_component() {
    assert_command gcc
    assert_command go

    cgo_dir="$tmp_root/cgo"
    mkdir -p "$cgo_dir"
    cat >"$cgo_dir/main.go" <<'EOF'
package main

/*
#include <stdint.h>
static int32_t answer(void) { return 42; }
*/
import "C"
import "fmt"

func main() { fmt.Println("cgo", int(C.answer())) }
EOF

    CGO_ENABLED=1 go run "$cgo_dir/main.go" >"$tmp_root/cgo.out"
    assert_contains "$tmp_root/cgo.out" "cgo 42" "CGO should compile and run with native build tools"

    pass "CGO works with native build component"
}

test_rust_components() {
    assert_command rustc
    assert_command cargo
    assert_command rustfmt
    assert_command cargo-fmt
    assert_command cargo-clippy
    assert_command clippy-driver
    assert_command rustc1.80
    assert_command cargo1.80
    assert_command rustc1.82
    assert_command cargo1.82

    rust_dir="$tmp_root/rust"
    mkdir -p "$rust_dir/src"
    cat >"$rust_dir/Cargo.toml" <<'EOF'
[package]
name = "codex-rust-smoke"
version = "0.1.0"
edition = "2021"
EOF
    cat >"$rust_dir/src/main.rs" <<'EOF'
fn main() {
    println!("rust ok");
}
EOF

    (cd "$rust_dir" && cargo run --quiet) >"$tmp_root/rust.out"
    assert_contains "$tmp_root/rust.out" "rust ok" "cargo run should execute a simple Rust program"
    (cd "$rust_dir" && cargo fmt --check)
    (cd "$rust_dir" && cargo clippy --quiet -- -D warnings)

    rustc1.80 --version | grep -F '1.80.' >/dev/null || fail "rustc1.80 should report Rust 1.80"
    cargo1.80 --version | grep -F '1.80.' >/dev/null || fail "cargo1.80 should report Cargo 1.80"
    rustc1.82 --version | grep -F '1.82.' >/dev/null || fail "rustc1.82 should report Rust 1.82"
    cargo1.82 --version | grep -F '1.82.' >/dev/null || fail "cargo1.82 should report Cargo 1.82"
    cargo-fmt --version | grep -F 'rustfmt' >/dev/null || fail "cargo-fmt should report rustfmt version"
    cargo-fmt1.80 --version | grep -F 'rustfmt' >/dev/null || fail "cargo-fmt1.80 should report rustfmt version"
    cargo-fmt1.82 --version | grep -F 'rustfmt' >/dev/null || fail "cargo-fmt1.82 should report rustfmt version"
    cargo-clippy1.80 --version | grep -F 'clippy 0.1.80' >/dev/null || fail "cargo-clippy1.80 should report Clippy 1.80"
    cargo-clippy1.82 --version | grep -F 'clippy 0.1.82' >/dev/null || fail "cargo-clippy1.82 should report Clippy 1.82"

    pass "Rust components run cargo, fmt, clippy, and versioned aliases"
}

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

require_codex_snap
test_wrapper_diagnostics
test_python_component
test_go_components
test_cgo_with_native_build_component
test_rust_components

printf 'All %s snap component smoke tests passed.\n' "$tests_run"
