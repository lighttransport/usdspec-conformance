# pages/browser — USD spec gap workbench

An interactive reproduction/verification site for each registry finding: a
minimal repro (editable multi-layer USDA plus a short ops list) executed
against the same three sources of truth, side by side:

| Column | Content | Live? |
|---|---|---|
| Spec / Lean model | Expected results from the Lean formalization (generated vectors + registry row) | precomputed in `case.json` |
| LightUSD | LightUSD `next` WASM or a recorded native run until the WASM lands | live when `wasm/manifest.json` pins an artifact |
| OpenUSD oracle | Stock OpenUSD 26.11 WASM (Phase 2) or a recorded native run | live after Phase 2 |

"Compiler Explorer, for USD spec gaps": humans get `.html`+JS, AI agents get
the same content as `case.md`/`case.json`.

## Serving

Tracked source lives in this directory; the Workers assets config (`./pages`)
serves it at:

- `https://usdspec-conformance.lighttransport.workers.dev/browser/` (index)
- `…/browser/app.html?case=LEAN-111` (case runner)
- `…/browser/case/LEAN-111/case.json` and `…/case/LEAN-111/case.md` (machine/agent data)

## Case format

See `SCHEMA.md`. Bridge from the repo:
`case.cite.draft` → `issues/aousd/NN-*.md`, `case.cite.registry_row` →
`verif/lean/ISSUES.md`, ops modeled on the per-issue demo `run.py` and on
generated vectors.

## WASM artifacts

`wasm/` is generated (git-ignored). Manifest file `wasm/manifest.json`
(tracked) pins each backend artifact: URL, SHA-256, size, source revision.
Artifacts are published to **GitHub Pages** via a release asset upload in CI:
each manifest entry contains `url`, `sha256`, `size`, `source_revision`;
the site's JS fetches them from the GitHub Release assets (no CORS issues for same-origin Worker).

- `build-wasm-lightusd.sh` — emsdk/emcmake build of LightUSD `next` wasm (phase 1)
- `upload-wasm.sh` — push artifacts to R2 and update `wasm/manifest.json`
- `smoke.mjs` — schema-validate every `case/*.json` and check case.md mirrors

CI: `.github/workflows/browser-wasm.yml` runs the same scripts on demand
(`workflow_dispatch`; no nightly auto-rebuild).
