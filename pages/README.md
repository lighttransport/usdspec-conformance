# pages/ — static site

Minimal static web pages summarizing the LEAN formalization, its implementation
status (LightUSD, OpenUSD), current verification status, and the AOUSD spec
findings. For humans as `.html`, for AI agents as `.md` at the same path.

## Build

```sh
node pages/build.mjs    # from the repository root
```

The build uses Node built-ins only (no npm dependencies, no runtime JS, no CDN):
markdown is converted to HTML at build time by a small hand-written converter in
`build.mjs`. Output files land in this directory (`pages/`).

Cloudflare (git-connected Workers project, served at
`https://usdspec-conformance.lighttransport.workers.dev`): the repo-root
`wrangler.jsonc` declares the assets-only Worker (`assets.directory = ./pages`),
so Build & Deploy settings are:

- Build command: `node pages/build.mjs`
- Deploy command: `npx wrangler@4.158.0 deploy`
- (No Node/NPM version overrides needed; the build has zero dependencies.)
- The advanced "Root directory" should stay at the repo root, so `wrangler deploy`
  finds the tracked `wrangler.jsonc` (assets-only, serving `./pages`). If the
  deploy log shows an interactive "Detected Project Settings / Create
  wrangler.jsonc" wizard, it ran from the wrong directory.

For a classic Cloudflare **Pages** project instead, the equivalent settings are:
build command `node pages/build.mjs`, output directory `pages`, and the
advanced root directory left at the repo root.

Generated `pages/*.html` and the agent-facing copies `pages/*.md` are
git-ignored; only `build.mjs`, `style.css`, `pages/src/*.md` and this README are
tracked. Repo-relative links inside the source markdown are rewritten to
absolute GitHub source links (in-page links between converted pages become
relative `./<name>.html` links).

## Content map

| File | Source |
|---|---|
| `index.html` / `index.md` | hand-written intro: `src/index.md` |
| `status.html` / `status.md` | `doc/STATUS.md` |
| `formalization.html` / `formalization.md` | `verif/lean/README.md` |
| `reflection.html` / `reflection.md` | `verif/lean/REFLECTION.md` |
| `findings.html` / `findings.md` | `verif/lean/ISSUES.md` |
| `verification.html` / `verification.md` | `doc/validation/verification-2026-11-07.md` |
| `ledger.html` / `ledger.md` | `doc/validation/lean-followup-status.md` |

Note: `verif/lean/README.md` documents commands that require local generated
audit artifacts (`scripts/extract-usda-peg.py --lean`); that generation step is
a local/CI concern and is not published with the site.
