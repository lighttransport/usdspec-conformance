"""aousd/05 review demo: `add` vs `append` give different composed orders
when the item is already present in a weaker opinion.
Run: python demo.py   (needs OpenUSD Python bindings)"""
import os
from pxr import Sdf, Usd
here = os.path.dirname(os.path.abspath(__file__))
print("OpenUSD:", Usd.GetVersion())
for name in ("strong_add.usda", "strong_append.usda"):
    stage = Usd.Stage.Open(os.path.join(here, name))
    targets = stage.GetRelationshipAtPath("/P.r").GetTargets()
    print("%-19s %s" % (name, [str(t) for t in targets]))
# Same thing at the SdfListOp level, no composition involved.
weak = ["/A", "/B"]
for op in ("addedItems", "appendedItems"):
    lo = Sdf.PathListOp()
    setattr(lo, op, ["/A"])
    print("%-19s %s" % (op, [str(p) for p in lo.ApplyOperations([Sdf.Path(p) for p in weak])]))
