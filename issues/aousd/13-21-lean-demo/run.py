#!/usr/bin/env python3
"""Repro for issues/aousd/13-21 (found by the verif/lean formalization).

Run with a stock OpenUSD python from this directory, e.g.
  PYTHONPATH=<OpenUSD>/lib/python python3 run.py
"""
import os, struct, tempfile
from pathlib import Path

os.chdir(Path(__file__).resolve().parent)
from pxr import Sdf, Usd, Pcp

print("pxr", Usd.GetVersion())

# 13: path grammar
for s in ["/a{v=x}b/c",
          "/World/Foo/Baz{VariantSet1=VarFoobar}Foobar.foobarprop1",
          "/World/Bar{VariantSet2=VarBarFoo}{VariantSet3=VarBarBar}BarFoo",
          "a.b.c", "/a.b.c", "a.b", "..", "../..", "../../ParentSibilng/Cousin",
          "/Root/Child/Grandchild{size=1}/GreatGrandchild",
          "/Root/Child/Grandchild{size=1}GreatGrandchild"]:
    print("13 IsValidPathString(%r) = %s" % (s, Sdf.Path.IsValidPathString(s)))

# 14: element ordering (UsdPrim::GetPropertyNames sorts with TfDictionaryLessThan)
names = ["foobar", "Foobar", "_foobar", "foo_bar", "foo001bar001abc",
         "foo001bar002abc", "foo0001bar0002xyz", "foo00001bar", "a0", "aü", "ab"]
l = Sdf.Layer.CreateAnonymous(".usda")
p = Sdf.CreatePrimInLayer(l, "/P"); p.specifier = Sdf.SpecifierDef
for n in names:
    Sdf.AttributeSpec(p, n, Sdf.ValueTypeNames.Int)
st = Usd.Stage.Open(l)
print("14 pxr order of the L3535-3545 names:", list(st.GetPrimAtPath("/P").GetPropertyNames()))
l2 = Sdf.Layer.CreateAnonymous(".usda")
p2 = Sdf.CreatePrimInLayer(l2, "/P"); p2.specifier = Sdf.SpecifierDef
Sdf.CreatePrimInLayer(l2, "/P/_a").specifier = Sdf.SpecifierDef
Sdf.CreatePrimInLayer(l2, "/P/a0").specifier = Sdf.SpecifierDef
Sdf.CreatePrimInLayer(l2, "/P/a_").specifier = Sdf.SpecifierDef
st2 = Usd.Stage.Open(l2)
print("14 '_' vs digit, children a_ a0 _a:", [c.GetName() for c in st2.GetPrimAtPath("/P").GetChildren()])

# 15: namespace mapping injectivity
m = Pcp.MapFunction({"/B": "/A", "/": "/"})
print("15 MapFunction{(/B,/A),(/,/)}: /B ->", m.MapSourceToTarget("/B"),
      "| /A ->", repr(m.MapSourceToTarget("/A")), "| /C ->", m.MapSourceToTarget("/C"))

reloc = Pcp.MapFunction({"/A/B": "/A/C"}); ref = Pcp.MapFunction({"/Ref": "/A"})
print("15 relocates∘reference as written (L4962-4966):", reloc.Compose(ref).sourceToTargetMap)
reloc_id = Pcp.MapFunction({"/A/B": "/A/C", "/": "/"})
print("15 same with identity added to the relocates map  :", reloc_id.Compose(ref).sourceToTargetMap)

# 16: relocates chain A->B, C->A in one layer
st = Usd.Stage.Open("single.usda")
print("16 children of /P:", [c.GetName() for c in st.GetPrimAtPath("/P").GetAllChildren()])
for e in st.GetCompositionErrors():
    print("16 error:", str(e).splitlines()[0][:160])

# 17: ordered children pseudocode
l = Sdf.Layer.CreateAnonymous(".usda")
l.ImportFromString('#usda 1.0\ndef "P" (\n prepend references = @./refs.usda@</R>\n)\n'
                   '{\n reorder nameChildren = ["b", "a"]\n def "x" {}\n def "a" {}\n def "b" {}\n}\n')
st = Usd.Stage.Open(l)
print("17 children x a b, primOrder [b,a]:", [c.GetName() for c in st.GetPrimAtPath("/P").GetChildren()
                                               if c.GetName() in "xab"])
st = Usd.Stage.Open("nospec.usda")
print("17 rename X->Y onto existing Y, no /P/C spec in the relocating stack:",
      [c.GetName() for c in st.GetPrimAtPath("/P/C").GetAllChildren()])
