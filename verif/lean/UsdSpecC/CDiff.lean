/-
  Differential-testing driver (MiniC leg): runs translated lspec_* kernels
  on stdin cases, printing the MiniC result. tools/cdiff.py compares
  compiled C (tools/cdiff_c.c shim) vs this MiniC output vs Python Lean
  ports.

  Input lines:
    most_common <n> <v0> ...           (int32)
    contains <n> <v> <x0> ...          (int64)
    crate_enc <n> <x0> ...             (int32) -> code out_len b0...
    crate_dec <hex> <n>                -> code x0...
    listop_apply <is_exp> <nexpl> <e...> <npre> <p...> <napp> <a...>
                   <ndel> <d...> <wlen> <w...> -> code out_len v0...
    dict_merge <sn> <sk...> <sv...> <wn> <wk...> <wv...> -> code on k v...
    ts_held_bits <tBits> <n> <tb> <vb> <blk> ... -> kind outBits
    scan_quoted <hex> <fuel>             -> code out_len consumed b0...
    listop_iterate <is_exp> <nexpl> <e...> <npre> <p...> <napp> <a...>
    listop_reduce <is_exp> <nexpl> <e...> <ndel> <d...> <npre> <p...> <napp> <a...>
    listop_combine <s_is> <s_nexpl> <se...> <s_ndel> <sd...> <s_npre> <sp...> <s_napp> <sa...>
                   <w_is> <w_nexpl> <we...> <w_ndel> <wd...> <w_npre> <wp...> <w_napp> <wa...>
    dict_lookup <n> <k> <keys...> <vals...>
    ts_linear <t> <n> <t0> <v0> <b0> ...  (int64)
    quote_len <hex>
    offset_valid <bits>
    offset_sanitize <bits>
-/
import UsdSpecC.Gen
import UsdSpecC.Semantics

open UsdSpecC

def fuel : Nat := 100000

def toU8LE (n : Nat) (k : Nat) : List UInt8 := encodeLE k n

def bytesI32 (v : Int) : List UInt8 := toU8LE (IntTy.i32.wrap v) 4

def bytesI64 (v : Int) : List UInt8 := toU8LE (IntTy.i64.wrap v) 8

def bytesI32List (xs : List Int) : List UInt8 :=
  xs.flatMap bytesI32

def bytesI64List (xs : List Int) : List UInt8 :=
  xs.flatMap bytesI64

def parseHex (s : String) : List UInt8 :=
  let cs := s.toList
  let rec go : List Char → List UInt8
    | a :: b :: rest =>
      let h (c : Char) : Nat :=
        if c.isDigit then c.toNat - '0'.toNat
        else if 'a' ≤ c ∧ c ≤ 'f' then c.toNat - 'a'.toNat + 10
        else c.toNat - 'A'.toNat + 10
      (h a * 16 + h b).toUInt8 :: go rest
    | _ => []
  go cs

def showRes (r : Res (Option Val × Mem)) : String :=
  match r with
  | .ok (some (.int t n), _) =>
    let m := IntTy.toInt t n
    s!"{m}"
  | .ok _ => "ERR"
  | .ub => "UB"
  | .timeout => "TIMEOUT"

def showCrateEnc (r : Res (Option Val × Mem)) : String :=
  match r with
  | .ok (some (.int t code), m) =>
    if IntTy.toInt t code == 0 then
      match m 3, m 4 with
      | some outBlk, some lenBlk =>
        let outLen := decodeLE (lenBlk.take 4)
        let outBytes := (outBlk.take outLen).map (fun b => s!"{b.toNat}")
        s!"0 {outLen} " ++ " ".intercalate  outBytes
      | _, _ => "ERR"
    else s!"{IntTy.toInt t code} 0"
  | .ok _ => "ERR"
  | .ub => "UB"
  | .timeout => "TIMEOUT"

def showCrateDec (r : Res (Option Val × Mem)) (n : Nat) : String :=
  match r with
  | .ok (some (.int t code), m) =>
    if IntTy.toInt t code == 0 then
      match m 1 with
      | some blk =>
        let vals := (List.range n).map (fun i => IntTy.toInt IntTy.i32 (decodeLE ((blk.drop (4*i)).take 4)))
        let vs := vals.map (fun v => s!"{v}")
        s!"0 " ++ " ".intercalate  vs
      | none => "ERR"
    else s!"{IntTy.toInt t code}"
  | .ok _ => "ERR"
  | .ub => "UB"
  | .timeout => "TIMEOUT"

