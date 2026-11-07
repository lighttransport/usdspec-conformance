"""UsdCollectionAPI includeRoot: docs say "The fallback is false", but the
generated schema has no default, so Get() resolves to no value.
Run with OpenUSD's Python on PYTHONPATH."""
from pxr import Usd

stage = Usd.Stage.CreateInMemory()
prim = stage.DefinePrim('/P')
coll = Usd.CollectionAPI.Apply(prim, 'c')
attr = coll.GetIncludeRootAttr()
print('Usd.GetVersion():', Usd.GetVersion())
print('includeRoot defined by schema:', attr.IsDefined())
print('includeRoot HasAuthoredValue:', attr.HasAuthoredValue())
print('includeRoot HasFallbackValue:', attr.HasFallbackValue())
print('includeRoot Get():', attr.Get())
print('membership includes </>:', coll.ComputeMembershipQuery().IsPathIncluded('/'))
for name in ('includeRoot', 'expansionRule', 'mode'):
    a = prim.GetAttribute('collection:c:' + name)
    print('  %-13s fallback: %r' % (name, a.Get()))
