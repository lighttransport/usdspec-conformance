# Docs question: should GetConnections/GetTargets say that Usd skips Pcp's class-to-instance target validation?

### Description of Issue

This is a documentation question, not a bug report.

A connection authored in a class targets something that each instance of the
class relocates. For `/Face/L/Sculpt.amount` in the attached files:

| API | Result |
|---|---|
| `Pcp.Cache(..., usd=True).ComputeAttributeConnectionPaths` | `[]`, errors `ErrorInvalidExternalTargetPath` and `ErrorInvalidInstanceTargetPath` |
| `UsdAttribute::GetConnections` (and so `UsdStage::Flatten`) | `[/Face/Anim/R.value]`, only the "outside the scope of the inherit" warning |

From the v26.11.1 source, this looks deliberate. `UsdProperty` composes
targets with `PcpComposeTargetPaths` (`pxr/usd/usd/property.cpp` L199), which
passes no validation cache. The class-targets-instance check in
`pxr/usd/pcp/targetIndex.cpp` (L368-386) runs only `if (cacheForValidation)`,
and `targetIndex.h` (L46-47) says that `PcpBuildTargetIndex` "will skip the
validation checks performed by PcpBuildFilteredTargetIndex".

The Usd API docs don't mention this, though. `UsdAttribute::GetConnections`
says it returns false when "composition errors were encountered", so a reader
could expect Usd to drop the same targets that a USD-mode `PcpCache` rejects.

### Question

Is it intended that `UsdAttribute::GetConnections` and
`UsdRelationship::GetTargets` keep targets that a USD-mode `PcpCache` reports
as `ErrorInvalidInstanceTargetPath`? If so, could the Usd docs (or the
instancing "targets and connections" page) say that Usd skips this check?

### Steps to Reproduce

Files in this directory (`ref.usda`, `root.usda`, `repro.py`):

```
python repro.py
```

Output (OpenUSD v26.11, see below), after the two "outside the scope of the
inherit" warnings:

```
L  Usd GetConnections: ['/Face/Anim/R.value']
L  Pcp(usd=True) ComputeAttributeConnectionPaths: []
     ErrorInvalidExternalTargetPath
     ErrorInvalidInstanceTargetPath
R  Usd GetConnections: ['/Face/Anim/L.value']
R  Pcp(usd=True) ComputeAttributeConnectionPaths: []
     ErrorInvalidInstanceTargetPath
     ErrorInvalidExternalTargetPath
```

### System Information (OS, Hardware)

Linux x86_64.

### Package Versions

OpenUSD 26.11. A stock `usd-core==26.11` wheel and `usd-core==26.5` give the
same Usd/Pcp split. The source references are to v26.11.1 and are unchanged
on `dev` as of 2d39590aa.

### Build Flags

Default.

## Reviewer checklist

- [ ] Re-run `repro.py` (now `usd=True`) on a stock wheel. The drafter ran it
      only on the fork install `dist-v26.11` (output above, verbatim; the order of
      R's two errors differs from L's). The earlier review ran the v1 repro
      (`usd=False`) on the stock wheels; the current repro uses USD mode.
- [ ] Line numbers: `property.cpp` L199, `targetIndex.cpp` L368-386,
      `targetIndex.h` L46-47 at v26.11.1.
- [ ] `attribute.h` GetConnections doc (around L668-680), with the "composition errors
      were encountered" wording. Check whether GetConnections returns false
      here (it reported a warning for the external target).
- [ ] Search again for "ErrorInvalidInstanceTargetPath" issues.
