Item: aousd/02-schema-family-underscore-digit-name
Verdict: FILE AFTER EDITS (NOTE: already filed, unreviewed, as aousd/specifications-public#5 on 2026-11-04; body is the draft verbatim INCLUDING the "Reviewer checklist" section)
Reviewer environment: official PyPI wheel usd-core==26.11 (Python 3.11, Linux x86_64); OpenUSD source tag v26.11.1 (pxr/usd/usd/schemaRegistry.h); vendored spec 1.1.0 (sha256 OK)
Claims checked:
  - [OK] Grammar quoted exactly: core_spec.md L8253-8269 (AsciiStart, AsciiContinue, SchemaName, Family, Version), section "Schema Families and Versioning".
  - [OK] Hand parse of `_1`: Family must start with AsciiStart, which consumes `_`; at `1` the lookahead `'_' Version !AsciiContinue` cannot match (next char is not `_`), so AsciiContinue consumes `1`; the optional `('_' Version)` then has nothing to match. Result: unversioned family `_1`. Same procedure gives `Foo_1_2` -> family `Foo_1`, version 2 (the `!AsciiContinue` blocks the split at `_1_`).
  - [OK] The prose after the grammar ("if a schema name ends with an underscore followed by one or more digits ... the remainder is the family name") gives an empty family for `_1`; real contradiction.
  - [OK] Every table cell re-run with usd-core 26.11:
      `_1` -> ('', 1), family allowed False, Make -> `_1`, IsAllowedSchemaIdentifier False
      `Foo_1_2` -> ('Foo_1', 2), False, `Foo_1_2`, False
      `Foo_0` -> ('Foo', 0), True, `Foo`, False
      `Foo_01` -> ('Foo', 1), True, `Foo_1`, False
      `A_99999999999` -> ('A', 4294967295), True, `A_4294967295`, False
      `Foo_1` -> ('Foo', 1), True, `Foo_1`, True;  `Mesh` -> ('Mesh', 0), True, `Mesh`, True
  - [OK] schemaRegistry.h doc comments: IsAllowedSchemaFamily = valid identifier that does not itself contain a version suffix (non-empty follows from valid identifier); IsAllowedSchemaIdentifier = parses to an allowed family and equals MakeSchemaIdentifierForFamilyAndVersion(family, version); Make with version 0 returns the bare family. ParseSchemaFamilyAndVersionFromIdentifier doc says the suffix is "an underscore followed by a positive integer", which also supports "version 0 == unversioned".
  - [OK] The spec has no "allowed schema identifier" concept (`grep -i allowed | grep -i schema`: no hits).
  - [OK, minor] `MySchema_` (spec table row) is also accepted by OpenUSD (family `MySchema_`, allowed True), so it is consistent; no change needed.
Duplicates searched: `gh search issues --repo aousd/specifications-public` "schema family", "underscore": only #5 (this draft).
Required edits:
  1. Remove the "## Reviewer checklist" section from the filed #5.
  2. Optional: in Case 1, cite OpenUSD's own doc string ("a positive integer") as the source of the version-0 and empty-family behaviour, so the request reads as "align the spec with this documented rule or say it is implementation-defined".
  3. Otherwise accurate; the four cases are fine as one issue because they are one grammar section.
