---
name: sync
description: Pull from the remote, stage any unstaged changes, commit them with a clear message, and push. Use when the user says "sync", "/sync", "sync the repo", or asks to pull-then-push their work in one shot.
---

# sync

One-shot "pull, commit anything pending, push" for the current branch. Use this when the user wants their local work synced with the remote in a single step.

## Steps

Run these in order. Stop and surface the problem to the user if any step fails — do not invent workarounds (no `--no-verify`, no `--force`, no `reset --hard`).

### 1. Snapshot current state

Run these in parallel:
- `git status` — see what's modified/untracked.
- `git rev-parse --abbrev-ref HEAD` — current branch.
- `git rev-parse --abbrev-ref --symbolic-full-name @{u}` — upstream. If this errors, the branch has no upstream — tell the user and ask whether to set one (`git push -u origin <branch>`) before continuing.

### 2. Pull

`git pull --rebase` on the current branch.

- If the working tree is dirty, prefer `git pull --rebase --autostash` so local changes are stashed and reapplied around the pull.
- If the rebase hits a conflict, **stop**. Show the conflicting paths and ask the user how to proceed. Do not run `git rebase --abort` or `--skip` without explicit confirmation.

### 3. Stage + commit (only if there are changes)

After the pull, re-run `git status --porcelain`. If it's empty, skip to step 4.

Otherwise:
- Run `git diff` (unstaged) and `git diff --cached` (staged) to understand what changed.
- Stage with specific paths: `git add <path1> <path2> …`. Avoid `git add -A` / `git add .` — they can sweep in `.env`, credentials, build artifacts, or other files the user didn't intend to commit. If you see anything that looks sensitive (`.env`, `*.key`, `*.pem`, `credentials*`, tokens), flag it to the user before staging.
- Draft a commit message that describes **why** the change was made, not just what files moved. Match the style of recent commits — check `git log -5 --oneline` first. Most commits in this repo are short imperative subjects (e.g. "spotify fix", "pinned apps", "quicshell ui notifications"); follow that convention unless the change really needs a body.
- Commit with a HEREDOC so formatting is preserved:

  ```
  git commit -m "$(cat <<'EOF'
  <subject line>

  <optional body explaining why>
  EOF
  )"
  ```

- **Do not** append a `Co-Authored-By` trailer, do not add the Claude Code generator footer, and do not use `--amend`. If a pre-commit hook fails, fix the underlying issue and create a **new** commit — never `--no-verify`.

### 4. Push

`git push` to the tracked upstream. If the upstream rejects the push as non-fast-forward (someone pushed between step 2 and step 4), re-run from step 2 — do **not** use `--force` or `--force-with-lease` without the user explicitly asking.

### 5. Report

End with one short line: branch name, what was committed (subject only), and that the push succeeded. Example: `main: committed "fix battery glyph poll", pushed.` If nothing was committed: `main: already clean, pulled + pushed (no-op).`

## What this skill does NOT do

- Does not create branches, switch branches, or open PRs.
- Does not run tests, linters, or builds — the pre-commit hook (if any) handles that.
- Does not resolve merge/rebase conflicts automatically.
- Does not stage files that look like secrets without confirmation.
