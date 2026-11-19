# UsdRenderComputeSpec ignores instantaneousShutter

Compile `tests/next/oracle/render_spec.cc` against OpenUSD 26.11 and run it
on `scene.usda`. The RenderSettings author `instantaneousShutter = 1` and
nothing else about motion blur. The resulting product reports
`disableMotionBlur == false`.

The `RenderSettingsBase.instantaneousShutter` doc says: "Deprecated - use
disableMotionBlur instead. Override the targeted camera's shutterClose to be
equal to shutterOpen, to produce a zero-width shutter interval." In
`pxr/usd/usdRender/spec.cpp`, `_ReadSettingsBase` has a block commented
"For backwards-compatibility: instantaneousShutter disables motion blur",
but that block reads `rsBase.GetDisableMotionBlurAttr()` instead of
`GetInstantaneousShutterAttr()`. This looks like a copy-paste error, and it
makes the compatibility path a no-op.

Expected: `disableMotionBlur == true`. Fix: read
`GetInstantaneousShutterAttr()` in that block.

LightUSD's `lightusd::ComputeRenderSpec` follows the doc. The conformance
runner `tests/next/test-domain-render-runtime.py` records this as a known
gap.
