#!/usr/bin/env python3
"""Differential harness: compiled lspec_* C vs Python ports of Lean specs.

Covers T1 crate roundtrip, T2 list-op apply, T3 held samples and quoted codec.
Full MiniC-interpreter CDiff.lean (C == MiniC == Lean) is the next step; this
harness catches wrapping/count/filter bugs with ASan/UBSan on the C side.

Usage: python3 tools/cdiff.py [--n N] [--seed S]
"""
import os
import random
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUSD_DIR = os.environ.get("LUSD_SPEC_DIR", os.path.expanduser("~/work/lightusd-c"))


def f64bits(f):
    return struct.unpack("<Q", struct.pack("<d", f))[0]


def bits_to_f(b):
    return struct.unpack("<d", struct.pack("<Q", b))[0]


def most_common(ds, zero=0):
    best = zero
    for d in ds:
        cd = sum(1 for x in ds if x == d)
        cb = sum(1 for x in ds if x == best)
        if cd > cb or (cd == cb and best < d):
            best = d
    return best


def to_deltas(xs):
    out = []
    prev = 0
    for x in xs:
        out.append(((x - prev) & 0xFFFFFFFF) if x >= 0 else (((x & 0xFFFFFFFF) - (prev & 0xFFFFFFFF)) & 0xFFFFFFFF))
        # normalize to signed
        prev = x
    # convert to signed int32
    res = []
    for d in out:
        if d >= 2**31:
            d -= 2**32
        res.append(d)
    return res


def crate_rt_expected(xs):
    # Only roundtrip value matters (encode len varies with tie-break choice
    # which decodes identically); check decode(encode) == xs.
    return xs


def contains(xs, v):
    return v in xs


def listop_apply(is_exp, expl, pre, app, dele, weaker):
    if is_exp:
        return list(expl)
    pre_f = [x for x in pre if x not in app]
    mid = [x for x in weaker if x not in app and x not in dele and x not in pre]
    return pre_f + mid + list(app)


def held_eval(times, vals, blk, t):
    if not times:
        return (0, None)
    if t <= times[0]:
        p = 0
    else:
        p = 0
        for i in range(len(times)):
            if times[i] <= t:
                p = i
    if blk[p]:
        return (1, None)
    return (2, vals[p])


def quote_len(b):
    n = 0
    for c in b:
        if c == 34:
            n += 2
        elif c == 92:
            n += 4
        elif c < 32:
            n += 4
        else:
            n += 1
    return n