def runMost (rest : List String) : String :=
  match rest with
  | nStr :: vals =>
    let n := nStr.toNat?
    match n with
    | none => "BADLINE"
    | some nv =>
      if vals.length < nv then "BADLINE"
      else
        let xs := (vals.take nv).map (fun s => s.toInt?.getD 0)
        let mem : Mem := fun b => if b = 0 then some (bytesI32List xs) else none
        let args : List Val :=
          [.ptr 0 0, .int IntTy.u32 nv, .int IntTy.i32 (IntTy.i32.wrap 0)]
        let r := callFunc Gen.prog fuel Gen.fid_lspec_crate_most_common_i32 args mem
        showRes r
  | [] => "BADLINE"

def runContains (rest : List String) : String :=
  match rest with
  | nStr :: vStr :: vals =>
    let n := nStr.toNat?
    match n with
    | none => "BADLINE"
    | some nv =>
      if vals.length < nv then "BADLINE"
      else
        let v := vStr.toInt?.getD 0
        let xs := (vals.take nv).map (fun s => s.toInt?.getD 0)
        let mem : Mem := fun b => if b = 0 then some (bytesI64List xs) else none
        let args : List Val :=
          [.ptr 0 0, .int IntTy.u32 nv, .int IntTy.i64 (IntTy.i64.wrap v)]
        let r := callFunc Gen.prog fuel Gen.fid_lspec_contains_i64 args mem
        showRes r
  | _ => "BADLINE"

def runCrateEnc (rest : List String) : String :=
  match rest with
  | nStr :: vals =>
    let n := nStr.toNat?
    match n with
    | none => "BADLINE"
    | some nv =>
      if vals.length < nv then "BADLINE"
      else
        let xs := (vals.take nv).map (fun s => s.toInt?.getD 0)
        let mem : Mem := fun b =>
          if b = 0 then some (bytesI32List xs)
          else if b = 1 then some (List.replicate (4*nv) 0)
          else if b = 2 then some (List.replicate (4*nv) 0)
          else if b = 3 then some (List.replicate 65536 0)
          else if b = 4 then some (List.replicate 4 0)
          else none
        let args : List Val :=
          [.ptr 0 0, .int IntTy.u32 nv, .ptr 1 0, .ptr 2 0,
           .ptr 3 0, .int IntTy.u32 65536, .ptr 4 0]
        let r := callFunc Gen.prog fuel Gen.fid_lspec_crate_encode32 args mem
        showCrateEnc r
  | [] => "BADLINE"

def runCrateDec (rest : List String) : String :=
  match rest with
  | hex :: nStr :: _ =>
    let n := nStr.toNat?
    match n with
    | none => "BADLINE"
    | some nv =>
      let bs := parseHex hex
      let mem : Mem := fun b =>
        if b = 0 then some bs
        else if b = 1 then some (List.replicate (4*nv) 0)
        else none
      let args : List Val :=
        [.ptr 0 0, .int IntTy.u32 bs.length, .int IntTy.u32 nv, .ptr 1 0]
      let r := callFunc Gen.prog fuel Gen.fid_lspec_crate_decode32 args mem
      showCrateDec r nv
  | _ => "BADLINE"

def parseInts (ss : List String) : List Int :=
  ss.map (fun s => s.toInt?.getD 0)

def takeN (ss : List String) (n : Nat) : List String × List String :=
  (ss.take n, ss.drop n)