for e in st.GetCompositionErrors():
    print("17 error:", str(e).splitlines()[0][:160])
l = Sdf.Layer.CreateAnonymous(".usda")
l.ImportFromString('#usda 1.0\ndef "P"\n{\n reorder properties = ["a", "a"]\n int a = 1\n int b = 2\n}\n')
st = Usd.Stage.Open(l)
print("17 propertyOrder [a,a] over {a,b}:", list(st.GetPrimAtPath("/P").GetPropertyNames()))

# 18: specifier resolution
for f in ["s1", "s2", "s3"]:
    st = Usd.Stage.Open(f + ".usda"); pr = st.GetPrimAtPath("/A")
    print("18", f, "GetSpecifier() =", pr.GetSpecifier(), "| stack:",
          [(s.layer.identifier.split("/")[-1], str(s.path), str(s.specifier).split(".")[-1])
           for s in pr.GetPrimStack()])

# 19: attribute value source priority
for f in ["w", "v", "x", "y", "z"]:
    st = Usd.Stage.Open(f + ".usda"); a = st.GetAttributeAtPath("/P.a")
    print("19", f, "Get(5) =", a.Get(5), "| Get() =", a.Get(), "| source:", a.GetResolveInfo(5).GetSource())

# 20: independently authored class-chain controls, not copied spec layers.
# A reference introduces a class chain in a different namespace. Prim-index
# sites may exist without authored specs; actual opinions must have specs.
def walk(n, d=0):
    print("20 index", "  " * d + str(n.arcType).split(".")[-1],
          n.path, "hasSpecs" if n.hasSpecs else "nospecs")
    for child in n.children:
        walk(child, d + 1)

for kind in ("specializes", "inherits"):
    library = Sdf.Layer.CreateAnonymous("class-chain.usda")
    leaf = Sdf.CreatePrimInLayer(library, "/Seed")
    leaf.specifier = Sdf.SpecifierClass
    middle = Sdf.CreatePrimInLayer(library, "/Trait")
    middle.specifier = Sdf.SpecifierClass
    model = Sdf.CreatePrimInLayer(library, "/LibraryModel")
    model.specifier = Sdf.SpecifierDef
    field = "specializesList" if kind == "specializes" else "inheritPathList"
    getattr(middle, field).prependedItems = [Sdf.Path("/Seed")]
    getattr(model, field).prependedItems = [Sdf.Path("/Trait")]
    root = Sdf.Layer.CreateAnonymous("class-consumer.usda")
    consumer = Sdf.CreatePrimInLayer(root, "/Instance")
    consumer.specifier = Sdf.SpecifierDef
    consumer.referenceList.prependedItems = [Sdf.Reference(library.identifier, "/LibraryModel")]
    stage = Usd.Stage.Open(root)
    prim = stage.GetPrimAtPath("/Instance")
    stack = prim.GetPrimStack()
    assert [(item.layer == root, str(item.path)) for item in stack] == [
        (True, "/Instance"), (False, "/LibraryModel"),
        (False, "/Trait"), (False, "/Seed")]
    assert not root.GetPrimAtPath("/Trait") and not root.GetPrimAtPath("/Seed")
    print("20", kind, "authored stack:", [str(item.path) for item in stack])
    walk(prim.GetPrimIndex().rootNode)

# 19: does the spec's reference python even parse?
spec = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../aousd/core/1.1.0/core_spec.md")).read().splitlines()
for name, lo, hi in [("value resolution get_value L6364-6442", 6364, 6442)]:
    src = "\n".join(spec[lo - 1:hi])
    try:
        compile(src, name, "exec"); print("19", name, ": parses")
    except SyntaxError as e:
        print("19", name, ": SyntaxError at spec line", lo - 1 + e.lineno, "-", e.msg)

# 21: crate binary layout
def lz4(src):
    out = bytearray(); i = 0
    while i < len(src):
        t = src[i]; i += 1; n = t >> 4
        if n == 15:
            while True:
                b = src[i]; i += 1; n += b
                if b != 255: break
        out += src[i:i + n]; i += n
        if i >= len(src): break
        off = src[i] | (src[i + 1] << 8); i += 2; mm = t & 15
        if mm == 15:
            while True:
                b = src[i]; i += 1; mm += b
                if b != 255: break
        for _ in range(mm + 4): out.append(out[-off])
    return bytes(out)
