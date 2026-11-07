# Licensing remediation — 2026-11-07

Current source changes address the publication review's identified notice and
bulk transformed-grammar concerns. They are not a legal certification or a
statement that all old repository history is ready for public distribution.

- Added the complete Unicode V3 notice, source attribution and
  hashes. Unicode generators retain data-license pointers in generated tables.
- Added `THIRD_PARTY_NOTICES.md`, separating original Apache-2.0 work from
  licensed unmodified AOUSD excerpts, Unicode data.
  No blanket fair-use or clean-room assertion is used.
- Replaced the committed full expanded/repaired grammar with an import facade.
  CTest automatically generates the ignored local audit module, even with
  filtered test selection. The original specification's hashes are verified
  before transformation. Full generated audit sources/compiled modules are not
  part of source distribution and must not be published without a suitable basis.
- Replaced embedded repaired production text in the extractor with AST edit
  operations. Structural comparison with the prior generator output is exact;
  generated vectors have no drift. Original mathematical models and proofs remain.
- Removed four repaired specification-example layers. Independently authored
  Sdf API controls exercise the same opinion-versus-nospec distinction and assert
  both inherit and specialize cases against stock OpenUSD 26.11.
- Future CI caches only Lake dependencies, not the project's compiled audit data.
- Added a license/provenance boundary gate and an automatic grammar fixture.

Validation: full configured suite **39/39 passed, zero skips**, in 269.17 seconds.
The axiom audit and both stock/local strict PCP ratchets pass. Clean source
snapshot tests also exercise generation from absent local grammar data.
Execution evidence: ignored `build/license-review/` and `build/license-results.xml`.

Follow-up: the historical full grammar tables and repaired example layers are
being purged from every revision intended for publication, with complete notices
backfilled. Old Actions runs and their cache were deleted as authorized. Private
recovery bundles remain under ignored `build/` and must not be published.
The history rewrite is prepared locally; its remote update requires an explicit
lease-protected force-push. Visibility is unchanged.
