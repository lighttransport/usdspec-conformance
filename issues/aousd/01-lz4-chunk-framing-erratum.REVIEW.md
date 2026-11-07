Item: aousd/01-lz4-chunk-framing-erratum
Verdict: FILE AFTER EDITS (NOTE: already filed, unreviewed, as aousd/specifications-public#4 on 2026-11-04 by syoyo; body is the draft verbatim INCLUDING the "Reviewer checklist" section; apply the edits below to the filed issue)
Reviewer environment: OpenUSD source at tag v26.11.1 (git show), official PyPI wheel usd-core==26.11 (Python 3.11, Linux x86_64); vendored spec copies verified with `sha256sum -c SHA256SUMS` (1.1.0 and 1.0.1: OK)
Claims checked:
  - [OK] Prose and table quote: aousd/core/1.1.0/core_spec.md L11584-11598. Prose "unsigned 64-bit integer" for the count and "the first byte of each chunk is an unsigned 64-bit integer"; table "Number of Chunks | 8 bytes", "Chunk Size ... | 1 byte | Unsigned 8 bit integer". Ellipsis-elided quote is faithful.
  - [OK] 1.0.1 listed chunk size as "8 bytes | Unsigned 64 bit integer" (diff of the two vendored copies).
  - [OK] Version string "v1.1.0 (e8f44c0)" is core_spec.md line 3.
  - [OK] v26.11.1 pxr/base/tf/fastCompression.cpp: reader L96 `int nChunks = *compressed++;`, L111-113 memcpy of `int32_t chunkSize`; writer L61 `compressed[0] = 0` for single block, L68 `*compressed++ = nWholeChunks + (partChunkSz ? 1 : 0)`, per-chunk int32 size prefix (L70-74).
  - [OK] crateFile.cpp uses TfFastCompression::CompressToBuffer / DecompressFromBuffer (L3105-3107, 3446-3447, 3675, 3837); enclosing sections store their own uint64 sizes.
  - [OK] GetMaxInputSize() = 127 * LZ4_MAX_INPUT_SIZE (L24-26), so at most 127 chunks.
  - [OK] Hex check: exported a small .usdc with usd-core 26.11; TOKENS section = numTokens 12, uncompressed 85, compressed 88 (three uint64), then the first byte of the LZ4 buffer is 0.
  - [WRONG/imprecise] "Number of Chunks ... unsigned 8-bit integer": OpenUSD reads it through `char const*` into an int, i.e. plain `char` (signed on x86-64/most ABIs). Values 128-255 would be read as negative. The 127 cap is what makes it portable; the spec should say "8-bit count, 0-127" rather than "unsigned 8-bit (0-255)".
Duplicates searched: `gh search issues --repo aousd/specifications-public` for "LZ4", "chunk": only #4 (this draft, already filed). No other matches.
Required edits:
  1. Remove the "## Reviewer checklist" section from the filed #4 (internal review notes are public now).
  2. Describe the count byte as "1 byte, value 0-127 (OpenUSD reads it as a plain char, so values >127 are not portable)" instead of "unsigned 8-bit integer".
  3. Optional: say that the 1.0.1 table was also wrong for the count field (8 bytes); 1.1.0 only changed the chunk-size row.
