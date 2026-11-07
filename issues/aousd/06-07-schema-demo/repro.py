"""Codeless demo schemas (plugin/resources) for AOUSD drafts 06 and 07.
Run via run.sh so PXR_PLUGINPATH_NAME points at the plugin."""
from pxr import Usd, Sdf
print("OpenUSD", Usd.GetVersion())
layer = Sdf.Layer.CreateAnonymous(".usda")
layer.ImportFromString('''#usda 1.0
def DemoPrim "typed" {}
def "autoApplied" (apiSchemas = ["DemoAutoAPI"]) {}
def "strongOnly" (apiSchemas = ["DemoStrongAPI"]) {}
def "both" (apiSchemas = ["DemoStrongAPI", "DemoWeakAPI"]) {}
''')
stage = Usd.Stage.Open(layer)
reg = Usd.SchemaRegistry.GetAutoApplyAPISchemas()
print("06: GetAutoApplyAPISchemas: DemoAutoAPI ->", list(reg["DemoAutoAPI"]),
      " DemoOnAPI ->", list(reg["DemoOnAPI"]))
for p in ("/typed", "/autoApplied", "/strongOnly"):
    prim = stage.GetPrimAtPath(p)
    print("06: %-12s type %-10r GetAppliedSchemas %s" % (
        p, str(prim.GetTypeName()), list(prim.GetAppliedSchemas())))
prim = stage.GetPrimAtPath("/both")
a = prim.GetAttribute("demo:mode")
print("07: /both GetAppliedSchemas", list(prim.GetAppliedSchemas()))
for f in ("default", "allowedTokens", "displayName", "displayGroup", "hidden",
          "documentation"):
    print("07:   demo:mode %-13s = %r" % (f, a.GetMetadata(f)))
