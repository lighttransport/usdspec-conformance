/* cdiff_c.c - Differential harness shim for lspec_* kernels.
 * Reads lines from stdin, calls compiled kernels, prints results.
 * Format: see tools/cdiff.py. Includes generated sources directly.
 */
#include "internal/lusd_spec_crate.h"
#include "internal/lusd_spec_listop.h"
#include "internal/lusd_spec_samples.h"
#include "internal/lusd_spec_dict.h"
#include "internal/lusd_spec_offset.h"
#include "internal/lusd_spec_codecs.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* We include the .c files so the shim needs no build of the full library. */
#include "internal/lusd_spec_crate.c"
#include "internal/lusd_spec_listop.c"
#include "internal/lusd_spec_samples.c"
#include "internal/lusd_spec_dict.c"
#include "internal/lusd_spec_offset.c"
#include "internal/lusd_spec_codecs.c"

static char line[1 << 20];

int main(void) {
    while (fgets(line, sizeof(line), stdin)) {
        size_t n = strlen(line);
        while (n && (line[n - 1] == '\n' || line[n - 1] == '\r')) line[--n] = 0;
        if (strncmp(line, "crate_rt ", 9) == 0) {
            /* crate_rt <n> <x0> ... <x{n-1}> : encode+decode, print outputs */
            char* p = line + 9;
            uint32_t count = (uint32_t)strtoul(p, &p, 10);
            static int32_t xs[4096];
            static int32_t back[4096];
            static int32_t deltas[4096];
            static uint32_t codes[4096];
            static uint8_t enc[65536];
            uint32_t i;
            uint32_t elen = 0;
            LusdResult r;
            if (count > 4096) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < count; i++) {
                xs[i] = (int32_t)strtol(p, &p, 10);
            }
            if (count == 0) {
                puts("0");
                continue;
            }
            r = lspec_crate_encode32(xs, count, deltas, codes, enc, sizeof(enc), &elen);
            if (r != LUSD_SUCCESS) {
                printf("ENCERR %d\n", (int)r);
                continue;
            }
            r = lspec_crate_decode32(enc, elen, count, back);
            if (r != LUSD_SUCCESS) {
                printf("DECERR %d\n", (int)r);
                continue;
            }
            printf("%d", (int)elen);
            for (i = 0; i < count; i++) printf(" %d", (int)back[i]);
            puts("");
        } else if (strncmp(line, "listop_apply ", 13) == 0) {
            /* listop_apply <is_exp> <nexpl> <pre...> <napp> <app...> <wlen> <w...>
             * simplified: explicit apply is identity; comp: pre/app/weaker.
             * Format: listop_apply <is_exp> <nexpl> <e0...> <npre> <p0...> <napp> <a0...>
             *   <ndel> <d0...> <wlen> <w0...>
             */
            char* p = line + 13;
            int is_exp = (int)strtol(p, &p, 10);
            uint32_t nexpl = (uint32_t)strtoul(p, &p, 10);
            static int64_t expl[64], pre[64], app[64], del[64], weak[64], out[256];
            uint32_t npre, napp, ndel, wlen, i, olen = 0;
            LusdResult r;
            for (i = 0; i < nexpl; i++) expl[i] = strtoll(p, &p, 10);
            npre = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < npre; i++) pre[i] = strtoll(p, &p, 10);
            napp = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < napp; i++) app[i] = strtoll(p, &p, 10);
            ndel = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < ndel; i++) del[i] = strtoll(p, &p, 10);
            wlen = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < wlen; i++) weak[i] = strtoll(p, &p, 10);
            r = lspec_listop_i64_apply(is_exp, expl, nexpl, del, ndel, pre, npre,
                                       app, napp, weak, wlen, out, 256, &olen);
            if (r != LUSD_SUCCESS) {
                printf("%d 0\n", (int)r);
                continue;
            }
            printf("0 %d", (int)olen);
            for (i = 0; i < olen; i++) printf(" %lld", (long long)out[i]);
            puts("");
        } else if (strncmp(line, "ts_held ", 8) == 0) {
            /* ts_held <t> <n> <t0> <v0> <b0> ...  (double times/vals) */
            char* p = line + 8;
            double t = strtod(p, &p);
            uint32_t n = (uint32_t)strtoul(p, &p, 10);
            static double times[256], vals[256];
            static uint8_t blk[256];
            uint32_t i;
            double ov = 0;
            uint32_t kind = 0;
            LusdResult r;
            for (i = 0; i < n; i++) {
                times[i] = strtod(p, &p);
                vals[i] = strtod(p, &p);
                blk[i] = (uint8_t)strtoul(p, &p, 10);
            }
            r = lspec_ts_held_eval(times, vals, blk, n, t, &ov, &kind);
            if (r != LUSD_SUCCESS) {
                printf("ERR %d\n", (int)r);
                continue;
            }
            printf("%d %.17g\n", (int)kind, ov);
        } else if (strncmp(line, "quote_rt ", 9) == 0) {
            /* quote_rt <hex> : quote then scan, print back hex + len */
            char* hex = line + 9;
            size_t hl = strlen(hex);
            size_t len = hl / 2;
            static uint8_t in[4096], q[32768], back[4096];
            size_t i;
            uint32_t qlen = 0, blen = 0, cons = 0;
            LusdResult r;
            if (hl % 2) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < len; i++) {
                unsigned int v;
                sscanf(hex + 2 * i, "%2x", &v);
                in[i] = (uint8_t)v;
            }
            r = lspec_quote_string(in, (uint32_t)len, q, sizeof(q), &qlen);
            if (r != LUSD_SUCCESS) {
                printf("ERR %d\n", (int)r);
                continue;
            }
            /* q is quoted with surrounding quotes; scan body includes closing */
            r = lspec_scan_quoted(q + 1, qlen - 1, (uint32_t)len + 2,
                                  back, sizeof(back), &blen, &cons);
            if (r != LUSD_SUCCESS) {
                printf("SCANERR %d\n", (int)r);
                continue;
            }
            printf("%d", (int)blen);
            for (i = 0; i < blen; i++) printf(" %d", (int)back[i]);
            puts("");
        } else if (strncmp(line, "most_common ", 12) == 0) {
            char* p = line + 12;
            uint32_t count = (uint32_t)strtoul(p, &p, 10);
            static int32_t xs[4096];
            uint32_t i;
            int32_t r;
            if (count > 4096) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < count; i++) xs[i] = (int32_t)strtol(p, &p, 10);
            r = lspec_crate_most_common_i32(xs, count, 0);
            printf("%d\n", (int)r);
        } else if (strncmp(line, "contains ", 9) == 0) {
            char* p = line + 9;
            uint32_t count = (uint32_t)strtoul(p, &p, 10);
            int64_t v = strtoll(p, &p, 10);
            static int64_t xs[4096];
            uint32_t i;
            uint32_t r;
            if (count > 4096) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < count; i++) xs[i] = strtoll(p, &p, 10);
            r = lspec_contains_i64(xs, count, v);
            printf("%d\n", (int)r);
        } else if (strncmp(line, "crate_enc ", 10) == 0) {
            char* p = line + 10;
            uint32_t count = (uint32_t)strtoul(p, &p, 10);
            static int32_t xs[4096];
            static int32_t deltas[4096];
            static uint32_t codes[4096];
            static uint8_t enc[65536];
            uint32_t i;
            uint32_t elen = 0;
            LusdResult r;
            if (count > 4096) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < count; i++) xs[i] = (int32_t)strtol(p, &p, 10);
            if (count == 0) {
                puts("0 0");
                continue;
            }
            r = lspec_crate_encode32(xs, count, deltas, codes, enc, sizeof(enc), &elen);
            if (r != LUSD_SUCCESS) {
                printf("%d 0\n", (int)r);
                continue;
            }
            printf("0 %d", (int)elen);
            for (i = 0; i < elen; i++) printf(" %d", (int)enc[i]);
            puts("");
        } else if (strncmp(line, "crate_dec ", 10) == 0) {
            char* p = line + 10;
            char hex[131072];
            static uint8_t bs[65536];
            static int32_t out[4096];
            uint32_t i;
            uint32_t n;
            size_t hl;
            size_t len;
            LusdResult r;
            if (sscanf(p, "%131071s %u", hex, &n) != 2) {
                puts("BADLINE");
                continue;
            }
            hl = strlen(hex);
            len = hl / 2;
            if (len > 65536 || n > 4096) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < len; i++) {
                unsigned int v;
                sscanf(hex + 2 * i, "%2x", &v);
                bs[i] = (uint8_t)v;
            }
            r = lspec_crate_decode32(bs, (uint32_t)len, n, out);
            if (r != LUSD_SUCCESS) {
                printf("%d\n", (int)r);
                continue;
            }
            printf("0");
            for (i = 0; i < n; i++) printf(" %d", (int)out[i]);
            puts("");
        } else if (strncmp(line, "dict_merge ", 11) == 0) {
            char* p = line + 11;
            uint32_t sn = (uint32_t)strtoul(p, &p, 10);
            static uint32_t sk[256];
            static int64_t sv[256];
            static uint32_t wk[256];
            static int64_t wv[256];
            static uint32_t ok[512];
            static int64_t ov[512];
            uint32_t i;
            uint32_t wn;
            uint32_t on = 0;
            LusdResult r;
            if (sn > 256) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < sn; i++) sk[i] = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < sn; i++) sv[i] = strtoll(p, &p, 10);
            wn = (uint32_t)strtoul(p, &p, 10);
            if (wn > 256) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < wn; i++) wk[i] = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < wn; i++) wv[i] = strtoll(p, &p, 10);
            r = lspec_dict_merge_u32(sk, sv, sn, wk, wv, wn, ok, ov, 512, &on);
            if (r != LUSD_SUCCESS) {
                printf("%d 0\n", (int)r);
                continue;
            }
            printf("0 %d", (int)on);
            for (i = 0; i < on; i++) printf(" %u %lld", (unsigned)ok[i], (long long)ov[i]);
            puts("");
        } else if (strncmp(line, "ts_held_bits ", 13) == 0) {
            char* p = line + 13;
            uint64_t tbits = strtoull(p, &p, 10);
            uint32_t n = (uint32_t)strtoul(p, &p, 10);
            static double times[256];
            static double vals[256];
            static uint8_t blk[256];
            static uint8_t tb[2048];
            static uint8_t vb[2048];
            uint32_t i;
            double t;
            double ov = 0;
            uint32_t kind = 0;
            LusdResult r;
            uint64_t outbits = 0;
            if (n > 256) {
                puts("BADLINE");
                continue;
            }
            /* p points after n; parse triples tb vb blk */
            static uint64_t tmp[768];
            for (i = 0; i < n * 3; i++) tmp[i] = strtoull(p, &p, 10);
            memcpy(&t, &tbits, 8);
            for (i = 0; i < n; i++) {
                uint64_t a = tmp[i * 3], b = tmp[i * 3 + 1];
                memcpy(&times[i], &a, 8);
                memcpy(&vals[i], &b, 8);
                blk[i] = (uint8_t)tmp[i * 3 + 2];
            }
            (void)tb; (void)vb;
            r = lspec_ts_held_eval(times, vals, blk, n, t, &ov, &kind);
            if (r != LUSD_SUCCESS) {
                printf("%d 0\n", (int)r);
                continue;
            }
            memcpy(&outbits, &ov, 8);
            if (kind == 0 || kind == 1) outbits = 0;
            printf("%u %llu\n", (unsigned)kind, (unsigned long long)outbits);
        } else if (strncmp(line, "scan_quoted ", 12) == 0) {
            char hex[131072];
            static uint8_t bs[65536];
            static uint8_t out[4096];
            uint32_t fuel;
            size_t hl;
            size_t len;
            uint32_t i;
            uint32_t olen = 0;
            uint32_t cons = 0;
            LusdResult r;
            if (sscanf(line + 12, "%131071s %u", hex, &fuel) != 2) {
                puts("BADLINE");
                continue;
            }
            hl = strlen(hex);
            len = hl / 2;
            if (len > 65536) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < len; i++) {
                unsigned int v;
                sscanf(hex + 2 * i, "%2x", &v);
                bs[i] = (uint8_t)v;
            }
            r = lspec_scan_quoted(bs, (uint32_t)len, fuel, out, sizeof(out), &olen, &cons);
            if (r != LUSD_SUCCESS) {
                printf("%d\n", (int)r);
                continue;
            }
            printf("0 %d %d", (int)olen, (int)cons);
            for (i = 0; i < olen; i++) printf(" %d", (int)out[i]);
            puts("");
        } else if (strncmp(line, "listop_iterate ", 15) == 0) {
            char* p = line + 15;
            int is_exp = (int)strtol(p, &p, 10);
            uint32_t nexpl = (uint32_t)strtoul(p, &p, 10);
            static int64_t expl[64], pre[64], app[64], out[256];
            uint32_t npre, napp, i, olen = 0;
            LusdResult r;
            for (i = 0; i < nexpl; i++) expl[i] = strtoll(p, &p, 10);
            npre = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < npre; i++) pre[i] = strtoll(p, &p, 10);
            napp = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < napp; i++) app[i] = strtoll(p, &p, 10);
            r = lspec_listop_i64_iterate(is_exp, expl, nexpl, 0, 0, pre, npre, app, napp,
                                         out, 256, &olen);
            if (r != LUSD_SUCCESS) {
                printf("%d 0\n", (int)r);
                continue;
            }
            printf("0 %d", (int)olen);
            for (i = 0; i < olen; i++) printf(" %lld", (long long)out[i]);
            puts("");
        } else if (strncmp(line, "listop_reduce ", 14) == 0) {
            char* p = line + 14;
            int is_exp = (int)strtol(p, &p, 10);
            uint32_t nexpl = (uint32_t)strtoul(p, &p, 10);
            static int64_t expl[64], dele[64], pre[64], app[64];
            static int64_t oe[64], od[64], op2[64], oa[64];
            uint32_t ndel, npre, napp, i;
            uint32_t is_e = 0, ne = 0, nd = 0, np = 0, na = 0;
            LusdResult r;
            for (i = 0; i < nexpl; i++) expl[i] = strtoll(p, &p, 10);
            ndel = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < ndel; i++) dele[i] = strtoll(p, &p, 10);
            npre = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < npre; i++) pre[i] = strtoll(p, &p, 10);
            napp = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < napp; i++) app[i] = strtoll(p, &p, 10);
            r = lspec_listop_i64_reduce(is_exp, expl, nexpl, dele, ndel, pre, npre, app, napp,
                                        oe, 64, od, 64, op2, 64, oa, 64,
                                        &is_e, &ne, &nd, &np, &na);
            if (r != LUSD_SUCCESS) {
                printf("%d\n", (int)r);
                continue;
            }
            printf("0 %u %u %u %u %u", (unsigned)is_e, (unsigned)ne, (unsigned)nd,
                   (unsigned)np, (unsigned)na);
            for (i = 0; i < ne; i++) printf(" %lld", (long long)oe[i]);
            for (i = 0; i < nd; i++) printf(" %lld", (long long)od[i]);
            for (i = 0; i < np; i++) printf(" %lld", (long long)op2[i]);
            for (i = 0; i < na; i++) printf(" %lld", (long long)oa[i]);
            puts("");
        } else if (strncmp(line, "listop_combine ", 15) == 0) {
            char* p = line + 15;
            int s_is = (int)strtol(p, &p, 10);
            uint32_t s_nex = (uint32_t)strtoul(p, &p, 10);
            static int64_t se[64], sd[64], sp[64], sa[64];
            static int64_t we[64], wd[64], wp[64], wa[64];
            static int64_t oe[64], od[64], op2[64], oa[64];
            uint32_t i, s_nd, s_np, s_na, w_nex, w_nd, w_np, w_na;
            int w_is;
            uint32_t is_e = 0, ne = 0, nd = 0, np = 0, na = 0;
            LusdResult r;
            for (i = 0; i < s_nex; i++) se[i] = strtoll(p, &p, 10);
            s_nd = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < s_nd; i++) sd[i] = strtoll(p, &p, 10);
            s_np = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < s_np; i++) sp[i] = strtoll(p, &p, 10);
            s_na = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < s_na; i++) sa[i] = strtoll(p, &p, 10);
            w_is = (int)strtol(p, &p, 10);
            w_nex = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < w_nex; i++) we[i] = strtoll(p, &p, 10);
            w_nd = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < w_nd; i++) wd[i] = strtoll(p, &p, 10);
            w_np = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < w_np; i++) wp[i] = strtoll(p, &p, 10);
            w_na = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < w_na; i++) wa[i] = strtoll(p, &p, 10);
            r = lspec_listop_i64_combine(s_is, se, s_nex, sd, s_nd, sp, s_np, sa, s_na,
                                         w_is, we, w_nex, wd, w_nd, wp, w_np, wa, w_na,
                                         oe, 64, od, 64, op2, 64, oa, 64,
                                         &is_e, &ne, &nd, &np, &na);
            if (r != LUSD_SUCCESS) {
                printf("%d\n", (int)r);
                continue;
            }
            printf("0 %u %u %u %u %u", (unsigned)is_e, (unsigned)ne, (unsigned)nd,
                   (unsigned)np, (unsigned)na);
            for (i = 0; i < ne; i++) printf(" %lld", (long long)oe[i]);
            for (i = 0; i < nd; i++) printf(" %lld", (long long)od[i]);
            for (i = 0; i < np; i++) printf(" %lld", (long long)op2[i]);
            for (i = 0; i < na; i++) printf(" %lld", (long long)oa[i]);
            puts("");
        } else if (strncmp(line, "dict_lookup ", 12) == 0) {
            char* p = line + 12;
            uint32_t n = (uint32_t)strtoul(p, &p, 10);
            uint32_t k = (uint32_t)strtoul(p, &p, 10);
            static uint32_t keys[256];
            static int64_t vals[256];
            uint32_t i;
            int64_t outv = 0;
            uint32_t found = 0;
            LusdResult r;
            if (n > 256) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < n; i++) keys[i] = (uint32_t)strtoul(p, &p, 10);
            for (i = 0; i < n; i++) vals[i] = strtoll(p, &p, 10);
            r = lspec_dict_lookup_u32(keys, vals, n, k, &outv, &found);
            if (r != LUSD_SUCCESS) {
                printf("%d\n", (int)r);
                continue;
            }
            if (found) printf("0 1 %lld\n", (long long)outv);
            else puts("0 0");
        } else if (strncmp(line, "ts_linear ", 10) == 0) {
            char* p = line + 10;
            int64_t t = strtoll(p, &p, 10);
            uint32_t n = (uint32_t)strtoul(p, &p, 10);
            static int64_t times[256];
            static int64_t vals[256];
            static uint8_t blk[256];
            uint32_t i;
            int64_t ov = 0;
            uint32_t kind = 0;
            LusdResult r;
            if (n > 256) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < n; i++) {
                times[i] = strtoll(p, &p, 10);
                vals[i] = strtoll(p, &p, 10);
                blk[i] = (uint8_t)strtoul(p, &p, 10);
            }
            r = lspec_ts_linear_eval_i64(times, vals, blk, n, t, &ov, &kind);
            if (r != LUSD_SUCCESS) {
                printf("%d 0\n", (int)r);
                continue;
            }
            if (kind == 2) printf("%u %lld\n", (unsigned)kind, (long long)ov);
            else printf("%u %lld\n", (unsigned)kind, (long long)ov);
        } else if (strncmp(line, "quote_len ", 10) == 0) {
            char hex[131072];
            static uint8_t bs[65536];
            size_t hl;
            size_t len;
            uint32_t i;
            if (sscanf(line + 10, "%131071s", hex) != 1) {
                if (line[10] == '\0') {
                    puts("0");
                    continue;
                }
                puts("BADLINE");
                continue;
            }
            hl = strlen(hex);
            len = hl / 2;
            if (len > 65536) {
                puts("BADLINE");
                continue;
            }
            for (i = 0; i < len; i++) {
                unsigned int v;
                sscanf(hex + 2 * i, "%2x", &v);
                bs[i] = (uint8_t)v;
            }
            printf("%d\n", (int)lspec_quote_len(bs, (uint32_t)len));
        } else if (strncmp(line, "offset_valid ", 13) == 0) {
            uint64_t bits = strtoull(line + 13, 0, 10);
            double d;
            memcpy(&d, &bits, 8);
            printf("%d\n", (int)lspec_offset_valid(d));
        } else if (strncmp(line, "offset_sanitize ", 16) == 0) {
            uint64_t bits = strtoull(line + 16, 0, 10);
            double d;
            double o = 0;
            LusdResult r;
            uint64_t ob = 0;
            memcpy(&d, &bits, 8);
            r = lspec_offset_sanitize(d, &o);
            if (r != LUSD_SUCCESS) {
                printf("%d\n", (int)r);
                continue;
            }
            memcpy(&ob, &o, 8);
            printf("%llu\n", (unsigned long long)ob);
        } else {
            puts("BADLINE");
        }
    }
    return 0;
}
