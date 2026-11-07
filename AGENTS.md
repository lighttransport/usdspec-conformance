# AGENTS.md

Guidance for coding agents working in usdspec-conformance.

This repository contains the Lean USD specification model and differential
conformance tests against LightUSD and OpenUSD. See `README.md` for setup and
`scripts/verify-local.sh` for complete local verification.

Repository-specific exception to Check 3 below: deliberately small, reviewed,
text USDA repro fixtures under `issues/` are permitted, alongside the canonical
text vectors under `tests/next/generated/lean/`. These are reproducible test
inputs, not captured customer assets. Compiled binaries, large assets, private
scene names, and machine-specific paths remain subject to the audit rules.

The pre-push policy below is copied verbatim from
`~/work/tinyusdz/dev/AGENTS.md`.

## Git Push Policy (mandatory pre-push checklist)

Pushing rewrites shared state. Before **any** `git push` (regular, force, or `--force-with-lease`), an agent must complete every step below. Skipping a step is a defect — pre-push hygiene is one of the few places in this repo where "ask first" beats "act first" by default, because once a 100 MB binary or a leaked credential lands on `origin` it is forever in the public Git history.

### 1. Audit the commits about to leave the machine

Always inspect the exact range you are pushing — `git log --oneline @{upstream}..HEAD` for a regular push, or `git log --oneline <remote-tip>..HEAD` for a force/lease push — and run the four checks below against **every** commit in that range, not just `HEAD`. Any single offending commit blocks the push; resolve via `git rebase -i` (drop / edit) or `git filter-repo` (path removal) before continuing.

#### Check 1 — Credentials & sensitive data

Never push a commit that contains, or has ever contained at any point in its history within the push range:

- API keys, bearer tokens, OAuth client secrets, AWS / GCP / Azure access keys, SSH private keys, PGP private keys, `.netrc`, `.env`, `.npmrc` with `_authToken`.
- Email/password pairs, JWTs, Slack/Discord/GitHub webhook URLs.
- Internal hostnames, VPN configs, customer asset paths that aren't already public.
- Personal user paths (`/home/<someone>/…`, `C:\Users\<someone>\…`) baked into source comments — embarrassing rather than dangerous, but still gets stripped.

How to check (run from the repo root, against the exact push range):

```bash
RANGE="$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream})..HEAD"
git diff "$RANGE" -- ':!**/*.md' ':!**/*.txt' \
  | grep -nIE 'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_\-]{35}|(?i)(api[_-]?key|secret|token|password|passwd|bearer|private[_-]?key)\s*[:=]' \
  || echo "No credential-shaped strings found in $RANGE"
```

This is a heuristic, not a guarantee. If a commit touches anything that *talks* to an external service (CI, package upload, asset server) eyeball the diff manually too.

##### Automated secret scanners (run when available — preferred over the grep heuristic)

When `gitleaks` and/or `trufflehog` are installed, run them over the **same push range** as a stronger, entropy- and rule-aware complement to the grep above. They do not replace the manual eyeball — they catch what the regex misses. **Any finding blocks the push** (resolve with `git rebase -i` / `git filter-repo`, treat the secret as compromised, and rotate before doing anything else). If a tool is missing, note that it was skipped and fall back to the grep heuristic.

```bash
# Same range as Check 1 (BASE..HEAD).
RANGE="${RANGE:-$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream})..HEAD}"
BASE="$(git rev-parse "${RANGE%%..*}")"
REPO="$(git rev-parse --show-toplevel)"
BRANCH="$(git branch --show-current)"
# trufflehog's go-git backend can't read a *worktree* `.git` file, so point it at
# the main worktree directory (its `.git` is a real directory) and pick the
# branch explicitly. For a normal checkout this resolves to the repo root.
MAIN_WT="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"

# gitleaks — handles worktrees natively; scans exactly the commits in the range
# via `git log` options. Exit 0 = clean, non-zero = leaks (or error). --redact
# keeps any secret out of logs/stdout.
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks detect --source "$REPO" --redact --log-opts="$RANGE" \
    && echo "gitleaks: clean over $RANGE" \
    || { echo "ABORT: gitleaks flagged secrets in $RANGE"; exit 1; }
else
  echo "gitleaks not installed; skipping (https://github.com/gitleaks/gitleaks). Rely on the grep heuristic above."
fi

# trufflehog — default binary at ~/go/bin/trufflehog, else PATH. Scans BASE..tip
# of $BRANCH; --fail exits 183 when results are found (verified live secrets +
# verification-errored). Add --only-verified for the lowest-noise gate.
TRUFFLEHOG="${TRUFFLEHOG:-$HOME/go/bin/trufflehog}"
[ -x "$TRUFFLEHOG" ] || TRUFFLEHOG="$(command -v trufflehog || true)"
if [ -n "$TRUFFLEHOG" ] && [ -x "$TRUFFLEHOG" ]; then
  "$TRUFFLEHOG" git "file://$MAIN_WT" --since-commit="$BASE" --branch="$BRANCH" --fail \
    && echo "trufflehog: clean over $RANGE" \
    || { echo "ABORT: trufflehog flagged secrets in $RANGE"; exit 1; }
else
  echo "trufflehog not installed; skipping (default path: ~/go/bin/trufflehog). Rely on the grep heuristic above."
fi
```

