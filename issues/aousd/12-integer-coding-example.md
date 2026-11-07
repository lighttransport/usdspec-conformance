# Crate: integer-coding example input has a typo, and "relative to the previous value" suggests a second delta pass

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Core File Formats → Binary → Compression → Compressed Integer Arrays (L11600-11668)
**Formal reference:** `verif/lean/UsdSpec/Crate/IntegerCoding.lean` — `decode32_encode32`, the `LEAN-401`/`LEAN-402` examples; registry `LEAN-401`, `LEAN-402`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L11663-11667:

```
input = [123, 124, 125, 100125, 100125, 100126, 10026]
output = [int32(1) 01 00 00 11 01 00 01 XX int8(123) int32(100000) int8(0) int8(0)]
```

The earlier sample and its difference array (L11619-11623) use `100126` as the
last element. L11640: "Each value in the array of differences is then
converted to a code point and a value relative to the previous value."

### Observation

1. With `100126` the listed output is exactly the encoding (13 bytes:
   `01 00 00 00 C1 11 7B A0 86 01 00 00 00`). With `10026` the last difference
   is `−90100`, which needs a `11` code and an `int32`, giving 16 bytes.
   `10026` is a typo.
2. Both OpenUSD (`_EncodeIntegers`, `pxr/usd/sdf/integerCoding.cpp`) and the
   example encode each *difference* directly (`int32(100000)`, not `99999`).
   "Relative to the previous value" reads as a second delta pass over the
   differences, which would give `[123, −122, 0, 99999, −100000, 1, −1]`.
3. Unstated details: the code for element *i* is stored in bits `2(i mod 4)..2(i mod 4)+1`
   of code byte `floor(i/4)` (zero-based indices) (first element in the low bits; the example's `01 00 00 11`
   grouping reads like the opposite), and the most-common-delta tie-break
   (OpenUSD picks the largest value). The tie-break does not affect decoding.

### What OpenUSD does

`_EncodeIntegers` L268-322 / `_DecodeIntegers` L325-352 at v26.11.1, as above.
LightUSD's encoder emits the byte-identical 13-byte stream.

### Request

Change `10026` to `100126`; replace "a value relative to the previous value"
with "the difference itself, stored at the code's width"; state the in-byte
code order.

## Reviewer checklist

- [ ] Quoted text L11619-11623, L11640, L11663-11667.
- [ ] Hand-encode both inputs; confirm 13 vs 16 bytes.
- [ ] Read `_EncodeIntegers` (`codeByte |= code << (2*i)`) at v26.11.1.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "integer compression example"`.
