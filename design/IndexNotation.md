# Index notation for Wolfram/Arrays — consolidated design

Supersedes three separate index-notation implementations by folding them into
one compiler with one IR and one public surface, hosted in this paclet. The
phase 1 surface of section 11 is implemented; the phases after it are design.

## 1. The three inputs

| Source | Surface | Substrate | What it uniquely contributes |
| --- | --- | --- | --- |
| `THVMLink/Kernel/Einx.wl` (`TEin*`, 842 lines) | einx **string** dialect: `"b (h c) -> b h c"`, `[s]` targets, trailing `"h" -> 4` hints | THVM `TTerm` UOp graph (`Reshape`/`Permute`/`Expand`/`Reduce`/`Pad`/`Shrink`) | The *alignment* lowering algorithm, a two-pass composite size solver, ~25 ready verbs, numerically stable named reductions |
| `Gravifer/Einstoff` (`ResourceFunction["Einstoff"]`, ~5.7k lines) | WL **expression** dialect: `{{a_, b_ ⊗ c_}} :> {{a, c, b}}`, `#t` targets, `Annotation[a, 3]` sizes | explicit WL arrays | The notation, the hygiene rules, a staged immutable IR, a constraint solver, `⊕` direct sums, ellipses/sequences, within-tensor contraction, `TraceAction` |
| `Wolfram/TensorNetworks` `EinsteinSummation` (131 lines) | classic einsum: `"ij,jkl,klm->im"` or `{{i,j},{j,k,l}} -> {i,m}` | symbolic and explicit WL arrays | Symbolic-tier lowering to an inert `TensorContract`/`TensorProduct` tree, hyperedges and dimension broadcasting via `IndexedMultiply`, integration with contraction-path planning |

Each is complete on its own substrate and unusable on the other two. Arrays is
the substrate that covers all three: it already classifies, shapes and operates
on explicit, lazy and symbolic containers behind one dispatch layer, and its
structural primitives (`ArrayContract`, `ArrayTranspose`, `ReshapeArray`,
`PadArray`, `ArrayPart`, `ArrayMap`) are already tier-polymorphic.

## 2. The two observations the consolidation rests on

**The three surfaces are spellings of one descriptor.** `EinsteinSummation`'s
index-list form `{{i,j},{j,k}} -> {i,k}` is *already* Einstoff's canonical
list-of-shapes `{{i,j},{j,k}} :> {{i,k}}` written with bare symbols and
targeting inference turned off; the einx string is a lexical dialect over the
same grammar. Nothing needs to be reconciled semantically — only parsed into a
common form.

**Two of the three lowering algorithms are the same algorithm.**
`einxLiftInput` (Einx.wl:339) reshapes each operand to split composites, drops
literal axes, permutes into a global axis order, inserts unit dimensions for
absent axes and expands. `IndexedMultiply` (EinsteinSummation.wl:26) transposes
each operand into a common index frame, reshapes to insert unit dimensions and
pads to the shared extent. They were derived independently, on different
substrates, for different purposes — einx broadcasting and einsum hyperedges —
and they are the same *align-to-a-global-frame* step. Once you have it, the
elementwise verbs, hyperedge contraction and repetition all fall out of it.

So: **one grammar, one alignment core, three tier backends.**

## 3. Public surface

Six new symbols. All names verified free of `System`` collisions in 15.0.

```wolfram
ArrayIndexPattern[desc]                  (* parse + normalize; no shapes yet *)
ArrayIndexPlan[desc, dimsOrArrays]       (* solve sizes; emit an execution plan *)

