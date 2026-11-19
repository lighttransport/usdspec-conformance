# Points collision import can emit a negative sphere radius

With OpenUSD 26.11, run `python repro.py`. The indexed widths primvar takes
precedence over the plain widths attribute. A selector for widths 2 and 4
produces radii 1 and 2. Repeating that selector expands to four widths for
two points and produces an empty sphere list. Selecting widths -1 and 8
instead produces radii -0.5 and 4.

The Points collider importer checks the resolved width count and multiplies
each width by half the scale. It has no diameter range check. A negative
width should be diagnosed before a collision shape containing a negative
radius is passed to a simulation backend. LightUSD checks the finite,
non-negative range of the selected widths and diagnoses this case as
`physics.collider.points`.

The same reproducer checks the built-in `ColliderChecker`. It reports one
selector for two points as a cardinality error, even though `elementSize = 2`
expands that selector to two widths and the importer emits two spheres. It
accepts two selectors because it compares the raw selector count with the
point count, while the importer rejects the four expanded widths. The
validator should compare the resolved width count with the point count.

Source in OpenUSD v26.11.0 is
[`_ParseSpherePointsShapeDesc`](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.11.0/pxr/usd/usdPhysics/parseUtils.cpp).
