# Issue drafts: independent review procedure

Local drafts, reproductions, and historical review/filing records. The
2026-11-04 review records AOUSD 01–04 as already filed; the Lean reports
08–21 remain local drafts in this checkout. Live upstream status must be
checked before filing. No review or edit here authorizes an upstream post.
Each draft was
written by one agent. Before anyone files it, a *second* agent or person
checks it from scratch using this procedure.

| Dir | Target | Items |
|---|---|---|
| `aousd/` | https://github.com/aousd/specifications-public/issues | `01`-`07`, one `.md` each (`01`-`04` already filed as #4-#7; `06`/`07` share the demo in `06-07-schema-demo/`; `08`-`12` were found by the Lean formalization in `verif/lean` (see `verif/lean/ISSUES.md`) and share the demo in `08-12-lean-demo/`; `13`-`21` are further Lean findings sharing `13-21-lean-demo/`) |
| `OpenUSD/` | https://github.com/PixarAnimationStudios/OpenUSD/issues | `01` (connection-target validation semantics), `03` (includeRoot schema fallback); `ISSUE.md` + repro files in each dir, superseded versions omitted |

## Scope

Keep reports and minimal repros that explain Lean models, specification defects,
USD semantic differences, or conformance-oracle behavior. General compiler bugs,
renderer/build troubleshooting and optional output-determinism feature requests
belong in their respective implementation repositories. Superseded incorrect
issue versions are omitted; retain the current report and its review evidence.

## Ground rules for the reviewer

1. **Don't trust the draft.** Treat every factual claim as unverified:
   quoted spec text, line and section names, code excerpts, command output,
   version numbers and "OpenUSD does X". Re-derive each one yourself.
2. **Use primary sources only:**
   - The spec: the vendored, byte-verified copies at
     `aousd/core/1.1.0/core_spec.md` in this repository. Historical 1.0.1
     comparisons require the separately identified LightUSD copy. Check them with `sha256sum -c SHA256SUMS`.
   - OpenUSD: the source tree at the stated tag (`git -C <OpenUSD> show v26.11.1:<path>`).
   - Behaviour: running the repro yourself.
3. **Use a stock OpenUSD.** The local fork carries extra patches, so prefer a
   clean `v26.11.1` build or an official wheel (`pip install usd-core==26.11`,
   if available). If you can only use the fork, say so in your verdict. State exactly which implementation and revision you ran;
   distinguish modified-fork observations from stock-oracle evidence.
4. **Search for duplicates.** Before recommending filing, search the target
   repo's open and closed issues and its recent commits. A fix may already be
   on `dev`.
5. **Check the claim, then the framing.** Is the report fair, minimal, and does
   it ask for one clear thing? Remove speculation that is presented as fact.
6. **Don't file anything.** Output a verdict per item. Filing is a human decision.

## Reproduce the Lean findings

From this repository's root, use the official wheel prepared by
`scripts/setup-oracle.sh` (or the full `scripts/verify-local.sh` setup):

```bash
env -u LD_LIBRARY_PATH -u PXR_PLUGINPATH_NAME \
  PYTHONPATH="$PWD/build/stock-openusd-oracle/site-packages" \
  python3.11 issues/aousd/08-12-lean-demo/run.py
env -u LD_LIBRARY_PATH -u PXR_PLUGINPATH_NAME \
  PYTHONPATH="$PWD/build/stock-openusd-oracle/site-packages" \
  python3.11 issues/aousd/13-21-lean-demo/run.py
```

The scripts locate their fixtures relative to their own file. Check the wheel's
ownership and version with `scripts/oracle-provenance.py` in the same isolated
environment. Do not substitute a patched local OpenUSD for stock evidence.

The AOUSD supplemental corpus is at
`~/.cache/lightusd/core-spec-supplemental-release_dec2025/releases/1.0.1`
(fetch with `scripts/fetch-aousd-supplemental.sh`; pinned `release/1.0.1.post0`).

## Verdict format (write one per item, for example `REVIEW.md` next to the draft)

```
Item: aousd/03-spline-keep-ratio-limit
Verdict: FILE | FILE AFTER EDITS | DO NOT FILE (duplicate / wrong / not a bug)
Reviewer environment: <OpenUSD build/tag, OS>
Claims checked:
  - [OK|WRONG|UNVERIFIED] <claim> — <how checked, what you saw>
Duplicates searched: <queries, links>
Required edits: <list, or none>
```

Each item's file ends with a **Reviewer checklist** of its specific claims.
