# AI Coding Assistant Context

This repository contains snap packaging for OpenAI Codex. The snap is intended
to be another installation method for Codex, alongside upstream installation
methods such as npm and Homebrew.

## Mandatory Startup Rule

On every turn, before doing analysis or edits:

1. Locate and read `AGENTS.md` from the current workspace root if it exists.
2. If more specific `AGENTS.md` files are added later, merge those rules with
   the root-level rules and prefer the nearest one for target files.
3. If the file cannot be read, report that before proceeding.

## Repository Layout

- `snap/snapcraft.yaml` is the main snapcraft project file.
- `snap/local/codex-wrapper` is the runtime wrapper used by the `codex` app.
- `snap/local/migrate-codex-home` migrates the snap-specific Codex home from
  the old revision-specific path to the common path.
- `snap/hooks` contains snap hooks, if present.
- `tests/` contains shell smoke tests.
- Files with `.snap` and `.comp` extensions are local build artifacts. Do not
  treat them as source and do not edit them.
- `tmp/` is used for local extraction/debugging artifacts and should generally
  be ignored unless the user explicitly points to it.

## Snap Shape

The snap currently uses:

- `base: core24`
- `confinement: classic`
- `grade: stable`
- `platforms: amd64, arm64`

The main `codex` part builds upstream Codex from the Rust source tree using the
Snapcraft `rust` plugin. It also stages `bubblewrap` and `xdg-utils`.
`bubblewrap` is intentionally bundled so Codex can find a Linux sandbox helper
without depending on the host package. The `launcher` part installs the wrapper
and migration helper from `snap/local`.

The app command is `bin/codex-wrapper`, and `CODEX_HOME` is set to
`$SNAP_USER_COMMON`, so persistent Codex state should live under:

```sh
$HOME/snap/codex/common
```

## Components And Utilities

This snap no longer ships optional language tooling as snap components. Do not
reintroduce `components:` metadata or `tools-*` component parts unless the user
explicitly asks to restore that design.

The snap also no longer bundles broad utility families such as Git, ripgrep,
jq, Python tooling, Go, Rust, or native build tools. Under classic confinement,
Codex should use host development tools subject to normal user permissions and
Codex's own sandbox settings.

Keep the package lean. If adding a staged package, it should be something Codex
itself needs to run consistently from the snap, not general project tooling.

## Wrapper Behavior

`snap/local/codex-wrapper` is intentionally small:

- It prepends `$SNAP/usr/sbin:$SNAP/usr/bin:$SNAP/sbin:$SNAP/bin` to `PATH`.
  Classic snaps do not necessarily have those paths on `PATH` in every shell
  context, but Codex must reliably find its own bundled `bwrap` and argv0
  helpers.
- `CODEX_WRAPPER_DIAGNOSTIC=1 codex-wrapper` prints `CODEX_HOME`, `PATH`, and
  selected tool paths/versions.
- `CODEX_WRAPPER_TEST=1 codex-wrapper` sets up the app environment, starts the
  user's shell, and exits when that shell exits instead of launching Codex.
- Normal execution runs `migrate-codex-home` and then execs `$SNAP/bin/codex`.

The wrapper should not prepend snap component paths or set component-specific
Go, Rust, Python, compiler, include, or library environment variables.

## Snap And Sandbox Limitations

Classic confinement lets Codex behave much closer to non-snap installs, but it
does not remove every snap-related edge case.

Known behavior:

- Host tools installed as normal binaries, such as `/usr/bin/git` or
  `/usr/bin/gcc`, work as normal subject to Codex sandbox policy.
- Tools installed as other snaps, such as `/snap/bin/go` or `/snap/bin/rustc`,
  can run from a normal shell inside the classic Codex snap.
- The same `/snap/bin/*` tools may fail from inside Codex's nested `bubblewrap`
  command sandbox because they invoke `snap-confine` from within another
  sandbox namespace.

Do not diagnose `/snap/bin/*` failures inside Codex's command sandbox as a
broken Codex snap by default. Prefer host non-snap tools for sandboxed commands,
or run the snap-provided tool outside Codex's bwrap sandbox with the usual
approval/escalation path.

Codex currently emits a non-fatal warning like this in some classic-snap
contexts:

```text
WARNING: proceeding, even though we could not update PATH: Read-only file system
```

This warning does not by itself mean the snap failed to start.

## Validation Workflow

After rebuilding/installing the snap, run validation from inside the new snap
environment:

```sh
CODEX_WRAPPER_DIAGNOSTIC=1 codex-wrapper
tests/smoke-snap-components.sh
tests/smoke-home-migration.sh
```

`tests/smoke-snap-components.sh` is a classic snap runtime smoke test. It
checks wrapper diagnostics, packaged `bubblewrap`, and Codex argv0 helpers; it
does not expect optional tool components or bundled utility families.

Useful manual checks:

```sh
find "$SNAP" -maxdepth 4 \( -path '*/usr/bin/bwrap' -o -name yq -o -name rg -o -name git -o -name jq \) -ls
"$SNAP/usr/bin/bwrap" --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --chdir "$PWD" /bin/sh -c 'printf "bwrap-ok\n"'
```

Expected result:

- `bwrap` is present under the snap.
- broad utility commands such as `yq`, `rg`, bundled `git`, and bundled `jq`
  are absent unless they are introduced for a specific reason.
- direct `bwrap` execution works.

## Working Inside The Snap

Agents often run from inside the snap itself while debugging this project. Keep
these constraints in mind:

- The installed test snap may not match the source tree until the user rebuilds
  and reinstalls it.
- Use `rg` for searches when available.
- Do not edit or delete local `.snap`/`.comp` build artifacts unless explicitly
  asked.
- Be careful with dirty worktrees. Do not revert unrelated user changes.

## Review Checklist

Before handing back packaging changes, check:

- `snap/snapcraft.yaml` has the expected confinement and no stale component or
  interface declarations.
- `codex-wrapper` has valid shell syntax with `sh -n`.
- README documentation matches the current confinement and install command.
- Smoke tests match the current package shape.
- `git diff --check` passes for touched files.
