# Spline Keep Ratio and value-error proof audit

The rational spline evaluator now uses the certified `Seg.keepRatio`
transformation. `UsdSpec/ValueResolution/SplineBounds.lean` connects its
bisection midpoint to the unique real time parameter. These are general proofs,
not tests on a fixed set of segment values or a fixed fuel.

For a positive-duration segment with nonnegative tangent widths, and any fuel
`n`, `keepRatioScale_safe` proves that the computed scale is positive and at
most one and that the scaled normalized widths satisfy `NonRegressive`.
`Seg.keepRatio_safe` transfers those facts to the actual segment fields used by
`curveSegValue`. Negative authored widths are already clamped to zero before
this transformation; Hermite widths are one third of the positive duration.

The lower square-root approximation has no assumed accuracy: `bisect_bounds`
proves interval containment and `sqrtLo_sq_le` proves its square is at most the
nonnegative input. `keepRatio_underapprox` then proves the shortening safe even
when the true square root is irrational. Fuel zero is included.

For corrected value control points `p0,p1,p2,p3`, define

```
A = 3*(p1-p0)
B = 3*(p0-2*p1+p2)
C = -p0+3*p1-3*p2+p3
K = abs(A) + 2*abs(B) + 3*abs(C)
```

`bezier_lipschitz` proves `abs(value(u)-value(v)) <= K*abs(u-v)` for arbitrary
real parameters in `[0,1]`. Bisection preserves the time bracket, its width is
`1/2^n`, and its midpoint is at most `1/2^(n+1)` from any parameter in that
bracket. Continuity gives a real root inside the bracket; no rational-root
assumption is made.

`timeReal_monotone` transfers the closed-form non-regression condition to the
real time polynomial. `bezier_strictMono_of_monotone` proves that a nonconstant
monotone cubic cannot have a flat interval: that would give infinitely many
roots of its difference from a constant polynomial. Positive duration makes the
time cubic nonconstant. Thus the time parameter exists and is unique, including
at the Keep Ratio boundary where the derivative may vanish at isolated points.

`keepRatio_root_unique` establishes existence and uniqueness for every target
time between the knot times. `keepRatio_value_error` proves that the actual
corrected-segment midpoint value differs from that unique root's value by at
most `K/2^(n+1)`. Its assumptions are positive duration, nonnegative input widths,
and a target time within the knot interval. They do not require a derivative
bounded away from zero. The evaluation fuel is 64, yielding the explicit bound
`K/2^65`; the proofs quantify over arbitrary fuel.

The time-linear/Hermite branch remains exact, as established by the existing
`bez_timeLinear` and `curveSegValue_hermite` theorems. Held and linear evaluation
do not use this bisection. The general bisection proof remains valid on endpoints.
The executable rational calculations are unchanged apart from factoring the
Keep Ratio transformation into a named definition.

This certifies the rational mathematical model and its real-root approximation.
It does not establish a floating-point rounding bound for native C++, complete
the review of all spline semantics, or prove the remaining Unicode and prim-index
requirements. No new AOUSD defect is claimed: the error bound is an analytical
property of this evaluator, not a tolerance mandated by the specification.
