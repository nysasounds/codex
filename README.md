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

### Configuration

Configuration lives under `$HOME/snap/codex/current/.codex`

If you wish to, you could symlink this back to the standard/default location for convenience:
```
ln -s "${HOME}/snap/codex/current/.codex" "${HOME}/.codex"
```
