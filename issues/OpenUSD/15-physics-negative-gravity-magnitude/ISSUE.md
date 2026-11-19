# Negative gravityMagnitude is not treated as earth gravity

Run `python repro.py` with OpenUSD 26.11. The scene authors
`physics:gravityMagnitude = -1` in a centimeter stage. The parser reports
`gravityMagnitude == -1`.

The `PhysicsScene.gravityMagnitude` doc says: "A negative value is a request
to use a value equivalent to earth gravity regardless of the metersPerUnit
scaling used by this scene." The fallback is `-inf`. `parseUtils.cpp`
substitutes `9.81 / metersPerUnit` only when the magnitude is below
`-0.5e38` (the `-inf` sentinel). Any other negative value passes through
unchanged, so gravity points against the authored direction.

Expected: any negative magnitude resolves to `9.81 / metersPerUnit` (981 in
this stage). Either the parser should test `< 0`, or the doc should limit the
rule to the `-inf` fallback.

LightUSD's `lightusd::ResolvePhysics` follows the doc. The Lean model
(`UsdSpec/Domains/PhysicsResolve.lean`, `gravityMagnitude`) and the
conformance runner record this as a known OpenUSD gap.
