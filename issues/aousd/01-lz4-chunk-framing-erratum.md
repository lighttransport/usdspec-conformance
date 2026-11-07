# LZ4 compressed-buffer framing: field widths contradict OpenUSD (and the prose)

**Type:** bug / erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Binary File Format → Compression → LZ4 Compression

### What the spec says

Prose:

> LZ4 compressed data buffers will store the number of chunks as their first element, as an unsigned 64-bit integer.
> … the first byte of each chunk is an unsigned 64-bit integer representing the size of the chunk in bytes.

Table (changed in 1.1.0; 1.0.1 listed the chunk size as 8 bytes):

| Description | Size | Value |
|---|---|---|
| Number of Chunks | 8 bytes | Unsigned 64 bit integer |
| Chunk Size . Only exists if number of chunks > 0 | 1 byte | Unsigned 8 bit integer |

The prose and the table disagree with each other ("first byte … is an unsigned 64-bit integer" is also self-contradictory), and neither matches the OpenUSD implementation.

### What OpenUSD writes and reads

`pxr/base/tf/fastCompression.cpp` (`TfFastCompression`, used by the crate format):

```cpp
int nChunks = *compressed++;            // 1 byte: number of chunks
...
int32_t chunkSize = 0;                  // per chunk: signed 32-bit size
std::memcpy(&chunkSize, compressed, sizeof(chunkSize));
compressed += sizeof(chunkSize);
```

So the actual layout is:

| Description | Size | Value |
|---|---|---|
| Number of Chunks | **1 byte** | unsigned 8-bit integer (0 = a single LZ4 block follows) |
| Chunk Size (per chunk, only if number of chunks > 0) | **4 bytes** | signed 32-bit little-endian integer |
| Chunk Data | Chunk Size bytes (or the rest of the buffer when the count is 0) | |

Every `.usdc` written by OpenUSD with compressed sections uses this layout; a reader built from the 1.1.0 table cannot read them.

### Suggested fix

Replace the prose and table with the layout above. Also worth stating: OpenUSD limits the input to `127 * LZ4_MAX_INPUT_SIZE`, so its writer emits at most **127 chunks**, not the full 255 representable by an unsigned byte. Each chunk decompresses to at most `LZ4_MAX_INPUT_SIZE` bytes (OpenUSD splits larger inputs).

This table describes the inner compressed-buffer framing. Enclosing crate sections can separately store unsigned 64-bit uncompressed/compressed lengths; those fields must not be confused with the chunk count or per-chunk size.

### Context

Found while auditing LightUSD (an independent implementation) against v1.1.0. LightUSD follows the OpenUSD layout, since that is what real files contain.

## Reviewer checklist

- [ ] The quoted prose and table match `aousd/core/1.1.0/core_spec.md` exactly
      (`grep -n "Number of Chunks" -B12 -A4 aousd/core/1.1.0/core_spec.md`).
- [ ] 1.0.1 really listed the chunk size as 8 bytes
      (`diff aousd/core/1.0.1/core_spec.md aousd/core/1.1.0/core_spec.md | grep "Chunk Size"`).
- [ ] OpenUSD layout: read `pxr/base/tf/fastCompression.cpp` at `v26.11.1`.
      Expect `int nChunks = *compressed++;` (1 byte) and a `memcpy` of an
      `int32_t chunkSize` before each chunk.
- [ ] That crate sections use `TfFastCompression`; distinguish their enclosing
      64-bit lengths from the inner framing (`grep -n "TfFastCompression" pxr/usd/sdf/crateFile.cpp`).
- [ ] Confirm `GetMaxInputSize()` limits the writer to 127 chunks.
- [ ] Optional: hex-dump a compressed section of a real `.usdc` and check
      the first byte is a small chunk count (typically 0).
- [ ] Search specifications-public issues for "LZ4" / "chunk".
