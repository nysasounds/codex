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

This snap uses classic confinement so Codex can behave closer to upstream install methods such as npm or Homebrew. Codex can use the host filesystem and host development tools subject to normal user permissions and Codex's own sandbox settings.

The default configuration location is still snap-managed; see [Configuration](#configuration) for details.

## Install

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-white.svg)](https://snapcraft.io/codex)

[![codex](https://snapcraft.io/codex/badge.svg)](https://snapcraft.io/codex)

Install from the global snap store

```
sudo snap install codex --classic
```

## Configuration

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