def runListop (rest : List String) : String :=
  -- Format matches tools/cdiff_c.c listop_apply.
  match rest with
  | isExpStr :: nexplStr :: rest1 =>
    let nexpl := nexplStr.toNat?.getD 0
    let (explS, rest2) := takeN rest1 nexpl
    match rest2 with
    | npreStr :: rest3 =>
      let npre := npreStr.toNat?.getD 0
      let (preS, rest4) := takeN rest3 npre
      match rest4 with
      | nappStr :: rest5 =>
        let napp := nappStr.toNat?.getD 0
        let (appS, rest6) := takeN rest5 napp
        match rest6 with
        | ndelStr :: rest7 =>
          let ndel := ndelStr.toNat?.getD 0
          let (delS, rest8) := takeN rest7 ndel
          match rest8 with
          | wlenStr :: rest9 =>
            let wlen := wlenStr.toNat?.getD 0
            let (weakS, _) := takeN rest9 wlen
            let isExp := isExpStr.toInt?.getD 0
            let expl := parseInts explS
            let pre := parseInts preS
            let app := parseInts appS
            let dele := parseInts delS
            let weak := parseInts weakS
            let mem : Mem := fun b =>
              if b = 0 then some (bytesI64List expl)
              else if b = 1 then some (bytesI64List pre)
              else if b = 2 then some (bytesI64List app)
              else if b = 3 then some (bytesI64List dele)
              else if b = 4 then some (bytesI64List weak)
              else if b = 5 then some (List.replicate (8*256) 0)
              else if b = 6 then some (List.replicate 4 0)
              else none
            let args : List Val :=
              [.int IntTy.i32 (IntTy.i32.wrap isExp),
               .ptr 0 0, .int IntTy.u32 nexpl,
               .ptr 3 0, .int IntTy.u32 ndel,
               .ptr 1 0, .int IntTy.u32 npre,
               .ptr 2 0, .int IntTy.u32 napp,
               .ptr 4 0, .int IntTy.u32 wlen,
               .ptr 5 0, .int IntTy.u32 256, .ptr 6 0]
            let r := callFunc Gen.prog fuel Gen.fid_lspec_listop_i64_apply args mem
            match r with
            | .ok (some (.int t code), m) =>
              if IntTy.toInt t code == 0 then
                match m 5, m 6 with
                | some outBlk, some lenBlk =>
                  let outLen := decodeLE (lenBlk.take 4)
                  let vals := (List.range outLen).map
                    (fun i => IntTy.toInt IntTy.i64 (decodeLE ((outBlk.drop (8*i)).take 8)))
                  s!"0 {outLen} " ++ " ".intercalate (vals.map (fun v => s!"{v}"))
                | _, _ => "ERR"
              else s!"{IntTy.toInt t code} 0"
            | .ok _ => "ERR"
            | .ub => "UB"
            | .timeout => "TIMEOUT"
          | _ => "BADLINE"
        | _ => "BADLINE"
      | _ => "BADLINE"
    | _ => "BADLINE"
  | _ => "BADLINE"

def showOpOut (r : Res (Option Val × Mem))
    (bExpl bDel bPre bApp bIs bNe bNd bNp bNa : Nat) : String :=
  match r with
  | .ok (some (.int t code), m) =>
    if IntTy.toInt t code == 0 then
      match m bExpl, m bDel, m bPre, m bApp, m bIs, m bNe, m bNd, m bNp, m bNa with
      | some eb, some db, some pb, some ab, some ib, some neb, some ndb, some npb, some nab =>
        let isE := decodeLE (ib.take 4)
        let ne := decodeLE (neb.take 4)
        let nd := decodeLE (ndb.take 4)
        let np := decodeLE (npb.take 4)
        let na := decodeLE (nab.take 4)
        let readVals (blk : List UInt8) (n : Nat) : List String :=
          (List.range n).map (fun i => s!"{IntTy.toInt IntTy.i64 (decodeLE ((blk.drop (8*i)).take 8))}")
        let vals := readVals eb ne ++ readVals db nd ++ readVals pb np ++ readVals ab na
        s!"0 {isE} {ne} {nd} {np} {na} " ++ " ".intercalate vals
      | _, _, _, _, _, _, _, _, _ => "ERR"
    else s!"{IntTy.toInt t code}"
  | .ok _ => "ERR"
  | .ub => "UB"
  | .timeout => "TIMEOUT"

