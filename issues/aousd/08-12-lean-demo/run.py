#!/usr/bin/env python3
"""Repro for issues/aousd/08-12 (found by the verif/lean formalization).

Run with a stock OpenUSD python, e.g.
  PYTHONPATH=<OpenUSD>/lib/python python3 run.py
from this directory.
"""
import os
from pathlib import Path
from pxr import Sdf, Usd

os.chdir(Path(__file__).resolve().parent)

print("pxr", Usd.GetVersion())

# 08: list-op congruence vs reduced-form equality
a = Sdf.IntListOp(); a.deletedItems = [1, 2]
b = Sdf.IntListOp(); b.deletedItems = [2, 1]
print("08 a == b:", a == b,
      "| same result on sampled inputs:",
      all(a.ApplyOperations(w) == b.ApplyOperations(w)
          for w in ([], [1], [2], [1, 2], [2, 1], [1, 2, 3], [3, 2, 1])))

# 09: dictionary combining is not associative
def custom_data(dicts):
    layers = []
    for d in dicts:
        l = Sdf.Layer.CreateAnonymous(".usda")
        p = Sdf.CreatePrimInLayer(l, "/P"); p.specifier = Sdf.SpecifierDef
        p.customData = d; layers.append(l)
    root = Sdf.Layer.CreateAnonymous(".usda")
    root.subLayerPaths = [l.identifier for l in layers]
    st = Usd.Stage.Open(root)
    out = st.GetPrimAtPath("/P").GetCustomData()
    del st
    return out, layers, root
a, b, c = {"x": {}}, {"x": 1}, {"x": {"y": 2}}
print("09 stack a>b>c       :", custom_data([a, b, c])[0])
print("09 (a∪b) over c      :", custom_data([custom_data([a, b])[0], c])[0])
print("09 a over (b∪c)      :", custom_data([a, custom_data([b, c])[0]])[0])

# 10: layer offset direction (sub.usda samples at 4, 12, 16; offset=10 scale=0.5)
st = Usd.Stage.Open("root.usda"); attr = st.GetAttributeAtPath("/P.v")
print("10 stage times of layer samples {4,12,16}:", attr.GetTimeSamples(),
      "| Get(12) =", attr.Get(12), "(layer value at 4) | Get(16) =", attr.Get(16), "(layer value at 12)")

# 11: TCPS chain R(24) -> A(48, offset 10) -> B(48, offset 5), B sample at 0
st = Usd.Stage.Open("R.usda")
print("11 B sample at 0 lands at stage time:", st.GetAttributeAtPath("/Q.v").GetTimeSamples())
