# Case schema (`case/*.json`)

One JSON file per registry finding ID. Conventions:

- IDs are the registry IDs from `verif/lean/ISSUES.md` (`LEAN-NNN`).
- Editor-editable layer texts are plain USDA text; the workbench runs the ops
  against each backend and diffs the outputs per op.
- Results are keyed by the op `id`. Backends either run live (WASM), or carry a
  recorded result until the WASM backend lands (`recorded: true`).
- `LEAN_TESTCASE` semantics borrowed from `tests/next/generated/lean/*.inc`
  (the Lean formalization's own expectations).

## Fields

| Field | Purpose |
|---|---|
| `id` | registry ID (matches the `case/` folder name) |
| `title` | one-line finding title |
| `cite` | `spec` (line cites), `decl` (Lean decl path), `registry_row`, `draft` (issue path), `repo_base` constant |
| `layers` | `{name, text}` pairs used by the ops interpreter |
| `ops` | `{id, op, …}` list (below); executed in order; individual failures are reported per op |
| `results` | `{lean: {…opId: value}, lightusd: {…}, oracle: {…}}` values shown per column; `recorded: "…" annotation field is allowed |
| `notes` | free-text explanation of the gap (markdown) |

## Ops

| op | args | semantics (also the WASM facade surface) |
|---|---|---|
| `open` | `stage` (root layer name), optional `session` | open the composed stage from the virtual layer FS |
| `getTimeSamples` | `attr` | values from `Usd.Attribute.GetTimeSamples()` |
| `get` | `attr`, `t` (number) | `Usd.Attribute.Get(t)` (default) or `Get(t, objectsArray)` |
| `getMetadata` | `prim`, `field` | `Usd.GetMetadata(field)` at prim |
| `customData` | `prim` | `GetPrimAtPath(prim).GetCustomData()` |
| `flatten` | — | full `UsdFlattenSessionLayer`-style export to text |
| `primIndex` | `prim`, `format: "json"` | `Pcp` prim index dump (JSON contract of `dump-pcp-oracle.py`) |
| `listOpApply` | `attr`, `op` (JSON listop) | apply a parsed list-op to an input sequence |
| `crateEncodeDecode` | `hex`, `mode` | wire-level vector ops (intcoding/LZ4/listop encoding) |
| `usdaRoundTrip` | `layer` | parse layer text and re-serialize (USDA text diff) |
| `parsePath` | `path` | `SdfPath` validity + element decomposition per PEG grammar |

New ops must be added here and to `lib/backend.js` (the single place that maps
ops to backend calls) — keep the op set small and deterministic.