ArrayIndexTransform[desc, arrays]        (* structural: rearrange/split/merge/repeat/join/split *)
ArrayIndexReduce[f, desc, arrays]        (* reduce over targeted axes *)
ArrayIndexContract[desc, arrays]         (* cross- and within-tensor contraction *)
ArrayIndexApply[f, desc, arrays]         (* feed targeted blocks to f, vmap the rest *)
```

`desc` is any of the three dialects (§4). Each executor also accepts an
`ArrayIndexPlan[...]` in place of `desc`, which is the compile-once /
apply-many path none of the three sources has and which a tensor-network
contraction loop needs.

`ArrayIndexPattern` and `ArrayIndexPlan` return inert self-describing objects
in the style of `ArrayObject`, with a summary box and properties
(`"Axes"`, `"Targets"`, `"Constraints"`, `"Effects"`; and for the plan,
`"AxisSizes"`, `"Steps"`, `"OutputDimensions"`, `"Expression"`). `"Expression"`
is Einstoff's `TraceAction -> Hold`: the lowered Arrays-primitive expression,
held, for inspection.

`ArrayIndexPlan[desc, dims]` accepting **dimensions** rather than arrays gives
shape inference with no data — which is the paclet's own thesis (shape without
materializing) applied to index notation.

### 3.1 Everything from the three sources maps onto those four executors

| Source entry | Consolidated call |
| --- | --- |
| `TEinRearrange` / `Einstoff[ArrayReshape]` / `Einstoff["Massage"]` / einops `rearrange`, `repeat` | `ArrayIndexTransform` |
| `Einstoff[Join]`, `Einstoff[Split]` (⊕) | `ArrayIndexTransform` (direction inferred from where `⊕` sits) |
| `TEinSum/Mean/Max/Min/Prod/Any/All/Var/Std/LogSumExp`, `Einstoff[ArrayReduce][f]` | `ArrayIndexReduce[f, …]`, `f` a function or a name from the shared reducer catalog |
| `TEinDot`, `Einstoff[Dot]`, `Einstoff[Inner][mul,add]`, `Einstoff["einsum"]`, `Einstoff["ArrayContract"]`, `EinsteinSummation` | `ArrayIndexContract`, option `"Combiner" -> {Times, Plus}` |
| `TEinAdd/Mul/Sub/Div/Eq/Lt/Where`, `TEinSoftmax/LayerNorm/RMSNorm/Flip/Roll`, `Einstoff[Operate][f]`, `Einstoff[Map][f]` | `ArrayIndexApply[f, …]` |
| `TEinGetAt/SetAt/AddAt/SubAt` | deferred (§11) |

The 25 `TEin*` verbs and 9 `Einstoff[…]` entrances collapse to four because
the verb *is* a parameter, not a name. `TEinSoftmax["b [s] d", x]` becomes
`ArrayIndexApply[softmax, {b_, #s, d_}, x]` with an ordinary Wolfram function;
`TEinRoll` becomes `ArrayIndexApply[RotateRight[#, k] &, …]`. This is
Einstoff's stated position (SPEC §9: "Einstoff only promises correctness of the
explicit Wolfram function the user supplies") and it is the right one here —
Arrays has no backend graph to optimize a named `where` against, so a named-op
catalog would be pure surface area.

The reducer catalog is the one place a *string* stays worth carrying, because
`"logsumexp"`, `"var"` and `"prod"` have stability-motivated lowerings
(§7.4) that a user-supplied `Variance` does not get. Carry Einstoff's set
(`sum`/`mean`/`var`/`std`/`prod`/`count_nonzero`/`any`/`all`/`max`/`min`/`logsumexp`),
which already covers every einx reduction, and accept a raw function too.

### 3.2 Entrance guards become an option

Einstoff's separate entrances (`ArrayReshape` bijective, `"ArrayContract"`
no-repetition, `"Massage"` permissive) are one core plus admission policies —
worth keeping, since they turn silent surprises into named errors, but not
worth three heads. They become one option on `ArrayIndexTransform`:

```wolfram
"Effects" -> All                     (* permissive: = Einstoff["Massage"] *)
"Effects" -> "Bijective"             (* = Einstoff[ArrayReshape]: rejects repetition, reduction, ⊕ *)
"Effects" -> {"Carried", "Contracted"}   (* = Einstoff["ArrayContract"] *)
```

The value is the set of plan effects (§6) the call admits; anything else is
rejected with a message naming the effect found and the entry that allows it.

## 4. One grammar, three dialects

A **descriptor** is `{shape, shape, …} :> {shape, shape, …}` — list of input
shapes to list of output shapes, unconditionally. A **shape** is a list of
axis terms. This is Einstoff §4.2 verbatim, and it is load-bearing: multi-output
(`⊕` split) and scalar operands (`{}`) both need it, and neither of the other
two sources can express them.

| Concept | einx string | WL expression | einsum list |
| --- | --- | --- | --- |
| named axis, inferred | `b` | `b_` | — |
| named axis, reference / bindable | `b` | `b` (bare) | `b` |
| named axis, hygienic | — | `"b"` | — |
| literal size | `4` | `4` | — |
| anonymous | `_` | `_` | — |
| ellipsis | `...` | `___` (`__` for ≥1) | — |
| named ellipsis | `a...` | `a___` / `a : t..` | — |
| composite (product) | `(h c)` | `h ⊗ c` | — |
| direct sum | `(q + k)` | `q ⊕ k` | — |
| target | `[s]` | `#s`, `Highlighted[s_]`, `Framed[s]` | (implicit: a repeated name) |
| inline size | `h=4` (kwarg) | `Annotation[h, 4]`, `Labeled[4, h]` | — |
| output | after `->` | RHS of `:>` | after `->` |

Three parsers, one `ArrayIndexPattern`:

```wolfram
ArrayIndexContract["ij,jk->ik", {a, b}]
ArrayIndexContract[{{i, j}, {j, k}} :> {{i, k}}, {a, b}]
ArrayIndexContract[{{i_, #j}, {#j, k_}} :> {{i, k}}, {a, b}]
```

all compile to the same normalized descriptor and the same plan.

### 4.1 Rules for the string dialect

Einx's tokenizer (identifiers, integers, `(`/`)`/`[`/`]`) and
`EinsteinSummation`'s `Characters[...]` splitter disagree about what `"ijk"`
means. Disambiguate lexically, once:

> A string containing a **space** is tokenized by identifier (einx dialect).
> A string with no space is tokenized by **character** (classic einsum).

`"ij,jk->ik"` and `"i j, j k -> i k"` therefore mean the same thing, and
`"b s d, d e -> b s e"` keeps multi-character names. No mode flag, no ambiguity
in either direction.

The rule cuts on any whitespace, so `"ij, jk->ik"` — a space after the comma
and nowhere else — is identifier mode, in which `ij` and `jk` are two axis
names and each operand is rank 1. That is a rank error against matrices rather
than a silent reinterpretation, but it is the one spelling where the classic
form and the einx form look alike and mean different things.

### 4.2 Rule vs RuleDelayed

`:>` is canonical; `->` is accepted with a warning, because `->` may have
evaluated the shapes away before the descriptor is seen. `EinsteinSummation`'s
existing `->` spelling is exactly that case and is the reason the warning is a
warning and not a rejection: `{{i,j},{j,k}} -> {{i,k}}` with unbound symbols
arrives intact and must keep working.

### 4.3 Call-site sugar

Two front-end sugars, normalized before the core sees them (Einstoff §4.2):

- a bare shape `{…}` stands for `{{…}}` when there is exactly one operand
- a descriptor with no arrow takes the entrance's default output

Additionally, a bare array in the `arrays` position stands for `{array}`.

The arrowless default is per-entrance, carried by a `"DefaultOutput"` option,
because the two entrances want opposite things from it. The structural and
block entrances want the identity `p :> p` — the shape-preserving case,
`ArrayIndexApply[Reverse, {___, g_ ⊗ #c}, x]`. Contraction wants einsum's rule:
the axes occurring exactly once, in first-occurrence order, so that `"ij,jk"`
means `"ij,jk->ik"`. Giving both entrances the identity default silently turns
every arrowless contraction into an outer product.

An empty output side is not the same as a missing one. `"ij->"` has an output
shape, and it is empty, so it contracts to a scalar; a tokenizer that discards
an empty trailing segment reads it as arrowless and returns the input
untouched.

## 5. Axis identity and hygiene

Adopt Einstoff §5.1/§5.6 unchanged. This is the part neither of the other two
sources has, and both are the poorer for it: einx has no hygiene problem only
because it never touches WL symbols, and `EinsteinSummation`'s bare-symbol
indices break under a bound `i`.

- The complete LHS is one binder scope. Every LHS `a_` binds or infer-checks
  the same logical axis; repeated LHS `a_` must unify to one size.
- A bare `a` on the LHS is an **ambient expression**, never localized by the
  presence of `a_` elsewhere. A bare `a` on the RHS references the completed
  LHS binding when one exists, and is ambient otherwise.
- `"a"` (and `#a`) is the fully hygienic tier, immune to any `Block`.
- Spelling kinds do not mix within one descriptor.
- Wolfram contexts do not contribute to axis identity: `` Foo`a_ `` and `a_`
  are the same axis `a`.
- After capture, an axis is an operation-local integer identity, never a
  symbol, `Unique[]`, or temporary. No symbol lifecycle is part of semantics.

The practical consequence for the einsum dialect: `EinsteinSummation`-style
bare indices keep working, and users who want them checked spell them `a_`,
`#a` or `"a"`.

## 6. Effects: the classification every entrance branches on

An axis in a descriptor lands in exactly one effect class, and the effect set
of a descriptor is what entrance guards (§3.2) admit or reject:

| Effect | Condition | Lowering |
| --- | --- | --- |
| `Carried` | present on input and output | permute |
| `Reduced` | targeted on input, absent from output, one operand | reduce step |
| `Contracted` | on ≥2 operands, absent from output | contraction |
| `SelfContracted` | repeated within one operand, absent from output | trace |
| `Broadcast` | present on output, absent from every input | repeat step |
| `TargetBlock` | targeted and kept | block feed to `f` |
| `DirectSumGroup` | inside `⊕` | slice or pad-and-add |
| `UnitAxis` | literal `1` | reshape only |

Targetedness is what separates `Reduced` from `TargetBlock`, and it is not
inferable from set difference between LHS and RHS names (Einstoff §5.2) — the
compiler must branch on it explicitly. `"Targeting" -> True | Automatic | False`
carries over as-is; `False` is the mode in which `EinsteinSummation` semantics
(contract by repeated name, no brackets anywhere) is exactly recovered, and
`Automatic` is the default.

## 7. Compilation

Five stages, each an immutable value; failure at any stage carries the source
reference of the offending fragment.

```
desc ──parse──▶ SurfaceDesc ──capture──▶ NormalizedDesc ──constrain──▶ ConstraintDesc
                                                                            │
                                                                          solve
                                                                            ▼
   result ◀──execute── ArrayIndexPlan ◀──plan── OperationAnalysis ◀──analyze── SolvedDesc
```

This is Einstoff's pipeline with `CapturedDesc` folded into `NormalizedDesc`
(the split exists there for a migration that is finished) and with `AxisTable`,
`SourceMap` and `BindingFacts` kept — the diagnostics are the reason the staged
form pays for itself.

`ArrayIndexPattern` is the pipeline stopped at `NormalizedDesc`;
`ArrayIndexPlan` is the pipeline run to completion minus execution. Caching the
pattern across many shapes, and the plan across many arrays, is the entire
reason both are public.

### 7.1 The alignment core

One algorithm, from Einx.wl / `IndexedMultiply` (§2):

1. **Global axis order** = output axes, then reduced/contracted axes, then any
   remaining input axes, deduplicated in that order. Putting output axes first
   means the final permutation is usually the identity.
2. **Lift each operand** to that order: reshape to split composites → reshape
   to drop literal axes → permute → reshape to insert size-1 dimensions for
   absent axes → broadcast to the full extent.
3. **Combine**: multiply (or apply the combiner) the lifted operands.
4. **Operate**: reduce / contract / feed blocks to `f`, dropping axes as they go.
5. **Finalize**: permute to the output order, then one reshape that merges
   composites and inserts literal axes.

Steps 1, 2 and 5 are shared by every entrance. Step 3–4 is where the four
executors differ, and it is the only place they differ.

Contraction does **not** have to go through step 3 as a materialized product:
for the explicit tier a pairwise `ArrayDot`/`Dot` fold is the fast path and
step 3 is skipped. Step 3 is the general form that makes hyperedges (an index
on ≥3 operands, which `TensorNetworks` supports and einx cannot express) and
elementwise broadcasting fall out of the same code.

### 7.2 Size solving

Three stages, cheapest first. Einx's solver is stages 1–2; Einstoff's is
stage 3. Running them in this order gets Einstoff's generality at Einx's cost
in the common case.

1. **Unify atomic axes** against operand dimensions, checking literal axes.
   Conflicts fail here, naming both sizes.
2. **Fixed-point composite resolution**: any `⊗`/`⊕` group with at most one
   unknown factor resolves by division / subtraction; iterate to a fixed point.
3. **Residual system**: hand the remaining product and sum equations, plus the
   positive-integer domain, to `Solve`. Unique solution binds; several
   solutions report *underdetermined* naming the free axes; none reports a
   mismatch.

Stage 3 is what makes `m (a ⊕ b)` with an outer size of 2 resolve `a = b = 1`,
a system einx rejects outright.

Sizes may come inline (`Annotation[a, 3]`, `Labeled[3, a]`) or out of band in a
binding list (`{"h" -> 4}`, einx's `h=4`, Einx.wl's trailing rules). Equal
facts coalesce; conflicting facts fail order-independently. A `Pattern` key
(`a_ -> 3`) is a hard rejection, not a silent no-op: a blank is inference-only.

### 7.3 Plan steps lower to primitives this paclet already has

The plan vocabulary is deliberately small, and every step already exists as a
tier-polymorphic Arrays function:

| Step | Primitive |
| --- | --- |
| `ReshapeStep` (split / merge / unit axes) | `ReshapeArray` |
| `TransposeStep` | `ArrayTranspose` |
| `ContractStep` | `ArrayMaterialize[Inactive[TensorContract][Inactive[TensorProduct][…], groups]]` |
| `MultiplyStep` (align, then combine) | elementwise `Times` on the lifted operands |
| `BroadcastStep` | tensor product with a ones vector, then permute — `ArrayMaterialize[Inactive[TensorProduct][a, ConstantArray[1, n]]]` |
| `ReduceStep`, additive | contraction against a ones vector |
| `ReduceStep`, other reducer | `ArrayMap[f, a, level]` |
| `TargetBlockStep` | permute targets last, `ArrayMap[f, a, {k}]` |
| `ConcatenateStep` (⊕ join) | `PadArray` each block into the output extent, then `Plus` |
| `SliceStep` (⊕ split) | `ArrayPart` with spans |
| `InnerStep` (combiner ≠ `{Times, Plus}`) | lift, apply `mul`, `ArrayMap[add, …]` |

Two of these are the interesting ones. **Broadcast as a tensor product with
ones** and **concatenation as pad-and-add** are not efficiency tricks — they
are the spellings that survive the symbolic and lazy tiers, because the tensor
product node and `PadArray` are already defined there. The explicit backend is
free to use a direct `Table`/`Join` fast path instead; the plan does not change.

The tensor-product node is built and handed to `ArrayMaterialize` rather than
routed through `ArrayContract`'s list form, which is narrower than it looks:
its list clause is guarded by `! AllTrue[arrays, ListQ]`, so plain nested-List
operands fall to the single-array clause, and a `SparseArray` operand meets
`SimplifyArray`'s singleton rule and comes back as a list of sparse rows. Three
operand kinds need handling before the node is built: a wrapper container
(`NumericArray`, `Dataset`, `Tabular`) is materialized first, because
`TensorProduct` has no evaluation on those heads and `Activate` degrades the
node into a `Times`; and a rank-0 operand is kept out of the product entirely
and multiplied back in, both because `TensorProduct[x, 0]` is `0` at any rank
and because the node does not evaluate with a scalar factor.

`MultiplyStep` is the alignment core's step 3 as a first-class plan step. It is
not optional: Wolfram arithmetic does not broadcast a size-1 dimension, so
every descriptor that keeps a shared axis on the output — batch matrix multiply,
Hadamard, row and column scaling, a kept hyperedge — needs the aligned operands
multiplied rather than contracted.

Two gaps in the existing primitives:

- `ArrayPart` handles integer indices and `All`. A `Span` falls through to its
  generic explicit clause and works there, but the symbolic clauses match on
  the index too: `ArrayPart[ArraySymbol["a", {4}], {1 ;; 2}]` returns
  `ArraySymbol["a"[1 ;; 2], {}]` — a rank-0 symbol where a length-2 vector was
  asked for, with no message. `SliceStep` needs a span that is right on every
  tier.
- A non-additive `ReduceStep` has no tier-polymorphic form. `ArrayMap` at a
  level is explicit-tier only. Honest statement: **additive reductions and
  contractions run on every tier; `Max`, `Variance` and friends require the
  explicit tier**, and a lazy or symbolic operand materializes first.

### 7.4 Reducer lowerings worth carrying over

Einx.wl's reduction bodies are the numerically careful ones and should be kept
as the catalog's implementations rather than re-derived:

- `logsumexp` = `max + log(sum(exp(x - max)))`, two reduce passes with a
  broadcast-back between them (Einx.wl:591)
- `softmax` = the same shift, then normalize (Einx.wl:607)
- `var` = `E[(x - E[x])²]`, population (ddof 0), matching NumPy and einx
- `prod` = `exp(sum(log x))` **only where the substrate has no product
  reduce** — on the explicit tier this is a lossy detour with a positivity
  precondition, so use a real product reduce there and keep the exp-log form
  as the fallback
- `min` = `-max(-x)`, `all` = `1 - any(1 - x)`: cheap on a substrate with only
  a MAX reduce, pointless on WL. Use `Min` and `AllTrue`.

The last two are worth stating explicitly because they are the clearest example
of a lowering that is correct in Einx.wl for a reason (the THVM UOp set has no
MIN opcode) that does not exist here.

## 8. Tier dispatch — what this paclet adds that none of the three sources has

The operand set is joined with `ArrayUnify`, exactly as `ArrayContract` already
does for its list form, and the joined tier picks the backend:

**Explicit.** Execute the steps eagerly through the Arrays primitives, which
already preserve `SparseArray` structure, packed arrays and `NumericArray`
wrappers. Pairwise `Dot`/`ArrayDot` fast path for `{Times, Plus}` contraction.

**Symbolic.** Emit the inert tree — this is `EinsteinSummation`'s lowering,
generalized past contraction: `Inactive[TensorContract][Inactive[TensorProduct][…], pairs]`
for contraction, and the unevaluated `ReshapeArray` / `PadArray` /
`ArrayTranspose` forms for the structural steps. Arrays already classifies such
a tree (`ArraySymbolicQ`), shapes it without materializing (`ArrayDimensions`
recurses through `TensorContract`, `TensorProduct`, `ArrayDot`, `ArrayReshape`
and this paclet's own unevaluated forms) and simplifies it (`SimplifyArray`).
So the symbolic backend is mostly *not writing an executor* — it is emitting
the nodes the paclet already understands. `ActivateTensors` in TensorNetworks
stays the way to force such a tree.

**Lazy.** Route every step through the existing `lazyStructuralOp` registry:
the container stays lazy where its head supplies a lazy-preserving rebuild (an
`InterpolatingFunction` value grid, `Piecewise` branch values, a `Function`
body) and materializes where it does not (`ParametricFunction`). This is the
policy `ArrayTranspose`, `ArrayContract`, `ReshapeArray` and `PadArray` already
implement; the index layer inherits it by construction rather than restating
it.

The result: `ArrayIndexContract["ij,jk->ik", {ArraySymbol["A", {2,3}], b}]`
gives an inert tree; the same call on packed arrays computes; the same call on
an `InterpolatingFunction[…][t]` stays lazy in `t`. No source in §1 can do more
than one of those three.

## 9. Divergences between the sources, and the decision for each

| # | Question | Einx.wl | Einstoff | EinsteinSummation | Decision |
| --- | --- | --- | --- | --- | --- |
| 1 | Index on ≥3 operands (hyperedge) | not expressible | pairwise only | supported via `IndexedMultiply` | **Support.** The alignment core (§7.1) gives it for free; the pairwise fold stays the fast path for the binary case. |
| 2 | Mismatched dimensions on a shared index | error | error | pads to the max (`ArrayPad`, `"Fixed"`/1) | **Error by default.** `IndexedMultiply`'s padding is a `TensorNetworks` convenience that silently changes results; expose it as `"DimensionMismatch" -> "Pad"` and leave it off. |
| 3 | Repeated axis in the **output** | n/a | rejected (no layout) | tensor power via `GeneralizedPower` | **Reject**, matching Einstoff and einx. `EinsteinSummation`'s multiplicity path is a real feature (`{{i}} :> {{i,i}}` is the outer square) but a surprising reading of a repeated name; if TensorNetworks needs it, it is `"IndexMultiplicity" -> True`, off by default. |
| 4 | Repeated axis **within one input**, dropped | not handled | self-contraction (trace), pairwise only | contracted | **Support pairwise** (GR-style traces). >2 occurrences and diagonal-keep (`aa->a`) are rejected, as in both sources. |
| 5 | Single-character index names | no | no | yes (`Characters`) | **Both**, disambiguated by whitespace (§4.1). |
| 6 | `->` vs `:>` | string only | `:>` canonical, `->` warned | `->` | **`:>` canonical, `->` warned but supported** — `EinsteinSummation` call sites depend on it. |
| 7 | Scalar operands | not handled | `{}` shape, natural | dropped and multiplied back in | **`{}` shape**, per Einstoff; the multiply-back-in is what the alignment core does anyway. |
| 8 | Where the verb lives | in the function name | curried parameter | fixed (sum-product) | **Parameter** (§3.1). |
| 9 | Combiner | `{Times, Plus}` only | `Inner[mul, add]` | `{Times, Plus}` only | **`"Combiner" -> {mul, add}`**, `{Times, Plus}` default with the native `Dot` fast path. |
| 10 | Output-only axis (repeat) | via explicit `->` axis + hint | uniform post-op broadcast | n/a | **Uniform broadcast** (Einstoff §5.5): repetition is not an operation, it is a materialization step every path routes its output through. |

## 10. File layout

Five flat kernel files, matching the existing convention (each
`Package["Wolfram`Arrays`"]`, `PackageExport` for public symbols,
`PackageScoped` for the IR):

```
Arrays/Kernel/IndexNotation.wl   dialect parsers → SurfaceDesc; capture, hygiene, interning
Arrays/Kernel/IndexSolver.wl     constraints and the three-stage size solver
Arrays/Kernel/IndexPlan.wl       effect analysis, entrance policy, plan construction
Arrays/Kernel/IndexExecute.wl    the three tier backends
Arrays/Kernel/IndexOperators.wl  the six public symbols
```

Docs follow `docs/AUTHORING.md`: one `docs/Symbols/<Name>.md` per public symbol,
plus a `docs/Tutorials/IndexNotation.md` tech note covering the dialect table
and the effect classification. Tests as `Tests/IndexNotation.wlt`,
`Tests/IndexSolver.wlt`, `Tests/IndexExecute.wlt`.

## 11. Phasing

**Phase 1 — parity with `EinsteinSummation`.** All three dialect parsers, the
descriptor IR, the size solver stages 1–2, `ArrayIndexPattern`,
`ArrayIndexPlan`, `ArrayIndexContract` and `ArrayIndexTransform` on the
explicit tier. Acceptance: `EinsteinSummation`'s own test suite passes through
`ArrayIndexContract` with `"Targeting" -> False`.

**Phase 2 — the tiers.** Symbolic and lazy backends. Acceptance: every Phase 1
test rerun with `ArraySymbol` operands returns an inert tree whose
`ArrayDimensions` matches, and with an `InterpolatingFunction[…][t]` operand
stays lazy.

**Phase 3 — reduce and blocks.** `ArrayIndexReduce`, `ArrayIndexApply`, the
reducer catalog with the §7.4 lowerings, targeting policy. Acceptance: the
`TEin*` verb surface is reproducible as calls, verified against Einx.wl's
semantics on shared shapes.

**Phase 4 — the full grammar.** `⊕` direct sums (join/split), ellipses and
named sequences, solver stage 3, entrance guards. Acceptance: Einstoff's `.wlt`
suite translated.

**Deferred, rejected loudly rather than mis-compiled** (both sources defer
these too): indexing verbs (`get_at`/`set_at`/`add_at` — they need a gather
primitive Arrays does not have), diagonal-keep, mixed within-and-cross-tensor
multi-operand einsum, and equal repeated `⊕` summands.

## 12. Validation

Three oracles, in increasing order of value:

1. Hand-written `VerificationTest`s in `Tests/`, per the existing suite.
2. **Cross-checks against the sources being consolidated** — the same
   contraction through `EinsteinSummation`, through `ResourceFunction["Einstoff"]`
   and through `ArrayIndexContract` must agree. This is the cheapest oracle
   available and it directly tests the §2 claim that the three surfaces are one
   descriptor.
3. Einstoff's Python cross-validation harness against real `einx` / `einops`,
   which rebuilds tensors from a shared dims recipe on both sides rather than
   marshaling inputs. Worth adopting wholesale as an opt-in test section; it
   catches the class of bug a hand-written expected value shares with the
   implementation.

## 13. Open questions

- **`ArrayPart` spans.** `SliceStep` needs them, and today a `Span` is
  mis-sliced by the symbolic clauses rather than declined (§7.3). Extend
  `ArrayPart`, or add a sibling that takes `Span` and keep `ArrayPart`
  index-only?
- **Non-additive reduction off the explicit tier.** Materializing is the honest
  answer today. Is a symbolic `Inactive[ArrayReduce]` node worth teaching
  `ArrayDimensions` and `ArraySymbolicQ` about, so that `Max`-reductions can
  stay symbolic?
- **Contraction order.** `ArrayIndexContract` over many operands needs a path.
  Reimplementing `TensorNetworks`' path planners here would duplicate them;
  taking a dependency inverts the current direction (TensorNetworks depends on
  Arrays). Proposal: default to a left fold that keeps only the axes a later
  operand still needs (Einstoff's `InnerStep` policy), and accept
  `"ContractionPath" -> path` so TensorNetworks can supply a planned one.
- **Does `TensorNetworks` migrate?** If `EinsteinSummation` becomes a thin
  wrapper over `ArrayIndexContract`, decisions 2 and 3 in §9 need the opt-in
  options actually implemented, and `IndexedMultiply` becomes the alignment
  core's public face. Worth doing, but it is a second project, not a
  precondition for this one.