def runListopReduce (rest : List String) : String :=
  match rest with
  | isExpStr :: nexplStr :: rest1 =>
    let nexpl := nexplStr.toNat?.getD 0
    let (explS, rest2) := takeN rest1 nexpl
    match rest2 with
    | ndelStr :: rest3 =>
      let ndel := ndelStr.toNat?.getD 0
      let (delS, rest4) := takeN rest3 ndel
      match rest4 with
      | npreStr :: rest5 =>
        let npre := npreStr.toNat?.getD 0
        let (preS, rest6) := takeN rest5 npre
        match rest6 with
        | nappStr :: rest7 =>
          let napp := nappStr.toNat?.getD 0
          let (appS, _) := takeN rest7 napp
          let isExp := isExpStr.toInt?.getD 0
          let expl := parseInts explS
          let dele := parseInts delS
          let pre := parseInts preS
          let app := parseInts appS
          let mem : Mem := fun b =>
            if b = 0 then some (bytesI64List expl)
            else if b = 1 then some (bytesI64List dele)
            else if b = 2 then some (bytesI64List pre)
            else if b = 3 then some (bytesI64List app)
            else if b = 4 then some (List.replicate (8*64) 0)
            else if b = 5 then some (List.replicate (8*64) 0)
            else if b = 6 then some (List.replicate (8*64) 0)
            else if b = 7 then some (List.replicate (8*64) 0)
            else if b = 8 then some (List.replicate 4 0)
            else if b = 9 then some (List.replicate 4 0)
            else if b = 10 then some (List.replicate 4 0)
            else if b = 11 then some (List.replicate 4 0)
            else if b = 12 then some (List.replicate 4 0)
            else none
          let args : List Val :=
            [.int IntTy.i32 (IntTy.i32.wrap isExp),
             .ptr 0 0, .int IntTy.u32 nexpl,
             .ptr 1 0, .int IntTy.u32 ndel,
             .ptr 2 0, .int IntTy.u32 npre,
             .ptr 3 0, .int IntTy.u32 napp,
             .ptr 4 0, .int IntTy.u32 64,
             .ptr 5 0, .int IntTy.u32 64,
             .ptr 6 0, .int IntTy.u32 64,
             .ptr 7 0, .int IntTy.u32 64,
             .ptr 8 0, .ptr 9 0, .ptr 10 0, .ptr 11 0, .ptr 12 0]
          let r := callFunc Gen.prog fuel Gen.fid_lspec_listop_i64_reduce args mem
          showOpOut r 4 5 6 7 8 9 10 11 12
        | _ => "BADLINE"
      | _ => "BADLINE"
    | _ => "BADLINE"
  | _ => "BADLINE"

