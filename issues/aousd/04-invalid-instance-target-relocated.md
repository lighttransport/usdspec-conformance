# Composition: specify target-path mapping for class opinions that target the inheriting instance's relocated subtree

**Type:** clarification (target mapping and validation requirements)
**Spec:** USD Core Specification v1.1.0, Composition (inherits / relocates / target path translation)
**Corpus:** core-spec-supplemental `release/1.0.1.post0`, `composition/tests/assets/ErrorInvalidInstanceTargetPath_root`

### Scenario (from the corpus, trimmed; legacy syntax)

`ref.usd`:

```
#usda 1.0
(
    relocates = {
        </BrowRig/LBrow/Anim/Brow>: </BrowRig/Anim/LBrow>,
        </BrowRig/RBrow/Anim/Brow>: </BrowRig/Anim/RBrow>
    }
)
def "BrowRig"
{
    class "SymBrow"
    {
        def "BrowInnUDPosBrowInnUDNeg_sculpt"
        {
            double amount = 0.001
            add double amount.connect = [
                </BrowRig/Anim/RBrow.InnUD>,
                </BrowRig/Anim/LBrow.InnUD>,
            ]
        }
        def "Anim" { def "Brow" {} }
    }
    def "LBrow" ( inherits = </BrowRig/SymBrow> ) {}
    def "RBrow" ( inherits = </BrowRig/SymBrow> ) {}
    def "Anim" {}
}
```

`root.usd` references `ref.usd</BrowRig>` at `/FaceRig/BrowRig` and relocates `/FaceRig/BrowRig/Anim/{L,R}Brow` to `/FaceRig/Anim/Face/Eyes/{L,R}Brow`.

The class connection in `SymBrow` targets `/BrowRig/Anim/LBrow`. That path is where the **inheriting instance `LBrow`'s own** `Anim/Brow` was relocated to, so it isn't in the class namespace.

The corpus root layer describes this as a museum case for errors when class connections target instances of that class, explaining that this is not allowed because it breaks invertibility of path translation. That context should inform the intended result; the differing outputs alone do not establish that all are valid.

The excerpt preserves the corpus’s deprecated `add` syntax for identification. Core 1.1 gives `add` no normative semantics. The self-contained reproduction below uses supported list operations instead.

### Minimal reproduction (no supplemental corpus required)

Save the following three files together in an otherwise empty directory. Run
`python repro.py` with OpenUSD’s Python bindings installed. To inspect flattening,
run `usdcat --flatten root.usda` if the CLI is available.

`ref.usda`:

```usda
#usda 1.0
(
    relocates = {
        </Rig/L/Anim/Src>: </Rig/Anim/L>,
        </Rig/R/Anim/Src>: </Rig/Anim/R>
    }
)

def "Rig"
{
    class "Sym"
    {
        def "Sculpt"
        {
            double amount = 0
            prepend double amount.connect = [
                </Rig/Anim/R.value>,
                </Rig/Anim/L.value>,
            ]
        }

        def "Anim"
        {
            def "Src"
            {
                double value = 1
            }
        }
    }

    def "L" (
        inherits = </Rig/Sym>
    )
    {
    }

    def "R" (
        inherits = </Rig/Sym>
    )
    {
    }

    def "Anim"
    {
    }
}
```

`root.usda`:

```usda
#usda 1.0

def "Face" (
    references = @./ref.usda@</Rig>
)
{
}
```

`repro.py`:

```python
import os
from pxr import Pcp, Sdf, Usd

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "root.usda")
stage = Usd.Stage.Open(root)
# Retain the layer: the layer-stack identifier holds a weak reference.
layer = Sdf.Layer.FindOrOpen(root)
cache = Pcp.Cache(Pcp.LayerStackIdentifier(layer), usd=True)
print("OpenUSD:", Usd.GetVersion())
for side in ("L", "R"):
    path = Sdf.Path("/Face/%s/Sculpt.amount" % side)
    print(side, "Usd:", [str(p) for p in
                            stage.GetAttributeAtPath(path).GetConnections()])
    paths, _, errors = cache.ComputeAttributeConnectionPaths(path)
    print(side, "Pcp:", [str(p) for p in paths], "errors:", len(errors))
    for error in errors:
        print(" ", type(error).__name__, str(error))
```

