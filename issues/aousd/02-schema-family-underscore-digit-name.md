# Schema families: clarify names that are only `_<digits>` (e.g. `_1`), and version `0`

**Type:** clarification
**Spec:** USD Core Specification v1.1.0, Schemas → Schema Families and Versioning

### Grammar as written

```
SchemaName <- Family ('_' Version)?
Family     <- (AsciiStart) (!('_' Version !AsciiContinue) AsciiContinue)*
Version    <- [0-9]+
```

### Case 1: `_1`

`Family` must consume at least one `AsciiStart`, and `_` is an `AsciiStart`. So the grammar parses `_1` as the **unversioned family `_1`**: the leading `_` is the family's first character, and `1` can't then start a `'_' Version` suffix.

OpenUSD 26.11 parses it differently:

```python
>>> Usd.SchemaRegistry.ParseSchemaFamilyAndVersionFromIdentifier('_1')
('', 1)
>>> Usd.SchemaRegistry.IsAllowedSchemaFamily('')
False
```

The prose immediately after the grammar says that a trailing underscore followed by digits is interpreted as the version and the remainder as the family. For `_1`, that prose yields an empty family, contradicting the PEG decomposition above.

Please reconcile the grammar and prose and state which reading is intended: `_1` as an unversioned family `_1`, or as version 1 of an empty (and therefore invalid) family. If empty families are invalid, explicitly exclude these names rather than allowing empty families generally.

### Case 2: version `0` and leading zeros

The table has no row for `Foo_0` or `Foo_01`. In OpenUSD:

| Name | OpenUSD family | OpenUSD version | `MakeSchemaIdentifierForFamilyAndVersion` |
|---|---|---|---|
| `Foo_0` | `Foo` | 0 | `Foo` (version 0 == unversioned) |
| `Foo_01` | `Foo` | 1 | `Foo_1` |

These parsing/rebuilding results do **not** establish schema aliases: `Foo_0` and `Foo_01` both fail OpenUSD’s `IsAllowedSchemaIdentifier` check (see below). The grammar accepts both spellings but does not by itself define version equality or identifier validity constraints. Please specify:

- whether version 0 is equivalent to unversioned;
- whether a version is compared as a number (`01` == `1`) or as a string;
- whether `Foo_0` and `Foo_01` are valid schema names.

The answers also affect the rule "a versioned schema must not inherit from another schema in the same family": is `Foo_0` versioned?

### Case 3: overflow (minor)

`Version <- [0-9]+` is unbounded; OpenUSD saturates at `UINT32_MAX` (`A_99999999999` → version 4294967295). A stated range would help.

### Case 4: OpenUSD rejects names the grammar accepts

OpenUSD only treats an identifier as valid if it parses into an *allowed* family and rebuilds to exactly itself (`UsdSchemaRegistry::IsAllowedSchemaIdentifier`). An allowed family must be non-empty and must not itself end in `_<digits>`. With v26.11.1:

| Name | Spec grammar | OpenUSD `IsAllowedSchemaIdentifier` |
|---|---|---|
| `Foo_1` | family `Foo`, version 1 | True |
| `Foo_1_2` | family `Foo_1`, version 2 | **False** (family `Foo_1` not allowed) |
| `Foo_0` | family `Foo`, version 0 | **False** (rebuilds as `Foo`) |
| `Foo_01` | family `Foo`, version 01 | **False** (rebuilds as `Foo_1`) |
| `_1` | family `_1`, unversioned | **False** |
| `A_99999999999` | family `A`, version 99999999999 | **False** (saturates, rebuilds as `A_4294967295`) |

The spec has no equivalent of "allowed schema identifier", so a name can be valid per the spec and rejected by OpenUSD. Please either add these constraints, i.e. a family must not end in `_<digits>`, versions are canonical decimal >= 1 with no leading zeros, plus an upper bound; or state that they are implementation-defined.

### Context

LightUSD follows the grammar literally (`_1` is an unversioned family `_1`; `Foo_0` has an explicit version 0) and saturates like OpenUSD. It will follow whatever the clarification decides.

## Reviewer checklist

- [ ] The grammar is quoted exactly
      (`grep -n "^SchemaName\|^Family \|^Version " aousd/core/1.1.0/core_spec.md`).
- [ ] Hand-parse `_1` against the PEG (Family needs one `AsciiStart`, then the
      negative lookahead) and confirm the draft's reading: an unversioned
      family `_1`.
- [ ] Re-run with OpenUSD and compare every table cell:
      ```python
      from pxr import Usd; R = Usd.SchemaRegistry
      for n in ['_1','Foo_1_2','Foo_0','Foo_01','A_99999999999','Foo_1','Mesh']:
          f, v = R.ParseSchemaFamilyAndVersionFromIdentifier(n)
          print(n, f, v, R.IsAllowedSchemaFamily(f),
                R.MakeSchemaIdentifierForFamilyAndVersion(f, v),
                R.IsAllowedSchemaIdentifier(n))
      ```
- [ ] Check `pxr/usd/usd/schemaRegistry.h` doc comments for
      `IsAllowedSchemaFamily` / `IsAllowedSchemaIdentifier`. Confirm the rules
      the draft attributes to OpenUSD (non-empty family, no trailing
      `_<digits>`, must round-trip).
- [ ] Confirm the spec defines no "allowed identifier" concept
      (`grep -n -i "allowed" aousd/core/1.1.0/core_spec.md | grep -i schema`).