def runListopCombine (rest : List String) : String :=
  -- rest: s_is s_nexpl se... s_ndel sd... s_npre sp... s_napp sa...
  --       w_is w_nexpl we... w_ndel wd... w_npre wp... w_napp wa...
  match rest with
  | sIsStr :: sNexStr :: r1 =>
    let sNex := sNexStr.toNat?.getD 0
    let (sExS, r2) := takeN r1 sNex
    match r2 with
    | sNdStr :: r3 =>
      let sNd := sNdStr.toNat?.getD 0
      let (sDeS, r4) := takeN r3 sNd
      match r4 with
      | sNpStr :: r5 =>
        let sNp := sNpStr.toNat?.getD 0
        let (sPrS, r6) := takeN r5 sNp
        match r6 with
        | sNaStr :: r7 =>
          let sNa := sNaStr.toNat?.getD 0
          let (sApS, r8) := takeN r7 sNa
          match r8 with
          | wIsStr :: wNexStr :: r9 =>
            let wNex := wNexStr.toNat?.getD 0
            let (wExS, r10) := takeN r9 wNex
            match r10 with
            | wNdStr :: r11 =>
              let wNd := wNdStr.toNat?.getD 0
              let (wDeS, r12) := takeN r11 wNd
              match r12 with
              | wNpStr :: r13 =>
                let wNp := wNpStr.toNat?.getD 0
                let (wPrS, r14) := takeN r13 wNp
                match r14 with
                | wNaStr :: r15 =>
                  let wNa := wNaStr.toNat?.getD 0
                  let (wApS, _) := takeN r15 wNa
                  let sIs := sIsStr.toInt?.getD 0
                  let wIs := wIsStr.toInt?.getD 0
                  let sEx := parseInts sExS
                  let sDe := parseInts sDeS
                  let sPr := parseInts sPrS
                  let sAp := parseInts sApS
                  let wEx := parseInts wExS
                  let wDe := parseInts wDeS
                  let wPr := parseInts wPrS
                  let wAp := parseInts wApS
                  let mem : Mem := fun b =>
                    if b = 0 then some (bytesI64List sEx)
                    else if b = 1 then some (bytesI64List sDe)
                    else if b = 2 then some (bytesI64List sPr)
                    else if b = 3 then some (bytesI64List sAp)
                    else if b = 4 then some (bytesI64List wEx)
                    else if b = 5 then some (bytesI64List wDe)
                    else if b = 6 then some (bytesI64List wPr)
                    else if b = 7 then some (bytesI64List wAp)
                    else if b = 8 then some (List.replicate (8*64) 0)
                    else if b = 9 then some (List.replicate (8*64) 0)
                    else if b = 10 then some (List.replicate (8*64) 0)
                    else if b = 11 then some (List.replicate (8*64) 0)
                    else if b = 12 then some (List.replicate 4 0)
                    else if b = 13 then some (List.replicate 4 0)
                    else if b = 14 then some (List.replicate 4 0)
                    else if b = 15 then some (List.replicate 4 0)
                    else if b = 16 then some (List.replicate 4 0)
                    else none
                  let args : List Val :=
                    [.int IntTy.i32 (IntTy.i32.wrap sIs),
                     .ptr 0 0, .int IntTy.u32 sNex,
                     .ptr 1 0, .int IntTy.u32 sNd,
                     .ptr 2 0, .int IntTy.u32 sNp,
                     .ptr 3 0, .int IntTy.u32 sNa,
                     .int IntTy.i32 (IntTy.i32.wrap wIs),
                     .ptr 4 0, .int IntTy.u32 wNex,
                     .ptr 5 0, .int IntTy.u32 wNd,
                     .ptr 6 0, .int IntTy.u32 wNp,
                     .ptr 7 0, .int IntTy.u32 wNa,
                     .ptr 8 0, .int IntTy.u32 64,
                     .ptr 9 0, .int IntTy.u32 64,
                     .ptr 10 0, .int IntTy.u32 64,
                     .ptr 11 0, .int IntTy.u32 64,
                     .ptr 12 0, .ptr 13 0, .ptr 14 0, .ptr 15 0, .ptr 16 0]
                  let r := callFunc Gen.prog fuel Gen.fid_lspec_listop_i64_combine args mem
                  showOpOut r 8 9 10 11 12 13 14 15 16
                | _ => "BADLINE"
              | _ => "BADLINE"
            | _ => "BADLINE"
          | _ => "BADLINE"
        | _ => "BADLINE"
      | _ => "BADLINE"
    | _ => "BADLINE"
  | _ => "BADLINE"

def runDictMerge (rest : List String) : String :=
  match rest with
  | snStr :: rest1 =>
    let sn := snStr.toNat?.getD 0
    let (skS, rest2) := takeN rest1 sn
    let (svS, rest3) := takeN rest2 sn
    match rest3 with
    | wnStr :: rest4 =>
      let wn := wnStr.toNat?.getD 0
      let (wkS, rest5) := takeN rest4 wn
      let (wvS, _) := takeN rest5 wn
      let sk := parseInts skS
      let sv := parseInts svS
      let wk := parseInts wkS
      let wv := parseInts wvS
      let bytesU32List (xs : List Int) : List UInt8 :=
        xs.flatMap (fun v => toU8LE (IntTy.u32.wrap v) 4)
      let mem : Mem := fun b =>
        if b = 0 then some (bytesU32List sk)
        else if b = 1 then some (bytesI64List sv)
        else if b = 2 then some (bytesU32List wk)
        else if b = 3 then some (bytesI64List wv)
        else if b = 4 then some (List.replicate (4*256) 0)
        else if b = 5 then some (List.replicate (8*256) 0)
        else if b = 6 then some (List.replicate 4 0)
        else none
      let args : List Val :=
        [.ptr 0 0, .ptr 1 0, .int IntTy.u32 sn,
         .ptr 2 0, .ptr 3 0, .int IntTy.u32 wn,
         .ptr 4 0, .ptr 5 0, .int IntTy.u32 256, .ptr 6 0]
      let r := callFunc Gen.prog fuel Gen.fid_lspec_dict_merge_u32 args mem
      match r with
      | .ok (some (.int t code), m) =>
        if IntTy.toInt t code == 0 then
          match m 4, m 5, m 6 with
          | some kBlk, some vBlk, some nBlk =>
            let outN := decodeLE (nBlk.take 4)
            let ks := (List.range outN).map
              (fun i => decodeLE ((kBlk.drop (4*i)).take 4))
            let vs := (List.range outN).map
              (fun i => IntTy.toInt IntTy.i64 (decodeLE ((vBlk.drop (8*i)).take 8)))
            let pairs := (ks.zip vs).map (fun kv => s!"{kv.1} {kv.2}")
            s!"0 {outN} " ++ " ".intercalate pairs
          | _, _, _ => "ERR"
        else s!"{IntTy.toInt t code} 0"
      | .ok _ => "ERR"
      | .ub => "UB"
      | .timeout => "TIMEOUT"
    | _ => "BADLINE"
  | _ => "BADLINE"