def gen_cases(rng, n):
    lines = []
    expected = []
    for _ in range(n):
        cnt = rng.choice([0, 1, 2, 3, 4, 5, 7, 8, rng.randint(0, 20)])
        xs = []
        for _ in range(cnt):
            xs.append(rng.choice([rng.randint(-2**31, 2**31 - 1),
                                  rng.randint(-100000, 100000),
                                  rng.randint(-200, 200),
                                  0, 1, -1, 127, -128, 32767, -32768]))
        lines.append("crate_rt " + str(cnt) + (" " + " ".join(str(v) for v in xs) if cnt else ""))
        expected.append(("crate", xs))
    for _ in range(n):
        # list-op comp with small domain
        dom = list(range(10))
        rng.shuffle(dom)
        pre = dom[:rng.randint(0, 3)]
        app = dom[3:3 + rng.randint(0, 3)]
        dele = dom[6:6 + rng.randint(0, 2)]
        weak = dom[rng.randint(0, 4):rng.randint(0, 4) + rng.randint(0, 4)]
        weak = list(dict.fromkeys(weak))
        lines.append(f"listop_apply 0 0 {len(pre)} " + " ".join(map(str, pre)) +
                     f" {len(app)} " + " ".join(map(str, app)) +
                     f" {len(dele)} " + " ".join(map(str, dele)) +
                     f" {len(weak)} " + " ".join(map(str, weak)))
        expected.append(("listop", listop_apply(0, [], pre, app, dele, weak)))
    for _ in range(n):
        cnt = rng.choice([0, 1, 2, 3, 5])
        times = sorted(rng.sample(range(0, 100), cnt)) if cnt else []
        vals = [rng.randint(0, 100) * 1.0 for _ in range(cnt)]
        blk = [rng.choice([0, 0, 0, 1]) for _ in range(cnt)]
        t = rng.uniform(-10, 110) if cnt else 0.0
        lines.append(f"ts_held {t!r} {cnt} " + " ".join(
            f"{times[i]!r} {vals[i]!r} {blk[i]}" for i in range(cnt)))
        expected.append(("held", held_eval(times, vals, blk, t)))
    for _ in range(n):
        ln = rng.randint(0, 8)
        b = [rng.randint(0, 255) for _ in range(ln)]
        lines.append("quote_rt " + bytes(b).hex())
        expected.append(("quote", b))
    for _ in range(n):
        cnt = rng.choice([0, 1, 2, 5, rng.randint(0, 10)])
        xs = [rng.randint(-200, 200) for _ in range(cnt)]
        lines.append(f"most_common {cnt} " + " ".join(map(str, xs)))
        expected.append(("most_common", most_common(xs, 0) if xs else 0))
    for _ in range(n):
        cnt = rng.choice([0, 1, 3, 5])
        xs = rng.sample(range(-50, 50), cnt) if cnt else []
        v = rng.randint(-50, 50)
        lines.append(f"contains {cnt} {v} " + " ".join(map(str, xs)))
        expected.append(("contains", 1 if v in xs else 0))
    for _ in range(n):
        cnt = rng.choice([0, 1, 2, 3, 7, rng.randint(0, 8)])
        xs = [rng.choice([rng.randint(-100000, 100000), rng.randint(-200, 200), 0]) for _ in range(cnt)]
        lines.append(f"crate_enc {cnt} " + " ".join(map(str, xs)))
        expected.append(("crate_enc", None))
    for _ in range(n):
        # random hex (mostly invalid) for C==MiniC differential
        ln = rng.choice([1, 5, 13, rng.randint(1, 20)])
        b = [rng.randint(0, 255) for _ in range(ln)]
        cnt = rng.choice([0, 1, 2, 7])
        lines.append(f"crate_dec {bytes(b).hex()} {cnt}")
        expected.append(("crate_dec", None))
    for _ in range(n):
        sn = rng.choice([0, 1, 2, 3])
        sk = [rng.randint(0, 5) for _ in range(sn)]
        sv = [rng.randint(0, 100) for _ in range(sn)]
        wn = rng.choice([0, 1, 2])
        wk = [rng.randint(0, 5) for _ in range(wn)]
        wv = [rng.randint(0, 100) for _ in range(wn)]
        lines.append(f"dict_merge {sn} " + " ".join(map(str, sk)) + " " +
                     " ".join(map(str, sv)) + f" {wn} " +
                     " ".join(map(str, wk)) + " " + " ".join(map(str, wv)))
        # Python merge oracle (stronger wins)
        want = list(zip(sk, sv))
        for k, v in zip(wk, wv):
            if k not in sk:
                want.append((k, v))
        expected.append(("dict_merge", want))
    for _ in range(n):
        cnt = rng.choice([0, 1, 2, 3])
        times = sorted(rng.sample([0.0, 25.0, 50.0, 75.0, 100.0], cnt)) if cnt else []
        vals = [rng.choice([0.0, 10.0, 20.5, -3.25]) for _ in range(cnt)]
        blk = [rng.choice([0, 0, 1]) for _ in range(cnt)]
        t = rng.choice([-5.0, 0.0, 10.0, 60.0, 200.0])
        triples = []
        for i in range(cnt):
            triples.append(f"{f64bits(times[i])} {f64bits(vals[i])} {blk[i]}")
        lines.append(f"ts_held_bits {f64bits(t)} {cnt} " + " ".join(triples))
        k, v = held_eval(times, vals, blk, t)
        outb = 0 if k in (0, 1) else f64bits(v)
        expected.append(("ts_held_bits", (k, outb)))
    for _ in range(n):
        ln = rng.randint(0, 6)
        content = [rng.choice([65, 66, 34, 92, 1, 10]) for _ in range(ln)]
        # quote in Python (same rules as lspec_quote_string)
        q = [34]
        for c in content:
            if c == 34:
                q.extend([92, 34])
            elif c == 92:
                q.extend([92, 49, 51, 52])
            elif c < 32:
                q.extend([92, 48, 48 + (c // 8), 48 + (c % 8)])
            else:
                q.append(c)
        q.append(34)
        body = q[1:]  # after opening quote, includes closing
        fuel = len(content) + 2
        lines.append(f"scan_quoted {bytes(body).hex()} {fuel}")
        expected.append(("scan_quoted", (content, len(body))))
    for _ in range(n):
        is_exp = rng.choice([0, 0, 1])
        nexpl = rng.choice([0, 1, 2])
        expl = [rng.randint(0, 9) for _ in range(nexpl)]
        npre = rng.choice([0, 1, 2])
        pre = [rng.randint(0, 9) for _ in range(npre)]
        napp = rng.choice([0, 1, 2])
        app = [rng.randint(0, 9) for _ in range(napp)]
        lines.append(f"listop_iterate {is_exp} {nexpl} " + " ".join(map(str, expl)) +
                     f" {npre} " + " ".join(map(str, pre)) +
                     f" {napp} " + " ".join(map(str, app)))
        if is_exp:
            want = list(expl)
        else:
            want = [x for x in pre if x not in app] + list(app)
        expected.append(("listop_iterate", want))
    for _ in range(n):
        cnt = rng.choice([0, 1, 2, 3])
        keys = [rng.randint(0, 5) for _ in range(cnt)]
        vals = [rng.randint(0, 100) for _ in range(cnt)]
        k = rng.randint(0, 5)
        lines.append(f"dict_lookup {cnt} {k} " + " ".join(map(str, keys)) + " " +
                     " ".join(map(str, vals)))
        found = 1 if k in keys else 0
        outv = vals[keys.index(k)] if found else None
        expected.append(("dict_lookup", (found, outv)))
    for _ in range(n):
        cnt = rng.choice([0, 1, 2, 3])
        times = sorted(rng.sample([0, 50, 100, 150], cnt)) if cnt else []
        vals = [rng.randint(0, 50) for _ in range(cnt)]
        blk = [rng.choice([0, 0, 1]) for _ in range(cnt)]
        t = rng.choice([-10, 0, 60, 200])
        triples = []
        for i in range(cnt):
            triples.append(f"{times[i]} {vals[i]} {blk[i]}")
        lines.append(f"ts_linear {t} {cnt} " + " ".join(triples))
        # Python integer-linear oracle (mirrors lspec_ts_linear_eval_i64)
        def linear_i64(times, vals, blk, t):
            if not times:
                return (0, 0)
            if t <= times[0]:
                if blk[0]:
                    return (1, 0)
                return (2, vals[0])
            for i, tv in enumerate(times):
                if tv == t:
                    if blk[i]:
                        return (1, 0)
                    return (2, vals[i])
            for i in range(len(times)):
                if times[i] > t:
                    if i == 0:
                        if blk[0]:
                            return (1, 0)
                        return (2, vals[0])
                    p = i - 1
                    if blk[p]:
                        return (1, 0)
                    if blk[i]:
                        return (2, vals[p])
                    den = times[i] - times[p]
                    if den == 0:
                        return (2, vals[p])
                    num = (t - times[p]) * (vals[i] - vals[p])
                    # C integer division truncates toward zero; Python // floors.
                    # Use truncating division.
                    q = abs(num) // abs(den)
                    if (num < 0) != (den < 0):
                        q = -q
                    return (2, vals[p] + q)
            if blk[-1]:
                return (1, 0)
            return (2, vals[-1])
        expected.append(("ts_linear", linear_i64(times, vals, blk, t)))
    for _ in range(n):
        ln = rng.choice([1, 2, 3, 5])
        b = [rng.choice([65, 66, 34, 92, 1, 10, 0]) for _ in range(ln)]
        lines.append(f"quote_len {bytes(b).hex()}")
        elen = sum(2 if c == 34 else (4 if c == 92 or c < 32 else 1) for c in b)
        expected.append(("quote_len", elen))
    for _ in range(n):
        bits = rng.choice([f64bits(-1.0), f64bits(0.0), f64bits(1.5),
                           f64bits(float("inf")), f64bits(float("-inf")),
                           0x7FF8000000000000, rng.randint(0, 2**64 - 1)])
        lines.append(f"offset_valid {bits}")
        fv = bits_to_f(bits)
        expected.append(("offset_valid", 1 if fv > 0 else 0))
    for _ in range(n):
        bits = rng.choice([f64bits(-1.0), f64bits(0.0), f64bits(1.5),
                           f64bits(float("inf")), f64bits(float("-inf"))])
        lines.append(f"offset_sanitize {bits}")
        fv = bits_to_f(bits)
        out = fv if fv > 0 else 1.0
        expected.append(("offset_sanitize", f64bits(out)))
    for _ in range(n):
        is_exp = rng.choice([0, 0, 0, 1])
        nexpl = rng.choice([0, 1, 2])
        expl = [rng.randint(0, 9) for _ in range(nexpl)]
        ndel = rng.choice([0, 1, 2])
        dele = [rng.randint(0, 9) for _ in range(ndel)]
        npre = rng.choice([0, 1, 2])
        pre = [rng.randint(0, 9) for _ in range(npre)]
        napp = rng.choice([0, 1, 2])
        app = [rng.randint(0, 9) for _ in range(napp)]
        lines.append(f"listop_reduce {is_exp} {nexpl} " + " ".join(map(str, expl)) +
                     f" {ndel} " + " ".join(map(str, dele)) +
                     f" {npre} " + " ".join(map(str, pre)) +
                     f" {napp} " + " ".join(map(str, app)))
        if is_exp:
            want = (1, list(expl), [], [], [])
        else:
            wd = [x for x in dele if x not in app and x not in pre]
            wp = [x for x in pre if x not in app]
            want = (0, [], wd, wp, list(app))
        expected.append(("listop_reduce", want))
    for _ in range(n):
        def rnd_op():
            is_e = rng.choice([0, 0, 1])
            ne = rng.choice([0, 1, 2])
            ex = [rng.randint(0, 9) for _ in range(ne)]
            nd = rng.choice([0, 1, 2])
            de = [rng.randint(0, 9) for _ in range(nd)]
            np_ = rng.choice([0, 1, 2])
            pr = [rng.randint(0, 9) for _ in range(np_)]
            na = rng.choice([0, 1, 2])
            ap = [rng.randint(0, 9) for _ in range(na)]
            return is_e, ex, de, pr, ap
        s_is, s_ex, s_de, s_pr, s_ap = rnd_op()
        w_is, w_ex, w_de, w_pr, w_ap = rnd_op()
        lines.append(f"listop_combine {s_is} {len(s_ex)} " + " ".join(map(str, s_ex)) +
                     f" {len(s_de)} " + " ".join(map(str, s_de)) +
                     f" {len(s_pr)} " + " ".join(map(str, s_pr)) +
                     f" {len(s_ap)} " + " ".join(map(str, s_ap)) +
                     f" {w_is} {len(w_ex)} " + " ".join(map(str, w_ex)) +
                     f" {len(w_de)} " + " ".join(map(str, w_de)) +
                     f" {len(w_pr)} " + " ".join(map(str, w_pr)) +
                     f" {len(w_ap)} " + " ".join(map(str, w_ap)))
        def combine(s_is, s_ex, s_de, s_pr, s_ap, w_is, w_ex, w_de, w_pr, w_ap):
            if s_is:
                return (1, list(s_ex), [], [], [])
            if w_is:
                mid = [x for x in w_ex if x not in s_ap and x not in s_de and x not in s_pr]
                pre_f = [x for x in s_pr if x not in s_ap]
                return (1, pre_f + mid + list(s_ap), [], [], [])
            d1 = [x for x in w_de if x not in s_pr and x not in s_ap]
            d2 = [x for x in s_de if x not in s_pr and x not in s_ap and x not in w_de]
            p1 = [x for x in s_pr if x not in s_ap]
            p2 = [x for x in w_pr if x not in s_ap and x not in s_de and x not in s_pr]
            a1 = [x for x in w_ap if x not in s_ap and x not in s_de and x not in s_pr]
            a2 = list(s_ap)
            return (0, [], d1 + d2, p1 + p2, a1 + a2)
        expected.append(("listop_combine",
                         combine(s_is, s_ex, s_de, s_pr, s_ap, w_is, w_ex, w_de, w_pr, w_ap)))
    return lines, expected


def check(c_out, expected, minic_out=None):
    bad = 0
    minic_idx = 0
    # minic_out aligns with MiniC lines in order (see minic_lines filter below).
    for idx, (c, exp) in enumerate(zip(c_out, expected)):
        kind = exp[0]
        ok = False
        is_minic_kind = kind in ("most_common", "contains", "crate_enc", "crate_dec", "listop", "dict_merge", "ts_held_bits", "scan_quoted", "listop_iterate", "dict_lookup", "ts_linear", "quote_len", "offset_valid", "offset_sanitize", "listop_reduce", "listop_combine")
        m_str = None
        if minic_out is not None and is_minic_kind:
            m_str = minic_out[minic_idx].strip()
            minic_idx += 1
        try:
            toks = c.strip().split()
            if kind == "crate":
                xs = exp[1]
                if not xs:
                    ok = toks == ["0"]
                else:
                    # toks: [elen, x0, x1, ...]
                    ok = (len(toks) == 1 + len(xs) and
                          [int(x) for x in toks[1:]] == xs)
            elif kind == "listop":
                want = exp[1]
                if not want:
                    ok = toks == ["0", "0"]
                else:
                    ok = (len(toks) == 2 + len(want) and
                          toks[0] == "0" and toks[1] == str(len(want)) and
                          [int(x) for x in toks[2:]] == want)
            elif kind == "listop_iterate":
                want = exp[1]
                if not want:
                    ok = toks == ["0", "0"]
                else:
                    ok = (len(toks) == 2 + len(want) and
                          toks[0] == "0" and toks[1] == str(len(want)) and
                          [int(x) for x in toks[2:]] == want)
            elif kind == "dict_lookup":
                found, outv = exp[1]
                if found == 0:
                    ok = toks == ["0", "0"]
                else:
                    ok = (len(toks) == 3 and toks[0] == "0" and toks[1] == "1"
                          and int(toks[2]) == outv)
            elif kind == "ts_linear":
                kk, ov = exp[1]
                ok = (len(toks) == 2 and toks[0] == str(kk) and toks[1] == str(ov))
            elif kind == "quote_len":
                ok = (len(toks) == 1 and int(toks[0]) == exp[1])
            elif kind == "offset_valid":
                ok = (len(toks) == 1 and int(toks[0]) == exp[1])
            elif kind == "offset_sanitize":
                ok = (len(toks) == 1 and toks[0] == str(exp[1]))
            elif kind in ("listop_reduce", "listop_combine"):
                is_e, e_list, d_list, p_list, a_list = exp[1]
                total = len(e_list) + len(d_list) + len(p_list) + len(a_list)
                if len(toks) != 6 + total:
                    ok = False
                else:
                    ok = (toks[0] == "0" and toks[1] == str(is_e)
                          and toks[2] == str(len(e_list)) and toks[3] == str(len(d_list))
                          and toks[4] == str(len(p_list)) and toks[5] == str(len(a_list))
                          and [int(x) for x in toks[6:]] == list(e_list) + list(d_list) + list(p_list) + list(a_list))
            elif kind == "held":
                k, v = exp[1]
                if k == 0:
                    ok = toks[0] == "0"
                elif k == 1:
                    ok = toks[0] == "1"
                else:
                    ok = toks[0] == "2" and abs(float(toks[1]) - v) < 1e-9
            elif kind == "quote":
                want = exp[1]
                ok = (len(toks) == 1 + len(want) and
                      [int(x) for x in toks[1:]] == want)
            elif kind == "most_common":
                ok = (len(toks) == 1 and int(toks[0]) == exp[1])
            elif kind == "contains":
                ok = (len(toks) == 1 and int(toks[0]) == exp[1])
            elif kind in ("crate_enc", "crate_dec", "listop", "dict_merge", "ts_held_bits", "scan_quoted", "listop_iterate", "dict_lookup", "ts_linear", "quote_len", "offset_valid", "offset_sanitize", "listop_reduce", "listop_combine"):
                # 3-way for listop/dict/ts/scan (C==MiniC==Python), 2-way for crate bytes.
                if kind in ("crate_enc", "crate_dec"):
                    ok = (m_str is not None and c.strip().split() == m_str.split())
                    if not ok:
                        print(f"MINIC MISMATCH #{idx} kind={kind} C:{c} MiniC:{m_str}")
                elif kind == "ts_held_bits":
                    kk, ob = exp[1]
                    ok = (len(toks) == 2 and toks[0] == str(kk) and toks[1] == str(ob))
                elif kind == "scan_quoted":
                    content, body_len = exp[1]
                    # toks: 0 out_len consumed b0...
                    ok = (len(toks) == 3 + len(content) and toks[0] == "0"
                          and toks[1] == str(len(content)) and toks[2] == str(body_len)
                          and [int(x) for x in toks[3:]] == content)
                else:
                    # listop handled above (with code prefix); dict below
                    if kind == "dict_merge":
                        ok = True  # filled by 3-way block below
                    else:
                        # listop: oks already set; verify MiniC below
                        pass
            else:
                ok = False
        except Exception:
            ok = False
        # 3-way: MiniC must agree with C and Python.
        if minic_out is not None and kind in ("listop", "listop_iterate", "listop_reduce", "listop_combine"):
            try:
                if c.strip().split() != m_str.split():
                    ok = False
                    print(f"MINIC MISMATCH #{idx} kind={kind} C:{c} MiniC:{m_str}")
            except Exception:
                ok = False
        if minic_out is not None and kind == "dict_merge":
            try:
                if c.strip().split() != m_str.split():
                    ok = False
                    print(f"MINIC MISMATCH #{idx} kind={kind} C:{c} MiniC:{m_str}")
                else:
                    # Python oracle for dict_merge is exp[1] = [(k,v),...]
                    want = exp[1]
                    toks2 = c.strip().split()
                    if toks2[0] != "0" or int(toks2[1]) != len(want):
                        ok = False
                    else:
                        nums = list(map(int, toks2[2:]))
                        pairs = [(nums[i], nums[i+1]) for i in range(0, len(nums), 2)]
                        if pairs != want:
                            ok = False
            except Exception:
                ok = False
        if ok and minic_out is not None and kind in ("most_common", "contains"):
            try:
                if int(m_str) != int(toks[0]) or int(m_str) != exp[1]:
                    ok = False
            except Exception:
                ok = False
        if minic_out is not None and kind in ("ts_held_bits", "scan_quoted", "dict_lookup", "ts_linear", "quote_len", "offset_valid", "offset_sanitize"):
            try:
                if c.strip().split() != m_str.split():
                    ok = False
                    print(f"MINIC MISMATCH #{idx} kind={kind} C:{c} MiniC:{m_str}")
            except Exception:
                ok = False
        if not ok:
            bad += 1
            if bad <= 10:
                print(f"MISMATCH #{idx} kind={kind}\n  C: {c}\n  want: {exp}")
    return bad


def main():
    n = 200
    seed = 1
    args = sys.argv[1:]
    if "--n" in args:
        n = int(args[args.index("--n") + 1])
    if "--seed" in args:
        seed = int(args[args.index("--seed") + 1])
    if not os.path.isdir(os.path.join(LUSD_DIR, "src", "internal")):
        print(f"cdiff: lightusd-c spec dir missing ({LUSD_DIR}); skipping", file=sys.stderr)
        return 77
    rng = random.Random(seed)
    lines, expected = gen_cases(rng, n)
    # gen_cases emits 19*n lines
    inp = "\n".join(lines) + "\n"
    with tempfile.TemporaryDirectory() as d:
        exe = os.path.join(d, "cdiff_c")
        subprocess.check_call(
            [os.environ.get("CC", "cc"), "-std=c11", "-O1", "-w",
             "-fsanitize=address,undefined", "-fno-sanitize-recover=all",
             f"-I{LUSD_DIR}/include", f"-I{LUSD_DIR}/src",
             "-o", exe, os.path.join(ROOT, "tools", "cdiff_c.c")])
        out = subprocess.run([exe], input=inp.encode(), capture_output=True, check=True)
        c_out = out.stdout.decode().splitlines()
    lines2 = inp.strip().split("\n")
    if len(c_out) != len(lines2):
        print(f"output length mismatch: {len(c_out)} vs {len(lines2)}")
        return 1
    minic_out = None
    minic_lines = [ln for ln in lines if ln.startswith(("most_common ", "contains ", "crate_enc ", "crate_dec ", "listop_apply ", "dict_merge ", "ts_held_bits ", "scan_quoted ", "listop_iterate ", "dict_lookup ", "ts_linear ", "quote_len ", "offset_valid ", "offset_sanitize ", "listop_reduce ", "listop_combine "))]
    if minic_lines:
        lean_dir = os.path.join(ROOT, "verif", "lean")
        subprocess.check_call(["lake", "build", "usdspec-cdiff"], cwd=lean_dir,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        minic_exe = os.path.join(lean_dir, ".lake", "build", "bin", "usdspec-cdiff")
        mout = subprocess.run([minic_exe], input=("\n".join(minic_lines) + "\n").encode(),
                              capture_output=True, check=True)
        minic_out = mout.stdout.decode().splitlines()
        if len(minic_out) != len(minic_lines):
            print(f"MiniC output length mismatch: {len(minic_out)} vs {len(minic_lines)}")
            return 1
    bad = check(c_out, expected, minic_out)
    print(f"cdiff: {len(lines2)} cases, {bad} mismatches")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
