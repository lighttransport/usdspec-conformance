# Crate: ValueRep flag bits, bootstrap size, PATHS counts and jump semantics do not match OpenUSD files

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Core File Formats → Binary → Preamble → Header / Bootstrap (L11691-11762); Paths Section (L11881-11983); Value Representations (L12049-12079)
**Formal reference:** `verif/lean/UsdSpec/Crate/ValueRep.lean` — `flagsMSB`, `flagsLSB`, `readings_differ_on_pxr_token`; `verif/lean/UsdSpec/Crate/Header.lean` — `bootstrapLen`, `spec_vs_pxr_bootstrapLen`; `verif/lean/UsdSpec/Crate/Paths.lean` — `specAlg`, `specAlg_diverges_on_pxr`, module doc; registry `LEAN-412`, `LEAN-413`, `LEAN-415`, `LEAN-416` (and `LEAN-411`, secondary)

Not covered by `01` (LZ4 chunk framing) or `12` (integer coding).

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

1. ValueRep, L12064-12079: "The last byte acts as bit flags … | Value is an Array | The last
   bit | Value is Inlined | The second last bit | Value is Compressed | The third last bit |".
2. Bootstrap, L11755-11758: "Table of Contents Offset … | 8 bytes |" then "| Reserved | 8
   bytes |". With the 16-byte header (L11697-11702) the bootstrap is 32 bytes.
3. PATHS, L11892-11894: "The section starts with an unsigned 64-bit integer representing the
   total number of paths, followed by three compressed integer arrays of equal length"; the
   table (L11898-11903) has one "Number of Paths" u64.
4. Jumps, L11943-11948: "`>0` An offset to a sibling relative to the current index; `0` This
   index only has siblings; `-1` The index only has a child; `-2` This index is a leaf".
   Algorithm L11980-11982: "If the jump value indicates it has siblings (0 or higher), then
   run this algorithm from the start with the starting index as the current X plus the jump
   value."

### Observation

1. **Bit order (LEAN-412).** "Last bit" can mean the MSB or the LSB of the flag byte. The inspected writer and reproduced files use the MSB reading (bits 63/62/61); an LSB reader (bits 56/57/58) misreads
   the reproduced inlined token value (`readings_differ_on_pxr_token`).
2. **Bootstrap size (LEAN-415).** OpenUSD reserves `int64_t[8]` (64 bytes), so the bootstrap
   is 88 bytes, not 32 (`spec_vs_pxr_bootstrapLen`), and OpenUSD rejects files smaller than
   88 bytes.
3. **Two counts (LEAN-416).** PATHS starts with two u64s: the size of the path table, then
   the number of encoded rows (the array length). They differ when the path table contains
   the empty path, which is never encoded, so path indices are not dense in the arrays.
4. **Jump 0 (LEAN-413).** OpenUSD writes `0` for "sibling only, which is the next row",
   i.e. X+1. The literal algorithm recurses at X+0 and never terminates
   (`specAlg_diverges_on_pxr`). `>0` means *both* a child (the next row) and a sibling at
   X+jump; the table mentions the sibling offset but omits the simultaneous child.
5. **Secondary (LEAN-411, wording).** The version table (L11744) says 0.4.0 "Compressed the
   Table of Contents Sections", but the TOC itself is never compressed (L11769-11782);
   OpenUSD's history says "0.4.0: Compressed structural sections."

### What OpenUSD does

Stock OpenUSD 26.11 (official `usd-core==26.11` wheel). Source:
`pxr/usd/sdf/crateFile.h` L84-86 (`_IsArrayBit = 1ull << 63`, `_IsInlinedBit = 1ull << 62`,
`_IsCompressedBit = 1ull << 61`), L479-486 (`_BootStrap { uint8_t ident[8]; uint8_t
version[8]; int64_t tocOffset; int64_t _reserved[8]; }`);
`pxr/usd/sdf/crateFile.cpp` L3534 ("File too small to contain bootstrap structure"),
L3143-3144 (writes `_paths.size()`), L3155-3159 (skips the empty path), L3378-3381 ("Write
the # of encoded paths. This can differ from the size of _paths since we do not write out
the empty path."), L3346-3353 (writer: both → `curIndex-thisIndex`, sibling only → `0`,
child only → `-1`, leaf → `-2`), L4051-4053 and L4084-4085 (reader: `thisIndex =
curIndex++`; `hasChild = jump > 0 || jump == -1`; `hasSibling = jump >= 0`), L409
("0.4.0: Compressed structural sections.").

`13-21-lean-demo/run.py` writes `crate_src.usda` (`/A{B{.x,.y},C}`, `/D`) as `.usdc`
with OpenUSD and decodes it:

```
21 version bytes: [0, 8, 0] | tocOffset: 591 | earliest section start: 136 | bytes 24..88 all zero: True
21 PATHS leading u64s: 7 7 | jumps: [-1, 5, 3, 0, -2, -2, -2]
21 decoded tokens: ['', 'A', 'B', 'x', 'y', 'C', 'D']
21 pxr reads it back: ['/', '/A', '/A/B', '/A/B.x', '/A/B.y', '/A/C', '/D']
21 ValueRep typeName   0x400b000000000006  top byte 0x40 (bit63 array=0 bit62 inlined=1 bit61 compressed=0) | LSB-of-flag-byte reading: bit56=0 bit57=0 bit58=0
21 references layer PATHS leading u64s: 3 2
```

Row 3 (`x`) has jump `0` and its sibling `y` is row 4; row 1 (`A`) has jump `5`: child `B`
at row 2 and sibling `D` at row 6. A layer with `references = @a.usda@` (empty prim path in
the path table) writes the counts `3, 2`.

### Request

1. ValueRep: name the bits explicitly (array = bit 63, inlined = bit 62, compressed = bit 61
   of the little-endian u64; i.e. the most significant bits of the flag byte).
2. Bootstrap: reserved is 64 bytes (8 × u64); the bootstrap is 88 bytes.
3. PATHS: two u64s — path-table size, then the encoded row count (= length of each array);
   the empty path is not encoded.
4. Jumps: `>0` child at X+1 and sibling at X+jump; `0` sibling at X+1 (no child); `-1`
   child at X+1; `-2` leaf. Fix the algorithm accordingly (continue at X+1; recurse at
   X+jump only for `>0`).
5. Version 0.4.0: "Compressed structural sections".

## Reviewer checklist

- [ ] Quoted text L11697-11702, L11755-11758, L11892-11903, L11943-11948, L11980-11982, L12064-12079, L11744.
- [ ] Read the cited `crateFile.h`/`crateFile.cpp` lines at v26.11.1.
- [ ] Run `13-21-lean-demo/run.py`; confirm the `21` lines (the decoder in `run.py` is ~40 lines of standalone LZ4 + integer decoding).
- [ ] Hand-run the spec algorithm on the jumps `[-1, 5, 3, 0, -2, -2, -2]` (expect no termination at row 3).
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "crate bootstrap"`, `"ValueRep"`, `"jump"`.