def runTsHeldBits (rest : List String) : String :=
  match rest with
  | tBitsStr :: nStr :: rest1 =>
    let tBits := tBitsStr.toNat?.getD 0
    let n := nStr.toNat?.getD 0
    if rest1.length < 3*n then "BADLINE"
    else
      let timesBits := (List.range n).map (fun i => (rest1.getD (3*i) "0").toNat?.getD 0)
      let valsBits := (List.range n).map (fun i => (rest1.getD (3*i+1) "0").toNat?.getD 0)
      let blk := (List.range n).map (fun i => (rest1.getD (3*i+2) "0").toNat?.getD 0)
      let bytesF64List (xs : List Nat) : List UInt8 :=
        xs.flatMap (fun v => toU8LE v 8)
      let bytesU8List (xs : List Nat) : List UInt8 :=
        xs.map (fun v => (v % 256).toUInt8)
      let mem : Mem := fun b =>
        if b = 0 then some (bytesF64List timesBits)
        else if b = 1 then some (bytesF64List valsBits)
        else if b = 2 then some (bytesU8List blk)
        else if b = 3 then some (List.replicate 8 0)
        else if b = 4 then some (List.replicate 4 0)
        else none
      let args : List Val :=
        [.ptr 0 0, .ptr 1 0, .ptr 2 0, .int IntTy.u32 n,
         .f64 tBits, .ptr 3 0, .ptr 4 0]
      let r := callFunc Gen.prog fuel Gen.fid_lspec_ts_held_eval args mem
      match r with
      | .ok (some (.int _ code), m) =>
        match m 3, m 4 with
        | some outBlk, some kindBlk =>
          let kind := decodeLE (kindBlk.take 4)
          let outBits := decodeLE (outBlk.take 8)
          s!"{kind} {outBits}"
        | _, _ => "ERR"
      | .ok _ => "ERR"
      | .ub => "UB"
      | .timeout => "TIMEOUT"
  | _ => "BADLINE"

def runScanQuoted (rest : List String) : String :=
  match rest with
  | hex :: fuelStr :: _ =>
    let fuelN := fuelStr.toNat?.getD 0
    let bs := parseHex hex
    let mem : Mem := fun b =>
      if b = 0 then some bs
      else if b = 1 then some (List.replicate 4096 0)
      else if b = 2 then some (List.replicate 4 0)
      else if b = 3 then some (List.replicate 4 0)
      else none
    let args : List Val :=
      [.ptr 0 0, .int IntTy.u32 bs.length, .int IntTy.u32 fuelN,
       .ptr 1 0, .int IntTy.u32 4096, .ptr 2 0, .ptr 3 0]
    let r := callFunc Gen.prog fuel Gen.fid_lspec_scan_quoted args mem
    match r with
    | .ok (some (.int t code), m) =>
      if IntTy.toInt t code == 0 then
        match m 1, m 2, m 3 with
        | some outBlk, some lenBlk, some consBlk =>
          let outLen := decodeLE (lenBlk.take 4)
          let consumed := decodeLE (consBlk.take 4)
          let outBytes := (outBlk.take outLen).map (fun b => s!"{b.toNat}")
          s!"0 {outLen} {consumed} " ++ " ".intercalate outBytes
        | _, _, _ => "ERR"
      else s!"{IntTy.toInt t code}"
    | .ok _ => "ERR"
    | .ub => "UB"
    | .timeout => "TIMEOUT"
  | _ => "BADLINE"