##### Proprietary asset names & personal paths — scan commit *messages*, not just the diff

The credential grep and the scanners above look at the code diff. Private
**asset filenames** (model/scene names, customer assets) and **personal paths**
leak just as easily through **commit messages** and **source comments** — e.g. a
perf note that says "model `PrivateScene_X.usdz` took 57 s", or a comment
`// e.g. CustomerScene: 5273 shaders`. Public history should describe *what*
changed in generic terms ("a ~5000-shader scene", "a reference folder scene"),
never the private asset that exercised it. Run both scans over the push range:

```bash
RANGE="$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream})..HEAD"

# (a) Personal paths in BOTH messages and source — must be empty.
{ git log "$RANGE" --format='%B'; git diff "$RANGE" -- 'src/*' 'web/*' 'python/*'; } \
  | grep -inE '/home/[a-z]|/Users/[A-Za-z]|C:\\Users\\' \
  && { echo "ABORT: personal path in messages or source"; } \
  || echo "clean: no personal paths"

# (b) Asset-filename tokens in messages + added source lines — EYEBALL each and
#     strip any that names a private/proprietary/customer asset. Generic names
#     (root.usdc, bare extensions, public samples) are fine.
{ git log "$RANGE" --format='%B'; git diff "$RANGE" -- 'src/*' 'web/*' 'python/*' | grep '^+'; } \
  | grep -oiE '[A-Za-z0-9_-]{3,}\.(usdz|usda|usdc|png|jpg|jpeg|exr|gltf|glb|fbx|obj)' \
  | sort -u
```

Any private asset name → rewrite before pushing. Messages:
`git filter-branch --msg-filter '…'` (or `git filter-repo --replace-message`;
`git rebase -i` if your harness allows it — some sandboxes block `-i`). Source
comments: edit + `git commit --amend` / rebase. **Re-run every Check 1 scan
(incl. the scanners) after the rewrite — the commit hashes change.**

#### Check 2 — No build artifacts

Build outputs do not belong in Git. They explode the pack size, cause merge conflicts on every rebuild, and routinely contain absolute paths from the developer's machine. If you find any of these in the push range, drop the file (and ignore the path going forward).

The common culprits in this repo:

- `build/`, `build_py/`, `build_py_ext/`, `build_test/`, `web/build/`, `web/build_64*/` — CMake / ninja output trees.
- `*.a`, `*.o`, `*.obj`, `*.so`, `*.dylib`, `*.dll`, `*.lib`, `*.pdb` — compiled object files / libraries.
- `python/lightusd/_core.abi3.so` — the editable-install Python extension binary; regenerated by `pip install -e .`.
- `*.ninja_deps`, `*.ninja_log`, `build.ninja`, `CMakeCache.txt`, `CMakeFiles/`, `CTestTestfile.cmake`, `compile_commands.json` — CMake/ninja state.
- `__pycache__/`, `*.pyc`, `node_modules/`, `dist/`, `*.egg-info/`.

Run from the repo root:

```bash
git diff --name-only "$RANGE" \
  | grep -E '^(build|build_py|build_py_ext|build_test|web/build)/|/CMakeFiles/|\.(a|o|obj|so|dylib|dll|lib|pdb|pyc|ninja_deps|ninja_log)$|/CMakeCache\.txt$|/CTestTestfile\.cmake$|/build\.ninja$|/_core\.abi3\.so$' \
  && { echo "ABORT: build artifacts staged for push"; exit 1; } \
  || echo "No obvious build artifacts in $RANGE"
```