With the official `usd-core==26.11` wheel, the result paths are:

```text
L Usd: ['/Face/Anim/R.value']
L Pcp: [] errors: 2
R Usd: ['/Face/Anim/L.value']
R Pcp: [] errors: 2
```

Warnings and the printed error details are additional output. For `L`, Pcp
reports `ErrorInvalidExternalTargetPath` for `/Rig/Anim/L.value` (outside the
inherit’s scope) and `ErrorInvalidInstanceTargetPath` for `/Rig/Anim/R.value`
(authored in a class but targeting an instance of that class). `R` is symmetric.
The reduced scene also produces these result paths with `usd-core==26.5`;
the release difference in the historical corpus table below concerns the
larger corpus scene, not this reduced scene.

Here `L` inherits `Sym`, while its `Anim/Src` content is relocated to
`/Rig/Anim/L`. The connection in `Sym/Sculpt` targets that relocated content
and the corresponding content of sibling `R`. The reference maps the scene
under `/Face`. Unlike the historical corpus scene, no second set of relocates
is needed to demonstrate the target-validation distinction.

### Composed `amount.connect` on `/FaceRig/BrowRig/LBrow/BrowInnUDPosBrowInnUDNeg_sculpt`

| Source | Result |
|---|---|
| Corpus baseline (`pcp.txt`) | `[/FaceRig/BrowRig/Anim/LBrow.InnUD]` (keeps the self target, pre-relocate; drops the other) |
| OpenUSD 26.05 `usdcat --flatten` | `[/FaceRig/Anim/Face/Eyes/RBrow.InnUD, /FaceRig/BrowRig/Anim/LBrow.InnUD]` |
| OpenUSD 26.11 `usdcat --flatten` / `UsdAttribute.GetConnections()` | `[/FaceRig/Anim/Face/Eyes/RBrow.InnUD]` (drops the self target, with warning "refers to a path outside the scope of the inherit") |
| OpenUSD 26.11 `PcpCache.ComputeAttributeConnectionPaths` | `[]` with 2 errors |

So four different answers, including two that disagree within the same OpenUSD release.

### Request

Please specify how a target path authored inside an inherited class is mapped when it points at content relocated out of the inheriting prim's own namespace. In particular:

- Is such a target invalid, and therefore dropped?
- Is it kept at the pre-relocate path?
- Or is it mapped through the relocate?

And what about a target into a *sibling* instance's relocated content (the `RBrow` target in `LBrow`)?

Please clarify how the general inherit/relocate namespace-mapping rules and the requirement that mappings be invertible apply here, and whether validation must reject these targets during value resolution. OpenUSD’s Usd and Pcp paths intentionally perform different amounts of target validation; their outputs are observations, not proof of a required API equivalence.

If any recovery behavior is implementation-defined, specify its boundaries explicitly. Merely encountering a composition error does not establish that every output above is conformant. The corpus baseline should be identified as historical evidence rather than assumed to be the normative answer.

## Reviewer checklist

- [ ] The trimmed `ref.usd` excerpt matches the corpus file
      `composition/tests/assets/ErrorInvalidInstanceTargetPath_root/usda/ref.usd`.
- [ ] Corpus baseline row: `grep -n -A3 "LBrow/BrowInnUDPosBrowInnUDNeg_sculpt.amount:" .../pcp.txt`
      under "Attribute connections".
- [ ] 26.11 Usd row: `usdcat --flatten root.usd | grep -A3 amount.connect`
      and `GetConnections()` on the LBrow attribute.
- [ ] 26.11 Pcp row: `Pcp.Cache(...).ComputeAttributeConnectionPaths(path)`.
      Expect `[]` and 2 errors.
- [ ] Recheck the 26.05 row with an official `usd-core==26.5` wheel; the
      independent review reproduced both targets via `GetConnections()` and flattening.
- [ ] Read the generic inherit/relocate namespace-mapping and invertibility
      rules; identify precisely which target-validation requirement needs clarification.
- [ ] Include the corpus header’s invalid-target explanation and use supported
      list operations in the normative repro.
- [ ] Run the three embedded reproduction files independently of this repository
      and the supplemental corpus. Confirm the result paths and both error types.
