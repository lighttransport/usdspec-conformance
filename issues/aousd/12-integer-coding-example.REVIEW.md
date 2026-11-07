Item: aousd/12-integer-coding-example
Verdict: FILE
Reviewer: independent follow-up session; these drafts predate this review.
Reviewer environment: Linux x86-64, CPython 3.11, official PyPI usd-core==26.11;
source inspected with git show v26.11.1:<path>, not the fork working tree.
Specification: byte-verified core/1.1.0/core_spec.md at published commit
83e25aceb11a9340db4778263bda5d5175875f49. Vendored text was not modified.

Claims checked:
  - [OK] The printed final input differs from the earlier sample and difference array.
  - [OK] Independent encoder replay gives the claimed 13-byte corrected stream and a 16-byte printed-input stream.
  - [OK] Tagged _EncodeIntegers uses one delta pass, little-endian widths, low-bit-first codes, and largest-value frequency ties.

Runtime evidence: [review output](REVIEW-2026-11-06/integer-coding-check.txt).
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

Edits applied: Added stock-oracle provenance and a frozen published specification link.
Required edits: none for these checked claims. A human decides whether to file;
no report has been filed by this review.
