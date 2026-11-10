# UsdSpecC — MiniC semantics and C ↔ Lean bridge for `lspec_*` kernels

Vendored MiniC (`Semantics.lean` + `Logic.lean` + `Hoare.lean`) from
`tinygltf/formal/GlTF/C/` (MIT). Same byte-addressed little-endian semantics,
explicit `Res.ub` for C11 undefined behaviour, F64 bit-pattern comparisons.

Pipeline:

- `tools/lean2c.py` — Lean spec → generated C11 (`lightusd-c/src/internal/lusd_spec_*.c`, DO NOT EDIT).
- `tools/c2lean.py` — generated C → `UsdSpecC/Gen.lean` (MiniC deep embedding, DO NOT EDIT).
- `tools/gen_xid.py` — `Unicode/XidTable.lean` → XID tables in `lusd_spec_codecs.c` (numeric-only).
- `tools/cdiff.py` — 3-way diff (compiled C == MiniC `usdspec-cdiff` == Python-Lean; MiniC covers `most_common`/`contains`/`crate_enc`/`crate_dec`/`listop_apply`/`listop_iterate`/`listop_reduce`/`listop_combine`/`dict_merge`/`dict_lookup`/`ts_held_bits`/`ts_linear`/`scan_quoted`/`quote_len`/`offset_valid`/`offset_sanitize`).

## Spec ↔ C map (v1 T1+T2+T3)

| Lean | C (`src/internal/lusd_spec_*`) |
|---|---|
| `UsdSpec.Crate mostCommon/encode32/decode32` | `lspec_crate_*` |
| `UsdSpec.ListOp apply/combine/reduce/iterate` (Int64) | `lspec_listop_i64_*` |
| `UsdSpec.Dict merge` (flat uint32 keys) | `lspec_dict_*` |
| `UsdSpec.LayerOffset valid/sanitize` (+ numeric compose/apply) | `lspec_offset_*` |
| `UsdSpec.ValueResolution.TimeSamples eval` | `lspec_ts_*` |
| `UsdSpec.Usda quoteString/scanQuoted` + `Unicode XID` | `lspec_quote_len` / `lspec_scan_quoted` / `lspec_is_xid_*` |

Build:

```sh
cd verif/lean && lake build UsdSpecC usdspec-cdiff
python3 tools/c2lean.py --check   # Gen.lean matches lusd_spec_*.c
python3 tools/lean2c.py --check   # lusd_spec_*.c matches lean2c templates
python3 tools/gen_xid.py --check  # XID tables match XidTable.lean
python3 tools/cdiff.py --n 200    # C == MiniC == Python-Lean
```
