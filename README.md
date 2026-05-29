# Snap packaging of OpenAI Codex

One agent for everywhere you code

Codex is OpenAI’s coding agent for software development. ChatGPT Plus, Pro, Business, Edu, and Enterprise plans include Codex. It can help you:

- **Write code**: Describe what you want to build, and Codex generates code that matches your intent, adapting to your existing project structure and conventions.
- **Understand unfamiliar codebases**: Codex can read and explain complex or legacy code, helping you grasp how teams organize systems.
- **Review code**: Codex analyzes code to identify potential bugs, logic errors, and unhandled edge cases.
- **Debug and fix problems**: When something breaks, Codex helps trace failures, diagnose root causes, and suggest targeted fixes.
- **Automate development tasks**: Codex can run repetitive workflows such as refactoring, testing, migrations, and setup tasks so you can focus on higher-level engineering work

[Upstream](https://github.com/openai/codex)

[Usage Docs](https://developers.openai.com/codex/cli/)

## Info

This is just another installation method for Codex, providing an alternative to documented installation methods such as NPM or Brew.

This is a strictly confined snap, which has the following considerations:
  - The application has restricted access to system resources, providing an extra layer of security.
    - System access is controlled by specifically configured interface plugs that are connected to the application.
    - Codex will have access to files under your HOME directory only, which is then further bound by the Sandboxing Modes you have configured for Codex.
      - Sandbox Modes do not supersede the strict confinement, rather the confinement acts as an extra security layer over the top.
  - Any extra utilities or other external dependencies must be included within the snap package, either specifically or by inheritance from the snaps base.
    - If you find an important dependency is missing, please open an Issue and/or PR so we can it's inclusion can be discussed.
  - The default configuration location is different
    - Please see the [below](#Configuration) for details

## Install

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-white.svg)](https://snapcraft.io/codex)

[![codex](https://snapcraft.io/codex/badge.svg)](https://snapcraft.io/codex)

Install from the global snap store

```
sudo snap install codex
```

## Optional language tooling components

Codex runs in a strictly confined snap. Tools that are not provided by the base
snap, the main Codex snap, or the current project need to be packaged with Codex
before Codex can use them reliably inside the confined environment.

To avoid bloating the main snap while still providing flexibility, optional
language tooling is shipped as snap components. Component support requires snapd
2.67 or newer. For example, install the Python component alongside Codex with:

```
sudo snap install codex+tools-python-3-12
```

Additional language and native build tooling are also available as components:

```
sudo snap install codex+tools-go-1-23
sudo snap install codex+tools-go-1-24
sudo snap install codex+tools-rust-1-80
sudo snap install codex+tools-rust-1-82
sudo snap install codex+tools-native-build
```

If Codex is already installed, the same command installs the missing component.

Available components can be listed with:

```
snap components codex
```


### Python 3.12 component

The `tools-python-3-12` component provides a Python 3.12 environment for Codex
shell tasks. When installed, the Codex wrapper prepends the component's `bin`
directory to `PATH`, so `python3`, `pip3`, `setuptools`, `wheel`, and
`virtualenv` resolve from the component.

The component is built with Snapcraft's `python` plugin. It behaves like a
plugin-managed Python environment rather than a full distro Python install.
`pip3` and `python3 -m pip` are expected to work normally.

One quirk is virtual environment creation. The plugin-managed environment does
not include the stdlib `ensurepip` module, so plain stdlib seeding is not
available. To keep common Python project setup commands working, the component
includes `virtualenv` and wraps `python3 -m venv ...` so it creates the requested
environment through `virtualenv` instead.

### Go components

The `tools-go-1-23` and `tools-go-1-24` components provide Go toolchains from
Ubuntu packages for Codex shell tasks. Each component exposes versioned commands
such as `go1.23`, `gofmt1.23`, `go1.24`, and `gofmt1.24`.

If more than one Go component is installed, the unversioned `go` and `gofmt`
commands resolve to the newest installed component supported by the wrapper.
Versioned commands remain available for projects that need a specific toolchain.

The Go wrappers set `GOROOT` to the component-local Go tree. The Codex wrapper
also sets writable defaults for Go state when a Go component is installed:

```
GOPATH=$HOME/snap/codex/common/go
GOCACHE=$HOME/snap/codex/common/.cache/go-build
GOENV=$HOME/snap/codex/common/go/env
```

These defaults avoid writing Go caches into revision-specific snap directories.

### Rust components

The `tools-rust-1-80` and `tools-rust-1-82` components provide Rust toolchains
from Ubuntu packages for Codex shell tasks. Each component exposes versioned
commands such as `rustc1.80`, `cargo1.80`, `rustfmt1.80`, `rustc1.82`,
`cargo1.82`, and `rustfmt1.82`.

If more than one Rust component is installed, the unversioned `rustc`, `cargo`,
`rustdoc`, `rustfmt`, `cargo-clippy`, and `clippy-driver` commands resolve to
the newest installed component supported by the wrapper. Versioned commands
remain available for projects that need a specific toolchain.

The Rust wrappers keep versioned Cargo commands paired with their matching
compiler. For example, `cargo1.80` uses the Rust 1.80 `rustc`, even if the Rust
1.82 component is also installed.

The Codex wrapper sets a writable default for Cargo state when a Rust component
is installed:

```
CARGO_HOME=$HOME/snap/codex/common/cargo
```

The Rust components do not include `rustup`, and they do not download missing
toolchains from `rust-toolchain.toml`. Projects that need a specific toolchain
should use one of the packaged versioned commands. Rust crates that compile or
link native code may also need the `tools-native-build` component, and projects
that depend on additional native libraries still need those libraries and
development headers to be packaged in Codex or another component.

### Native build component

The `tools-native-build` component provides common native build tools such as
GCC, make, libc headers, binutils, and pkg-config. It is useful for projects that
compile C or C++ code directly, and for Go projects that use CGO.

When installed, the Codex wrapper adds the component's compiler, library,
include, and pkg-config paths to the environment. Installing `tools-native-build`
alongside a Go component enables normal libc-based CGO builds. Projects that
depend on additional native libraries still need those libraries and development
headers to be packaged in Codex or another component.

### Configuration

Configuration lives under `$HOME/snap/codex/common`.

If you want Codex's standard/default location to point at the snap-managed
configuration, create this symlink:
```
ln -s "${HOME}/snap/codex/common" "${HOME}/.codex"
```

If you already have `${HOME}/.codex` as a symlink to the old location, `$HOME/snap/codex/current`,
update it to point at the current snap location instead:
```
ln -sfnT "${HOME}/snap/codex/common" "${HOME}/.codex"
```