`.gitignore` already covers all of the above; if a file shows up here it usually means it was either `git add`-ed with `-f`, or a previous mistake was rebased forward. Drop it; do not push it.

#### Check 3 — No unintended binary / asset data

USD asset files, Blender scenes, captured payloads, large images, and other binary art belong in external storage (Git LFS, Lighttransport's S3 bucket, the artist drop folder), not in the main repo history. Specifically reject:

- `*.blend`, `*.fbx`, `*.glb`, `*.gltf` larger than a few KB (small spec fixtures are OK), `*.abc`, `*.usdz` (zip), arbitrary `*.mb` / `*.ma`.
- `*.usd`, `*.usda`, `*.usdc` outside `tests/usda/`, `tests/usdc/`, `tests/feat/`, `models/`, `python/tests/` — these directories hold curated, deliberately-small fixtures; any ad-hoc capture goes elsewhere.
- `*.png`, `*.jpg`, `*.jpeg`, `*.exr`, `*.hdr`, `*.tif` over ~256 KB — texture captures are gitignored by default; small icons / spec test images are fine.
- Captured `.pdf` design docs (the AOUSD PDFs are explicitly gitignored under `aousd/*.pdf`; do not check them back in).
- `.codex`, `.claude/` and other AI tool scratch dirs.
- Anything you can't trivially regenerate from source.

Run from the repo root:

```bash
git diff --stat "$RANGE" \
  | awk '$3 ~ /^[0-9]+$/ && $3+0 > 256 { print }' \
  | head
# Inspect anything large; binaries show as "Bin <n> -> <m> bytes".

git diff --name-only "$RANGE" \
  | grep -iE '\.(blend|fbx|glb|gltf|abc|mb|ma|exr|hdr|tif|tiff|pdf)$|^data/.*\.usd[acz]?$|/captures?/' \
  && { echo "ABORT: unexpected binary/asset paths in $RANGE"; exit 1; } \
  || echo "No flagged binary/asset paths in $RANGE"
```

If a binary really must ship with the repo, the answer is git-lfs or an external asset bucket — never a plain `git add`. When in doubt, ask the user.

#### Check 4 — User permission (always, no exceptions)

After the three audits above pass, **stop and ask the user before pushing** — even if the user previously said "push when done", "go ahead and push", or has approved many pushes today. Authorization is single-shot and scoped to the immediate request. The default mode is "audit, summarize, ask, then push", in that exact order.

When asking, summarize what is about to be pushed:

- the branch name and remote (`origin/physics-2026`, etc.),
- whether it is a fast-forward or a force-push (force-pushes also need to spell out which previously-public commit hashes are being orphaned),
- the count of commits and a one-line per-commit summary,
- the audit results from checks 1–3 (e.g. "No credential-shaped strings, no build artifacts, no flagged binaries"),
- any pre-push test results worth surfacing (last unit / pytest run).

Do **not** assume "auto mode" or any prior `--yes`-style flag covers a push. Force-pushes especially need explicit, fresh confirmation; prefer `--force-with-lease` over `--force` when the user agrees to a force push, because lease refuses if the remote moved since the last fetch (avoiding the classic "I just clobbered a teammate's commit" failure).

### 2. After the push

- If the push was a force-push, immediately note the previous remote tip in the conversation so a teammate can recover their work (`git reflog show origin/<branch>` on their side, or `git fetch origin <old-sha>:refs/heads/recovered-<branch>`).
- Open / update the PR if one exists; the project's default PR base is `release`.
- Do not delete branches the user did not explicitly ask to delete.

### 3. If a check fails

- For a credential leak — **stop**, surface the leak to the user, and treat the credential as compromised even if the commit is still local. Rotate first, scrub history second; never push to "clean it up later."
- For a stray binary / artifact — drop it from history with `git filter-repo --invert-paths --path <p>` (or `git rebase -i` if it's a single recent commit), update `.gitignore`, then re-run the full checklist.
- For unintended assets — confirm with the user whether the asset belongs in Git LFS, an external bucket, or should simply be removed.

The Pre-push checklist is non-negotiable. A single 100 MB binary in `origin` permanently bloats every future clone of this repo; a single leaked key in `origin` is a security incident regardless of how fast it gets rotated.