def ints(raw, n, signed):
    common = struct.unpack_from("<i", raw, 0)[0]; nc = (n * 2 + 7) // 8
    codes = raw[4:4 + nc]; q = 4 + nc; prev = 0; res = []
    for k in range(n):
        c = (codes[k // 4] >> (2 * (k % 4))) & 3
        if c == 0: dv = common
        elif c == 1: dv = struct.unpack_from("<b", raw, q)[0]; q += 1
        elif c == 2: dv = struct.unpack_from("<h", raw, q)[0]; q += 2
        else: dv = struct.unpack_from("<i", raw, q)[0]; q += 4
        prev = (prev + dv) & 0xffffffff
        res.append(prev - (1 << 32) if signed and prev >= 1 << 31 else prev)
    return res
scratch = tempfile.TemporaryDirectory()
tmp = scratch.name; usdc = os.path.join(tmp, "crate.usdc")
Sdf.Layer.FindOrOpen("crate_src.usda").Export(usdc)
d = open(usdc, "rb").read()
toc = struct.unpack_from("<q", d, 16)[0]; n = struct.unpack_from("<Q", d, toc)[0]
secs = {}
for i in range(n):
    o = toc + 8 + 32 * i
    secs[d[o:o + 16].rstrip(b"\0").decode()] = struct.unpack_from("<qq", d, o + 16)
print("21 sections:", sorted((v[0], k) for k, v in secs.items()))
print("21 version bytes:", list(d[8:11]), "| tocOffset:", toc,
      "| earliest section start:", min(s for s, _ in secs.values()), "| bytes 24..88 all zero:", d[24:88] == bytes(64))
s, _ = secs["PATHS"]; q = s
tot, enc = struct.unpack_from("<QQ", d, q); q += 16
arrs = {}
for nm, sg in (("pathIndexes", 0), ("elementTokenIndexes", 1), ("jumps", 1)):
    cs = struct.unpack_from("<Q", d, q)[0]; q += 8; blk = d[q:q + cs]; q += cs
    arrs[nm] = ints(lz4(blk[1:]), enc, sg)
print("21 PATHS leading u64s:", tot, enc, "| jumps:", arrs["jumps"])
s, _ = secs["TOKENS"]; nt, ub, cb = struct.unpack_from("<QQQ", d, s)
toks = lz4(d[s + 25:s + 24 + cb]).split(b"\0")
print("21 decoded tokens:", [toks[abs(t)].decode() for t in arrs["elementTokenIndexes"]])
got = []; Sdf.Layer.FindOrOpen(usdc).Traverse("/", lambda p: got.append(str(p)))
print("21 pxr reads it back:", sorted(got))
s, _ = secs["FIELDS"]; nf = struct.unpack_from("<Q", d, s)[0]; q = s + 8
cs = struct.unpack_from("<Q", d, q)[0]; q += 8; ti = ints(lz4(d[q + 1:q + cs]), nf, 0); q += cs
cs = struct.unpack_from("<Q", d, q)[0]; q += 8; raw = lz4(d[q + 1:q + cs])
for k in range(nf):
    r = struct.unpack_from("<Q", raw, 8 * k)[0]
    if toks[ti[k]] in (b"typeName", b"specifier", b"default"):
        print("21 ValueRep %-10s 0x%016x  top byte 0x%02x (bit63 array=%d bit62 inlined=%d bit61 compressed=%d)"
              " | LSB-of-flag-byte reading: bit56=%d bit57=%d bit58=%d" % (toks[ti[k]].decode(), r, r >> 56, r >> 63 & 1, r >> 62 & 1,
              r >> 61 & 1, r >> 56 & 1, r >> 57 & 1, r >> 58 & 1))

# 21: PATHS with an empty path in the path table (reference without prim path)
l = Sdf.Layer.CreateAnonymous(".usda")
l.ImportFromString('#usda 1.0\ndef "A" (\n    references = @a.usda@\n)\n{\n}\n')
l.Export(os.path.join(tmp, "r.usdc"))
d = open(os.path.join(tmp, "r.usdc"), "rb").read()
toc = struct.unpack_from("<q", d, 16)[0]; n = struct.unpack_from("<Q", d, toc)[0]
for i in range(n):
    o = toc + 8 + 32 * i
    if d[o:o + 16].rstrip(b"\0") == b"PATHS":
        s = struct.unpack_from("<q", d, o + 16)[0]
        print("21 references layer PATHS leading u64s:", *struct.unpack_from("<QQ", d, s))
