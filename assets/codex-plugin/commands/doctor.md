# /rig:doctor

Run rig health checks for the current project and diagnose failures.

## Workflow

1. Run `rig doctor "$PWD"`; if `rig` is not on `PATH`, locate the `rig` skill/package root and use its `bin/rig`.
2. Report the verification sections exactly enough for the user to see which checks passed or failed.
3. For failures, identify the likely root cause before proposing writes:
   - missing global bootstrap or hook registration;
   - missing `jq`;
   - hook changes that require a new session;
   - project not initialized with `/rig:init` for the current AI tool;
   - placeholder or broken `scripts/lint-one.sh` / `scripts/verify-local.sh`.
4. Ask before network installs or destructive changes. For local deterministic fixes, make the smallest safe change and rerun `rig doctor`.
