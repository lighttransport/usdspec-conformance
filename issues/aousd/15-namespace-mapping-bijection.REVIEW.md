Item: aousd/15-namespace-mapping-bijection
Verdict: FILE
Reviewer: independent follow-up session; these drafts predate this review.
Reviewer environment: Linux x86-64, CPython 3.11, official PyPI usd-core==26.11;
source inspected with git show v26.11.1:<path>, not the fork working tree.
Specification: byte-verified core/1.1.0/core_spec.md at published commit
83e25aceb11a9340db4778263bda5d5175875f49. Vendored text was not modified.

Claims checked:
  - [OK] Longest-prefix substitution alone collides under identity plus a nonidentity mapping.
  - [OK] Tagged _Map enforces inverse consistency; stock MapFunction rejects the shadowed path and confirms identity-sensitive composition.
  - [OK] The existing spec table uses (/A,/B), so its missing shadowed source is /B, unlike the reversed internal-reference example.

Runtime evidence: [review output](REVIEW-2026-11-06/stock-13-21.txt).
Formal evidence: lake build, usdspec-test, and committed-vector drift check pass.
This verdict concerns the stated counterexamples and requested clarification;
it does not certify completeness of the whole formalization or C++ implementation.

Duplicates searched: fetched all open/closed issues and the recent commit history
from aousd/specifications-public on 2026-11-06. Retained API responses are in
REVIEW-2026-11-06/upstream-issues.json and upstream-commits.json. Six issues
and the v1.1.0 publication PR were present. No duplicate of this report was found.
Related published reports: [statement separators](https://github.com/aousd/specifications-public/issues/3),
[LZ4 framing](https://github.com/aousd/specifications-public/issues/4), and
[relocated class targets](https://github.com/aousd/specifications-public/issues/7)
cover different defects; local 15–17 and 20 cross-reference their shared context.

Edits applied: Framed the domain as a partial bijection and corrected the shadowed path in the existing table to /B.
Required edits: none for these checked claims. A human decides whether to file;
no report has been filed by this review.

Follow-up recheck (2026-11-07): Removed the stale candidate label for confirmed secondary registry entries.
See [the consolidated recheck](REVIEW-2026-11-07.md) for scope and evidence.
