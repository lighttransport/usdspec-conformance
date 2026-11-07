# Splines: define the Keep Ratio non-regressive limit precisely

**Type:** clarification
**Spec:** USD Core Specification v1.1.0, Value Resolution → Spline → Non-monotonic Curves → Anti-Regression at Evaluation Time

### What the spec says

> the implementation shall use the **Keep Ratio** strategy: shorten the tangents until the temporal regression is resolved, preserving the ratio of the two tangent lengths for each affected segment.

The strategy table already says to shorten proportionally “until the non-regressive limit is reached”. That identifies the mathematical boundary, but the spec does not state whether implementations may stop short of it for numerical robustness, or specify an allowable tolerance. This matters for comparing evaluated values.

### Exact limit

Assume a positive segment duration `dt` and nonnegative tangent widths after applying the spec’s backward-facing tangent rule (treat those widths as zero). Normalise the Bezier segment so its time span is 1, with tangent widths `a = w0/dt` and `b = w1/dt`. The time curve's derivative is proportional to `a(1-u)^2 + 2(1-a-b)u(1-u) + b u^2`. That is non-negative on [0,1], i.e. the curve is non-regressive, exactly when

    a + b <= 1   or   (1 - a - b)^2 <= a*b

If both widths are zero, use `s = 1`. Otherwise, scaling both widths by `s` keeps their ratio, and the largest non-regressive `s` is

    s = min(1, 1 / (a + b - sqrt(a*b)))

For equal regressive widths this gives `a = b = 1`, i.e. each tangent as wide as the interval.

### What OpenUSD does

OpenUSD 26.11 (`Ts`) stops slightly short of this limit. On

```
double v.spline = {
    bezier,
    0: 0; post curve (12, 10),
    10: 10; pre (12, 10),
}
```

it returns `29.97398957136784` at t=4, which corresponds to normalised widths of about 0.99999 rather than 1.0. An exact implementation returns `29.974239465872969`, a relative difference of about 1e-5.

This is deliberate numerical padding: `pxr/base/ts/regressionPreventer.cpp` at v26.11.1 defines `kWritePadding = 1e-5` and `kReadPadding = 1e-6`. `_AdjustWithKeepRatio` computes the boundary and subtracts `kWritePadding` from each normalized width. For unequal widths, subtracting the same absolute padding also changes their ratio slightly.

### Request

Either:

- supplement the existing boundary requirement with a precise numerical-padding policy (including any permitted departure from exact ratio preservation); or
- state that results within some tolerance are conformant, and that the exact shortening is implementation-defined.

Without one of these, conformance tests for regressive splines can't use exact values.

## Reviewer checklist

- [ ] The quoted sentence is in the "Anti-Regression at Evaluation Time"
      section of `aousd/core/1.1.0/core_spec.md`, and the strategy table already requires reaching the non-regressive
      limit; distinguish that requirement from a missing numerical tolerance (`grep -n -i "keep ratio" ...`).
- [ ] Re-derive the monotonicity condition yourself: B'(t)/3 is the
      quadratic a(1-u)^2 + 2(1-a-b)u(1-u) + b u^2, non-negative on [0,1]
      iff B >= 0 or B^2 <= AC. Then check that s = 1/(a+b-sqrt(ab))
      lands on the boundary (for a = b = 1.2 expect s = 0.8333).
- [ ] Reproduce the pxr number: write the spline from the draft as
      `def "S" { double v.spline = {...} }` and
      `Usd.Stage.Open(f).GetAttributeAtPath('/S.v').Get(4)`. Expect
      29.97398957136784.
- [ ] Independently compute the exact-limit value at t = 4 (widths 10, slope 10,
      bisection on the Bezier time curve). Expect about 29.97424, a relative
      gap of about 1e-5.
- [ ] Verify OpenUSD's padding in `pxr/base/ts/regressionPreventer.cpp`
      and see whether it uses an epsilon. If it does, quote it in the draft.