def runListopIterate (rest : List String) : String :=
  match rest with
  | isExpStr :: nexplStr :: rest1 =>
    let nexpl := nexplStr.toNat?.getD 0
    let (explS, rest2) := takeN rest1 nexpl
    match rest2 with
    | npreStr :: rest3 =>
      let npre := npreStr.toNat?.getD 0
      let (preS, rest4) := takeN rest3 npre
      match rest4 with
      | nappStr :: rest5 =>
        let napp := nappStr.toNat?.getD 0
        let (appS, _) := takeN rest5 napp
        let isExp := isExpStr.toInt?.getD 0
        let expl := parseInts explS
        let pre := parseInts preS
        let app := parseInts appS
        let mem : Mem := fun b =>
          if b = 0 then some (bytesI64List expl)
          else if b = 1 then some (bytesI64List pre)
          else if b = 2 then some (bytesI64List app)
          else if b = 3 then some (List.replicate (8*256) 0)
          else if b = 4 then some (List.replicate 4 0)
          else none
        -- iterate(is_exp, expl, nexpl, del=dummy empty, 0, pre, npre, app, napp, out, cap, out_len)
        let args : List Val :=
          [.int IntTy.i32 (IntTy.i32.wrap isExp),
           .ptr 0 0, .int IntTy.u32 nexpl,
           .ptr 0 0, .int IntTy.u32 0,
           .ptr 1 0, .int IntTy.u32 npre,
           .ptr 2 0, .int IntTy.u32 napp,
           .ptr 3 0, .int IntTy.u32 256, .ptr 4 0]
        let r := callFunc Gen.prog fuel Gen.fid_lspec_listop_i64_iterate args mem
        match r with
        | .ok (some (.int t code), m) =>
          if IntTy.toInt t code == 0 then
            match m 3, m 4 with
            | some outBlk, some lenBlk =>
              let outLen := decodeLE (lenBlk.take 4)
              let vals := (List.range outLen).map
                (fun i => IntTy.toInt IntTy.i64 (decodeLE ((outBlk.drop (8*i)).take 8)))
              s!"0 {outLen} " ++ " ".intercalate (vals.map (fun v => s!"{v}"))
            | _, _ => "ERR"
          else s!"{IntTy.toInt t code} 0"
        | .ok _ => "ERR"
        | .ub => "UB"
        | .timeout => "TIMEOUT"
      | _ => "BADLINE"
    | _ => "BADLINE"
  | _ => "BADLINE"

def runDictLookup (rest : List String) : String :=
  match rest with
  | nStr :: kStr :: rest1 =>
    let n := nStr.toNat?.getD 0
    let k := kStr.toInt?.getD 0
    let (keysS, rest2) := takeN rest1 n
    let (valsS, _) := takeN rest2 n
    let keys := parseInts keysS
    let vals := parseInts valsS
    let bytesU32List (xs : List Int) : List UInt8 :=
      xs.flatMap (fun v => toU8LE (IntTy.u32.wrap v) 4)
    let mem : Mem := fun b =>
      if b = 0 then some (bytesU32List keys)
      else if b = 1 then some (bytesI64List vals)
      else if b = 2 then some (List.replicate 8 0)
      else if b = 3 then some (List.replicate 4 0)
      else none
    let args : List Val :=
      [.ptr 0 0, .ptr 1 0, .int IntTy.u32 n,
       .int IntTy.u32 (IntTy.u32.wrap k),
       .ptr 2 0, .ptr 3 0]
    let r := callFunc Gen.prog fuel Gen.fid_lspec_dict_lookup_u32 args mem
    match r with
    | .ok (some (.int t code), m) =>
      if IntTy.toInt t code == 0 then
        match m 2, m 3 with
        | some outBlk, some foundBlk =>
          let found := decodeLE (foundBlk.take 4)
          let outV := IntTy.toInt IntTy.i64 (decodeLE (outBlk.take 8))
          if found == 0 then s!"0 0" else s!"0 1 {outV}"
        | _, _ => "ERR"
      else s!"{IntTy.toInt t code}"
    | .ok _ => "ERR"
    | .ub => "UB"
    | .timeout => "TIMEOUT"
  | _ => "BADLINE"

