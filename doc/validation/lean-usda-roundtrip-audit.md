# Supported USDA AST round-trip audit

The theorem `UsdSpec.Usda.parseLayer_print` in
[LayerProofs.lean](../../verif/lean/UsdSpec/Usda/LayerProofs.lean) proves
`Layer.WellFormed l → parseLayer l.print = some l` by structural equality of the
AST. It uses the actual parser and printer, including their input-length fuel.
Equality is not defined through printing, and no whole-parser-success hypothesis
is included in the admissibility predicates.

## Constructor coverage

| AST component | Cases and conditions | Recovery evidence |
| --- | --- | --- |
| Specifier | `def`, `over`, `class` | `specifier_print_general`, `prim_print_prefix` |
| Qualifier | explicit, prepend, append, delete | three `primMeta_*_print` arc statements |
| Offset | both optional fields independently present/absent; present numeric lexemes satisfy the subset scanner | `optOffset_print` |
| Sublayer | asset without an internal `@`, any supported offset | `subLayer_print`, `subLayer_bracket_body` |
| Reference | asset-only, path-only, both; delimiter-safe contents; at least one field | `reference_print`, `reference_bracket_padding` |
| Dictionary integer | every mathematical `Int`, without a magnitude bound | `numLexeme_int_string`, `int_print`, `dictItems_int_step` |
| Dictionary string | arbitrary `String` | `str_print`, `dictItems_str_step` |
| Dictionary nesting | arbitrary entry counts/depth, order and duplicate entries | `dictItems_nested`, `dict_nested` |
| Dictionary keys | arbitrary `String`, at every nesting depth | quoted-key prefix/step inverses, `EntriesWellFormed_all` |
| Prim metadata | references, inherits, specializes, customData; arbitrary mixed sequences | `primMeta_print`, `primMetas_print_text` |
| Attribute default | scanner-admissible identifier and numeric lexeme | `attrRest_value`, `primItems_printAttr` |
| Attribute samples | arbitrary pair counts/order; both lexemes scanner-admissible | `samples_print_text`, `attrRest_samples` |
| Prim | all specifiers, optional identifier type, arbitrary quoted name, metadata and mixed attribute/child bodies | `prim_recovery`, `prim_print` |
| Prim forest | arbitrary counts/order, whitespace and complete EOF consumption | `prims_print`, `prims_print_text` |
| Layer | sublayers absent, explicitly empty, or populated; empty or populated prim forest; printed `#usda 1.0` header | `parseHeader_print`, `layerSubs_some`, `parseLayer_print` |

`Prim.parserCost`/`Prim.itemsCost` and `dictCost` count recursive parser work.
Direct fuel induction handles both child and sibling calls. Printed-length
bounds discharge actual fuel at every recursive boundary; there is no depth,
list-count, string-length or lexeme-length ceiling. Generic item-parser
hypotheses in list combinators are discharged by concrete inverse theorems.

The remaining lexical conditions describe the model's accepted scanners:
identifier starts/continuations, nonempty numeric-character lexemes, and the
single-delimiter asset/path syntax. They do not encode a finite corpus, an
expected parser result, composition validity, sorted/unique timestamps, valid
URIs, finite numbers or native C++ integer range. Empty references with neither
asset nor path are rejected by the modeled reference parser itself.

## Dictionary-key completion check

The initial assembled proof excluded quoted dictionary keys via `IdentLexeme`.
That restriction was insufficient: the model parser accepted a key containing a
space, but its printer emitted that key bare. The printer now quotes all keys.
The entry inverses no longer require identifier-shaped keys, and
`EntriesWellFormed_all` proves admissibility for every dictionary tree. An
independent domain check proves recovery for every `String` key and `DVal`, and
computes the former spaced-key and nested Unicode/NUL counterexamples positively.

The seventeenth generated table contains 135 actual `Layer.print` cases: 45 keys
across integer, string and nested dictionary entries. The independently pinned
manifest includes all ASCII controls, empty strings, quote/backslash, Unicode,
punctuation, leading digits, keywords and namespace separators. Native
production paths check exact dictionary membership, type/value and nesting after
parsing, USDA rewriting and representable USDC transport.

These cases exposed a native writer defect: `namespace:key` was emitted bare,
then rejected during strict reparsing. The native dictionary printer now treats
namespace separators as requiring quoted DictionaryKey syntax. Stock
`usd-core==26.11` checks all 135 cases: 399 source/native-text/native-crate semantic
comparisons, 129 exact stock crate round trips and six explicitly classified
NUL-key truncations. LightUSD rejects those six unrepresentable crate writes.
The original 40 string cases and their two classified stock NUL-value losses
remain separately checked. Both scripts verify the oracle package and pxr path.

## Verification and remaining scope

The native Debug suite passes 100/100, including all 12 Lean gates. The production
vector consumer reports 39,091 checks and zero failures. The compiled audit covers
3,101 project theorems (493 private) in 42 modules, with dependencies limited to
`propext`, `Classical.choice` and `Quot.sound`. Reflection resolves all seven
references. The published specification checksum remains unchanged.

This closes the general **supported operational AST** round-trip and printer
escaping item. It does not claim complete coverage of the normative 166-rule PEG,
source hexadecimal/short-octal escapes, Unicode XID fidelity or semantic USD
validation. Those specification/model audits and all remaining implementation,
composition, NFC, spline, vector and regression tasks retain their original scope
in [the follow-up ledger](lean-followup-status.md).
