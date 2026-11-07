"""UsdAttribute.GetConnections keeps a class-authored target that a USD-mode
PcpCache reports as ErrorInvalidInstanceTargetPath. Run with OpenUSD's Python."""
import os
from pxr import Pcp, Sdf, Usd

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, 'root.usda')

stage = Usd.Stage.Open(root)
layer = Sdf.Layer.FindOrOpen(root)
cache = Pcp.Cache(Pcp.LayerStackIdentifier(layer), usd=True)
for side in ('L', 'R'):
    path = Sdf.Path('/Face/%s/Sculpt.amount' % side)
    usd = [str(p) for p in stage.GetAttributeAtPath(path).GetConnections()]
    pcp, _, errors = cache.ComputeAttributeConnectionPaths(path)
    print('%s  Usd GetConnections: %s' % (side, usd))
    print('%s  Pcp(usd=True) ComputeAttributeConnectionPaths: %s' %
          (side, [str(p) for p in pcp]))
    for e in errors:
        print('     %s' % type(e).__name__)