def runTsLinear (rest : List String) : String :=
  match rest with
  | tStr :: nStr :: rest1 =>
    let t := tStr.toInt?.getD 0
    let n := nStr.toNat?.getD 0
    if rest1.length < 3*n then "BADLINE"
    else
      let times := parseInts ((List.range n).map (fun i => rest1.getD (3*i) "0"))
      let vals := parseInts ((List.range n).map (fun i => rest1.getD (3*i+1) "0"))
      let blk := (List.range n).map (fun i => (rest1.getD (3*i+2) "0").toNat?.getD 0)
      let bytesU8List (xs : List Nat) : List UInt8 :=
        xs.map (fun v => (v % 256).toUInt8)
      let mem : Mem := fun b =>
        if b = 0 then some (bytesI64List times)
        else if b = 1 then some (bytesI64List vals)
        else if b = 2 then some (bytesU8List blk)
        else if b = 3 then some (List.replicate 8 0)
        else if b = 4 then some (List.replicate 4 0)
        else none
      let args : List Val :=
        [.ptr 0 0, .ptr 1 0, .ptr 2 0, .int IntTy.u32 n,
         .int IntTy.i64 (IntTy.i64.wrap t),
         .ptr 3 0, .ptr 4 0]
      let r := callFunc Gen.prog fuel Gen.fid_lspec_ts_linear_eval_i64 args mem
      match r with
      | .ok (some (.int _ code), m) =>
        match m 3, m 4 with
        | some outBlk, some kindBlk =>
          let kind := decodeLE (kindBlk.take 4)
          let outV := IntTy.toInt IntTy.i64 (decodeLE (outBlk.take 8))
          s!"{kind} {outV}"
        | _, _ => "ERR"
      | .ok _ => "ERR"
      | .ub => "UB"
      | .timeout => "TIMEOUT"
  | _ => "BADLINE"

def runQuoteLen (rest : List String) : String :=
  match rest with
  | hex :: _ =>
    let bs := parseHex hex
    let mem : Mem := fun b => if b = 0 then some bs else none
    let args : List Val := [.ptr 0 0, .int IntTy.u32 bs.length]
    let r := callFunc Gen.prog fuel Gen.fid_lspec_quote_len args mem
    showRes r
  | _ => "BADLINE"

def runOffsetValid (rest : List String) : String :=
  match rest with
  | bitsStr :: _ =>
    let bits := bitsStr.toNat?.getD 0
    let args : List Val := [.f64 bits]
    let mem : Mem := fun _ => none
    let r := callFunc Gen.prog fuel Gen.fid_lspec_offset_valid args mem
    showRes r
  | _ => "BADLINE"

def runOffsetSanitize (rest : List String) : String :=
  match rest with
  | bitsStr :: _ =>
    let bits := bitsStr.toNat?.getD 0
    let mem : Mem := fun b => if b = 0 then some (List.replicate 8 0) else none
    let args : List Val := [.f64 bits, .ptr 0 0]
    let r := callFunc Gen.prog fuel Gen.fid_lspec_offset_sanitize args mem
    match r with
    | .ok (some (.int t code), m) =>
      if IntTy.toInt t code == 0 then
        match m 0 with
        | some blk => s!"{decodeLE (blk.take 8)}"
        | none => "ERR"
      else s!"{IntTy.toInt t code}"
    | .ok _ => "ERR"
    | .ub => "UB"
    | .timeout => "TIMEOUT"
  | _ => "BADLINE"

def runLine (line : String) : String :=
  let toks := (line.trimAscii.toString.splitOn " ").filter (fun s => s != "")
  match toks with
  | "most_common" :: rest => runMost rest
  | "contains" :: rest => runContains rest
  | "crate_enc" :: rest => runCrateEnc rest
  | "crate_dec" :: rest => runCrateDec rest
  | "listop_apply" :: rest => runListop rest
  | "listop_iterate" :: rest => runListopIterate rest
  | "listop_reduce" :: rest => runListopReduce rest
  | "listop_combine" :: rest => runListopCombine rest
  | "dict_merge" :: rest => runDictMerge rest
  | "dict_lookup" :: rest => runDictLookup rest
  | "ts_held_bits" :: rest => runTsHeldBits rest
  | "ts_linear" :: rest => runTsLinear rest
  | "scan_quoted" :: rest => runScanQuoted rest
  | "quote_len" :: rest => runQuoteLen rest
  | "offset_valid" :: rest => runOffsetValid rest
  | "offset_sanitize" :: rest => runOffsetSanitize rest
  | _ => "BADLINE"

def main : IO Unit := do
  let stdin ← IO.getStdin
  let mut line ← stdin.getLine
  while line != "" do
    IO.println (runLine line)
    line ← stdin.getLine
