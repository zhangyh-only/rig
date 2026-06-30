# Codex Hook Minimal Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `rig init --codex` install a usable Codex hook minimal loop for project convention injection and post-edit lint feedback.

**Architecture:** Keep hook logic shared between Claude and Codex, and split only the final output protocol through `hook-emit.sh`. Keep Codex registration isolated in `~/.codex/hooks.json` and avoid touching `~/.codex/config.toml`.

**Tech Stack:** Bash 3.2-compatible scripts, `jq`, Codex hook JSON output, existing `rig` CLI and shell test scripts.

---

### Task 1: Repair And Extend Codex Hook Tests

**Files:**
- Modify: `test/codex-hooks.sh`

- [ ] **Step 1: Write the failing test**

Add assertions that exercise both the existing output helper and the real hook scripts:

```bash
# inject-conventions real script in Codex mode should output hookSpecificOutput.additionalContext.
tmp="$(mktemp -d)"
mkdir -p "$tmp/docs/conventions"
printf '%s\n' '项目规范Y' > "$tmp/docs/conventions/code.md"
out="$(printf '{"prompt":"改代码","cwd":"%s"}' "$tmp" | "$HOOKS/inject-conventions.sh" --codex)"
if printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName=="UserPromptSubmit" and (.hookSpecificOutput.additionalContext | contains("项目规范Y"))' >/dev/null 2>&1; then
  ok "inject-conventions --codex -> additionalContext"
else no "inject-conventions --codex（实得：$out）"; fi
rm -rf "$tmp"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/codex-hooks.sh`
Expected now: fails before implementation, either with the existing quote syntax error or because `inject-conventions.sh --codex` still emits plain text.

- [ ] **Step 3: Keep test script Bash-compatible**

Fix command substitution quoting so `emit_deny` and `emit_block` tests run:

```bash
out="$(HOOK_MODE=codex bash -c ". '$HOOKS/hook-emit.sh'; emit_deny '红线R'")"; rc=$?
out="$(HOOK_MODE=codex bash -c ". '$HOOKS/hook-emit.sh'; emit_block '修我M'")"; rc=$?
```

- [ ] **Step 4: Re-run test**

Run: `bash test/codex-hooks.sh`
Expected: helper tests pass; real hook tests fail until Task 2 connects the shared output layer.

### Task 2: Connect Shared Output Layer To Hook Scripts

**Files:**
- Modify: `assets/dotfiles-layer/hooks/inject-conventions.sh`
- Modify: `assets/dotfiles-layer/hooks/lint-changed.sh`
- Existing helper: `assets/dotfiles-layer/hooks/hook-emit.sh`

- [ ] **Step 1: Add mode setup**

At the top of each real hook:

```bash
HOOK_MODE=claude
[ "${1:-}" = "--codex" ] && HOOK_MODE=codex
HOOK_EVENT=UserPromptSubmit
. "$(dirname "$0")/hook-emit.sh"
```

For `lint-changed.sh`, set `HOOK_EVENT=PostToolUse`.

- [ ] **Step 2: Accumulate output before emitting**

Change `inject-conventions.sh` from direct `echo` calls to a variable such as `context`, then call:

```bash
emit_context "$context"
```

Non-coding prompts should still emit the always layer if present; if no context exists, `emit_context ""` exits 0 silently.

- [ ] **Step 3: Route lint failures through `emit_block`**

Replace direct `stderr + exit 2` with:

```bash
emit_block "❌ 规范检查未通过：$file
请按下列问题修正后再继续：
$out"
```

Claude keeps the old `exit 2` behavior through the helper; Codex gets `{"decision":"block"}`.

- [ ] **Step 4: Verify**

Run: `bash test/codex-hooks.sh`
Expected: all Codex/Claude output mode assertions pass.

### Task 3: Add Codex Hook Installation To `rig init --codex`

**Files:**
- Modify: `bin/rig`
- Test: `test/codex-hooks.sh`

- [ ] **Step 1: Add a test for hooks.json generation**

In `test/codex-hooks.sh`, create a temp home and call a new install helper exposed from `bin/rig` if available, or exercise `rig init --codex` with `HOME="$tmp/home"` against a temp project:

```bash
home="$tmp/home"; proj="$tmp/project"
mkdir -p "$home" "$proj"
HOME="$home" "$ROOT/bin/rig" init --codex "$proj" >/dev/null
jq empty "$home/.codex/hooks.json"
jq -e '.hooks.UserPromptSubmit[0].hooks[0].command | contains("--codex")' "$home/.codex/hooks.json" >/dev/null
jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("lint-changed.sh")' "$home/.codex/hooks.json" >/dev/null
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/codex-hooks.sh`
Expected: fails because `bin/rig` still skips Codex global mechanism.

- [ ] **Step 3: Implement installation helpers in `bin/rig`**

Add helpers:

```bash
install_codex_hooks(){
  mkdir -p "$HOME/.codex"
  rm -rf "$HOME/.codex/hooks"
  ln -sfn "$HOME/.claude/hooks" "$HOME/.codex/hooks"
  write_codex_hooks_json "$HOME/.codex/hooks.json"
}
```

`write_codex_hooks_json` should create or merge the two commands idempotently with `jq`, preserving unrelated existing hooks.

- [ ] **Step 4: Update `init --codex` branch**

Replace the placeholder message with:

```bash
install_codex_hooks
echo "  ✓ Codex hooks 已写入 ~/.codex/hooks.json"
echo "  Codex 首次使用需在 /hooks 中 review + trust 这些 command hook；脚本变更后需重新 trust。"
```

- [ ] **Step 5: Verify idempotency**

Run: `bash test/codex-hooks.sh` twice.
Expected: both runs pass; generated `hooks.json` does not duplicate commands.

### Task 4: Update Verification And Docs

**Files:**
- Modify: `scripts/verify.sh`
- Modify: `README.md`
- Modify: `docs/INSTALL.md`

- [ ] **Step 1: Add Codex smoke checks**

Extend `verify.sh` to report `~/.codex/hooks.json` status when it exists, without failing Claude-only installs.

- [ ] **Step 2: Update public docs**

Change the status text that says Codex is only canonical/CI fallback. Document `rig init --codex`, the `~/.codex/hooks.json` location, and the `/hooks` trust step.

- [ ] **Step 3: Final verification**

Run:

```bash
bash test/codex-hooks.sh
bash test/eval-demo.sh
bash test/guard-bash.sh
bash test/resolve-self.sh
bash scripts/verify.sh /Users/zhangyh/rig
```

Expected: all repository tests pass except real `codex --version` remains blocked by the local ENOENT installation issue and is documented as an environment limitation.
