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

Tracked source lives in this directory and is served from two places:

- GitHub Pages (primary for the workbench):
  - `https://lighttransport.github.io/usdspec-conformance/browser/` (index)
  - `…/browser/app.html?case=LEAN-111` (case runner)
  - `…/browser/case/LEAN-111/case.json` and `…/case/LEAN-111/case.md` (agent data)
  Deployed by `.github/workflows/pages.yml`; enable it once in
  repo Settings → Pages → Source: **GitHub Actions**.
- Cloudflare Workers (main site):
  - `https://usdspec-conformance.lighttransport.workers.dev/browser/`
  - `…/browser/app.html?case=LEAN-111`

`wasm/manifest.json` URLs are relative to `browser/`, so the modules are served
from the same origin as the workbench on GitHub Pages.

## Case format

See `SCHEMA.md`. Bridge from the repo:
`case.cite.draft` → `issues/aousd/NN-*.md`, `case.cite.registry_row` →
`verif/lean/ISSUES.md`, ops modeled on the per-issue demo `run.py` and on
generated vectors.

## WASM artifacts

`wasm/*.wasm` is generated (git-ignored). Manifest file `wasm/manifest.json`
(tracked) pins each backend artifact: relative URL, SHA-256, size, source
revision. The `pages` workflow deploys the workbench as a GitHub Pages artifact
and, when the `wasm-phase1` release exists, downloads those binaries into
`_site/browser/wasm/` so they are served same-origin with the workbench.

Tooling:

- `build-wasm-lightusd.sh` — emsdk/emcmake build of LightUSD `next` wasm (phase 1)
- `smoke.mjs` — schema-validate every `case/*.json` (run from the repo root)

CI: `.github/workflows/browser-wasm.yml` builds the wasm on demand
(`workflow_dispatch`); `.github/workflows/pages.yml` deploys the workbench to
GitHub Pages on pushes that touch this directory or `pages/style.css`.
