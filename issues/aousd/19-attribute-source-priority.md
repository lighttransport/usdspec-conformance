# Attribute value resolution: clarify cross-layer source priority and repair the reference Python

**Type:** erratum
**Spec:** USD Core Specification v1.1.0 (e8f44c0), Value Resolution → Attribute Resolution (L6322-6340, L6364-6442), Time Based (L6490-6503), Spline Evaluation (L6584-6590), Value Resolution of Clip Values (L7006-7012)
**Formal reference:** `verif/lean/UsdSpec/ValueResolution/Attribute.lean` — `perSpec`, `anchored`, `perFieldA`, `perFieldB`, `perSpec_eq_anchored`, `readings_disagree`, `pyGetValue`; registry `LEAN-702`, `LEAN-703`

**Reproduction environment:** official PyPI `usd-core==26.11`, CPython 3.11,
Linux x86-64. Both shared repro scripts were rerun with this wheel, isolated
from the local OpenUSD fork. Source references use the clean `v26.11.1` tag.
**Spec source:** [published v1.1.0](https://github.com/aousd/specifications-public/blob/83e25aceb11a9340db4778263bda5d5175875f49/core/1.1.0/core_spec.md).

### What the spec says

L6325-6336: "If time based evaluation is considered then the strongest opinion of the
following metadata fields are consulted (in the order given): `timeSamples`, `spline`,
`default`, `clips`. This happens on each spec contributing to composition."

L6492-6503: "When an attribute value is queried at a specific time, the query will take
into account 1. Time Samples … 2. Spline Evaluation … 3. Value clips … The query will
iterate all layers … Time Samples have higher priority over *Spline evaluation* or *Value
clips*." (no `default`)

L6588-6590: "`timeSamples` take precedence over splines, and splines take precedence over
`default` and value clips."

L7009-7010: "The clip data is just weaker than the `Local` … data of the anchoring layer."

### Observation (LEAN-702)

The per-spec sentence supports reading C. The broader field-priority wording
and the omission of defaults from the time-source list can also suggest the
following alternative readings when taken without that qualification:

- **A, per field across the stack** ("the strongest opinion of the following fields … in
  the order given", L6326-6332): the strongest `timeSamples` anywhere beats a stronger
  layer's `default`, and a weaker `default` beats a stronger layer's clips.
- **B, time sources only** (L6495-6503): `default` is not a time source at all.
- **C, per spec** ("This happens on each spec", L6334, plus clip anchoring L7009): walk
  specs strongest first; the first spec with any of `timeSamples`/`spline`/`default` (in
  that order) wins; clips anchored in a layer act as an opinion just below that layer's
  local opinions.

For the simplified model of eligible, unblocked opinions, C equals clip anchoring
(`perSpec_eq_anchored`). The probes below cover defaults, samples, and clips;
they do not establish all block, empty-sample, or spline-extrapolation behavior. The theorem `readings_disagree` covers the four distinguishing stacks
`w`, `x`, `y`, and `z`: only C matches their OpenUSD results. The fifth probe,
`v`, is a same-spec precedence control, not an additional case in that theorem.

### What OpenUSD does

Stock OpenUSD 26.11 (official `usd-core==26.11` wheel), `13-21-lean-demo/run.py`; `a.timeSamples =
{0: 1, 10: 2}` (1.5 at time 5), default `5`:

```
19 w Get(5) = 5.0 | ... source: Usd.ResolveInfoSourceDefault      # stronger default, weaker timeSamples (A, B say 1.5)
19 v Get(5) = 1.5 | ... source: Usd.ResolveInfoSourceTimeSamples  # same spec: timeSamples beat default (all agree)
19 x Get(5) = 5.0 | ... source: Usd.ResolveInfoSourceDefault      # stronger default, weaker clips (B says 1.5)
19 y Get(5) = 1.5 | ... source: Usd.ResolveInfoSourceValueClips   # stronger clips, weaker default (A says 5)
19 z Get(5) = 5.0 | ... source: Usd.ResolveInfoSourceDefault      # same layer: default beats clips (B says 1.5)
```

`pxr/usd/usd/stage.cpp` L9412-9470: per layer, `ProcessLayerAtTime` consults the spec's
own fields; "If we already found an opinion in the layer (default, spline, samples) then we
do not consult clips here. A single site only gets to supply one value opinion." (L9449-9451);
clips are consulted only at their `sourceLayer`.

### Observation (LEAN-703): the reference python

The python in L6364-6442 cannot be run as written:

- L6412-6413: the return annotation is split over two lines without parentheses
  (`SyntaxError`, reproduced by `run.py`: `19 value resolution get_value L6364-6442 :
  SyntaxError at spec line 6412 - expected ':'`).
- L6439: `(val : = self_process_default(spec))` — `: =` and a missing `.`; this
  "fallback" branch re-runs the default lookup instead of returning `self.fallbackVal`.
- L6430: `self._process_time_samples(spec)` omits the required `time` argument (L6404).
- It takes one `spec`, not the composed opinion stack, and ignores `spline`, `clips`
  and value blocks, contrary to L6326-6336.
- `_interpolate` (L6373-6374) indexes `timeSamples[0]` and fails on an empty
  authored `timeSamples` container (represented here as a list of pairs); it linearly interpolates any type when
  not `Held` (e.g. strings, tokens, bools).
- `_process_default` (L6485) tests the field with truthiness, while
  `_process_time_samples` (L6405) uses `is not None`. Whether this loses a
  zero/false default depends on the field wrapper's truth-value semantics;
  that failure is not established by the supplied probes.

### Request

1. State one rule: reading C (per spec, strongest first: `timeSamples`, `spline`, `default`;
   clips as an opinion just weaker than the anchoring layer's local opinions), and make
   L6492-6503 and L6588-6590 refer to it. Add the `w`/`y` stacks as examples.
2. Fix or replace the reference python: iterate the composed stack, pass `time`, handle
   `spline`/`clips`/blocks, return the fallback in the fallback branch, guard empty
   `timeSamples`, interpolate only interpolable types.

## Reviewer checklist

- [ ] Quoted text L6325-6336, L6492-6503, L6588-6590, L7009-7010, python L6364-6442.
- [ ] Run `13-21-lean-demo/run.py`; confirm the five `19` lines and the `SyntaxError` line.
- [ ] Hand-evaluate readings A, B, C on `w`, `x`, `y`, `z`.
- [ ] Read `stage.cpp` L9405-9470 at v26.11.1.
- [ ] Duplicates: `gh search issues --repo aousd/specifications-public "value resolution"`, `"get_value"`, `"value clips strength"`.
