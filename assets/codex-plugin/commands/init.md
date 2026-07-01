# /rig:init

Initialize the current project with rig for the current Codex session.

## Workflow

1. Run `rig init --codex "$PWD"`; if `rig` is not on `PATH`, try `~/.codex/skills/rig/bin/rig init --codex "$PWD"` or `~/.agents/skills/rig/bin/rig init --codex "$PWD"` after confirming the file exists.
2. Treat this as **project-level initialization for Codex**, even if the same repository was already initialized by Claude Code. Tool-specific wiring is expected.
3. After the mechanical install, read the `rig` skill instructions and finish the judgment work:
   - collect existing rule files into `docs/conventions/` without deleting the originals;
   - derive build/test/run commands from project files and update `AGENTS.md`;
   - replace placeholder `scripts/verify-local.sh` with real project commands;
   - check missing support components such as openspec, superpowers, and feature-spec, asking before any network install.
4. Run `rig doctor "$PWD"` and report what changed, what is still pending, and whether a new Codex session is needed.

Do not pretend external marketplace skills were installed if Codex cannot install them directly. Ask the user to install those and continue afterward.
