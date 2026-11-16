---
Template: Symbol
Name: ArrayIndexContract
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayIndexContract
Keywords: [index notation, einsum, tensor contraction, trace, hyperedge, batch matrix product, quantity array]
SeeAlso: [ArrayIndexTransform, ArrayIndexPattern, ArrayIndexPlan, ArrayContract, ArrayTranspose, ArrayMaterialize, ArrayTier, ArrayUnify]
RelatedGuides: [Arrays]
RelatedTutorials: [IndexNotation]
---

## Usage

<code>[ArrayIndexContract]()[*desc*, {$a_1$, $a_2$, ...}]</code> contracts the given array containers according to the index descriptor *desc*.

<code>[ArrayIndexContract]()[*desc*, *arrays*, *bindings*]</code> takes axis sizes out of band from a list of rules.

<code>[ArrayIndexContract]()[*plan*, *arrays*]</code> executes a prepared [ArrayIndexPlan]().

## Details & Options

- *desc* is a descriptor in the classic einsum dialect (`"ij,jk->ik"`), in the einx identifier dialect (`"b s d, d e -> b s e"`), or in the Wolfram list-of-shapes dialect (`{{i_, j_}, {j_, k_}} :> {{i, k}}`); [ArrayIndexPattern]() compiles it and owns the tokenizing rules, the axis spellings and the target spelling.
- A prepared [ArrayIndexPattern]() stands in the descriptor position as a prepared [ArrayIndexPlan]() does, its sizes solved against the operands rather than carried; either object is taken apart rather than compiled again, which is the compile-once path.
- An axis on the output is carried; an axis absent from the output is summed over every slot carrying it.
- By occurrence count: one occurrence sums that slot, two are an ordinary contraction, three and more are an axis shared by three operands, and an axis repeated within one input shape and absent from the output is self-contracted, which is the trace.
- An axis the output carries that two or more operands supply is a batch index, which is what makes a batch matrix product, a Hadamard product and a column scaling ordinary descriptors. It is a delta among the operands of the contraction, one slot tied to each occurrence and one left free to carry the axis to the output, and [ArrayContract]() contracts it block by block, at the cost of the result rather than of the operands' outer product.
- With no output shape written the output is the axes occurring exactly once, in first-occurrence order rather than sorted; [ArrayIndexPattern]() owns the `"DefaultOutput"` rule and the difference between an empty output side and a missing one.
- The steps keep the container they are handed: a [SparseArray]() and a packed array come back as themselves whatever steps the descriptor emits, a batch index included.
- The contraction step is lowered to [ArrayContract]() over the inactive [TensorProduct]() of its operands, which contracts them against each other without ever building that product; a rank-0 operand is a factor of the same node.
- With the sum-of-products combiner every step is linear in its operands, so the unit of a [QuantityArray]() is lifted off it, the steps run on the magnitudes, and the product of the units goes back on the result.
- The result is a [QuantityArray]() in the product unit whatever steps the descriptor emits, an ordinary [Quantity]() where the result is rank 0 and there is no [QuantityArray]() to build, and an unwrapped array where the units cancel and their product is a plain number.
- A [QuantityArray]() carrying a unit per column has no single unit to lift; one such operand leaves the whole operand set as it stands, and the elements carry their own units.
- A [NumericArray](), a [TabularColumn](), a [Tabular](), a [Dataset](), an [EventSeries]() and a [ByteArray]() are materialized first, [TensorProduct]() having no evaluation on those heads, and an [ArrayObject]() is unwrapped at the door and the result is the bare container it holds; [ArrayIndexTransform]() keeps the same door.
- A [List]() in the second argument is the operand list, so a single array operand is given as a one-element list.
- Every step keeps a symbolic operand inert and a lazy one lazy, so the result has the tier the operands join to. A symbolic operand gives an inert contraction tree whose [ArrayDimensions]() is the output shape, which [ArrayMaterialize]() computes once its symbols are given values; a lazy operand gives a lazy container where its head can rebuild through the steps, and a contraction that leaves no array gives a scalar expression in the lazy operand's parameter.
- A deferred tree, a structural tree over explicit containers alone, is materialized at the door, since it has a value and merely defers computing it.
- The options are:

| Option | Settings |
|---|---|
| `"Combiner"` | `{Times, Plus}`, the sum of products a contraction over an inactive [TensorProduct]() expresses |
| `"DefaultOutput"` | `"Contracted"` (default) or `"Identity"` |
| `"DimensionMismatch"` | `"Error"` (default) or `"Pad"` |
| `"Inactive"` | `False` (default) or `True` |
| `"IndexMultiplicity"` | `False` (default) or `True` |
| `"Targeting"` | `Automatic` (default), `True`, `False` |

- With `"DimensionMismatch" -> "Pad"` an axis the operands give different sizes takes the largest, and a shorter operand is padded to it by `IndexedMultiply`'s rule: an extent of 1 is repeated, and any other extent is padded at the end with 1s. A literal size still has to match.
- With `"IndexMultiplicity" -> True` an output shape may name an axis more than once, and the result is the tensor power `EinsteinSummation` reads there: the contraction with each output axis once, in as many copies as the most-repeated axis has occurrences, the *r*-th occurrence of an axis read from the *r*-th copy, and an axis's levels in the copies past its own count summed together. An axis repeated inside an output composite, and one repeated within one input shape and kept, are declined still.
- With `"Inactive" -> True` the result is the plan's tree unevaluated: [Inactive]()[[ArrayContract]()] over an [Inactive]()[[TensorProduct]()] of the operands, a batch index's delta among them, with [Inactive]()[[Transpose]](), [Inactive]()[[ArrayReshape]]() and, for a repeated axis, an [Inactive]()[[TensorProduct]]() with vectors of ones above it. Every node has the dimensions of what it stands for, a rank-0 result included, and [ArrayMaterialize]() computes the tree, contracting before it builds any product. A deferred tree among the operands stays a leaf of it.
- With `"Targeting" -> Automatic` an explicit target marks a contracted axis exactly; with `True` every contracted axis carries a target; with `False` target wrappers are ignored and a repeated name alone contracts, which is the classic einsum reading.
- `"Combiner"` and `"Inactive"` are read at execution, so a prepared [ArrayIndexPlan]() takes them as a descriptor does. `"Targeting"`, `"DefaultOutput"`, `"DimensionMismatch"`, `"IndexMultiplicity"` and a *bindings* list are read where a descriptor is compiled, so a prepared object carries what its own construction resolved and is declined them; [ArrayIndexPlan]() owns that rule. An option name `ArrayIndexContract` does not declare is declined before any setting is read.

## Basic Examples

<!-- #| annotation: 05.09.26: Design review - the contraction is ArrayContract over an inactive TensorProduct, which is that symbol's spelling for an operand set, so the step names the operation rather than the way it is executed. What ArrayContract does with the node is what the index layer needs of it: the operands are contracted against each other, the outer product is never built, and the containers survive - a SparseArray set gives a SparseArray, packed operands stay packed, exact operands stay exact and a structured atom keeps its structure. TensorContract takes a slot group of any length, so a hyperedge needs no pairwise decomposition and the plan carries groups rather than pairs. The unit lift is descriptor-wide rather than one wrapper rule per primitive: with the sum-of-products combiner the plan is multilinear in its operands and registers 1..n are read once each, so the result scales by each operand's unit exactly once, no step depends on the units, and the plan expression is unchanged - what it runs on is the magnitudes. A batch index is a delta in the contraction rather than an alignment of the operands into one frame: the alignment builds their outer product before summing anything, and it has no form that keeps a symbolic operand inert, while the delta costs what the result costs and is one more operand of a node that already stays inert or lazy. It is written inactive in the plan because the evaluator unpacks a packed array beside an active one. -->

A shared axis absent from the output contracts the two operands, giving the matrix product:

```wl
ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

An axis occurring once and absent from the output sums that slot:

```wl
ArrayIndexContract["ij->i", {{{1, 2}, {3, 4}}}]
```

<!-- => {3, 7} -->

---

An axis repeated within one input shape and absent from the output is the trace:

```wl
ArrayIndexContract["ii->", {{{1, 2}, {3, 4}}}]
```

<!-- => 5 -->

---

An axis carried by both operands and by the output is a batch axis, and the contraction runs inside it:

```wl
batch = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}};
ArrayIndexContract["bij,bjk->bik", {batch, batch}]
```

<!-- => {{{7, 10}, {15, 22}}, {{67, 78}, {91, 106}}} -->

## Scope

### Contraction by occurrence

Both axes summed give the total of the matrix:

```wl
ArrayIndexContract["ij->", {{{1, 2}, {3, 4}}}]
```

<!-- => 10 -->

---

Operands sharing no axis are not contracted at all, and the output carries both axes:

```wl
ArrayIndexContract["i,j->ij", {{1, 2}, {3, 4, 5}}]
```

<!-- => {{3, 4, 5}, {6, 8, 10}} -->

---

An axis on three operands and absent from the output sums the three slots together:

```wl
ArrayIndexContract["i,i,i->", {{1, 2}, {3, 4}, {5, 6}}]
```

<!-- => 63 -->

---

The same axis kept on the output is multiplied elementwise instead:

```wl
ArrayIndexContract["i,i,i->i", {{1, 2}, {3, 4}, {5, 6}}]
```

<!-- => {15, 48} -->

---

With no output shape written the output is the axes occurring exactly once, here `i` and `k`:

```wl
ArrayIndexContract["ij,jk", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

### Batch indices

Two axes carried by both operands and by the output make the elementwise product:

```wl
ArrayIndexContract["ij,ij->ij", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{5, 12}, {21, 32}} -->

---

An axis carried by one operand and by the output scales the columns of the other:

```wl
ArrayIndexContract["ij,j->ij", {{{1, 2}, {3, 4}}, {10, 20}}]
```

<!-- => {{10, 40}, {30, 80}} -->

---

Dropping that axis from the output sums the scaled columns, giving the matrix-vector product:

```wl
ArrayIndexContract["ij,j->i", {{{1, 2}, {3, 4}}, {10, 20}}]
```

<!-- => {50, 110} -->

### Symbolic and lazy operands

A symbolic operand gives the inert contraction tree:

```wl
tree = ArrayIndexContract["ij,jk->ik", {MatrixSymbol["A", {2, 2}], {{5, 6}, {7, 8}}}]
```

<!-- => TensorContract[Inactive[TensorProduct][MatrixSymbol["A", {2, 2}], {{5, 6}, {7, 8}}], {{2, 3}}] -->

The tree is a symbolic container of the output's shape:

```wl
ArrayDimensions[tree]
```

<!-- => {2, 2} -->

Given a value for the symbol, [ArrayMaterialize]() computes it:

```wl
ArrayMaterialize[tree /. MatrixSymbol["A", {2, 2}] -> {{1, 2}, {3, 4}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

A batch index over symbolic operands is a delta among the operands of the inert contraction:

```wl
ArrayIndexContract["bij,bjk->bik", {ArraySymbol["A", {2, 2, 3}], ArraySymbol["B", {2, 3, 4}]}]
```

<!-- => Inactive[TensorContract][Inactive[TensorProduct][SymbolicDeltaProductArray[{2, 2, 2}, {{1, 2, 3}}], ArraySymbol["A", {2, 2, 3}], ArraySymbol["B", {2, 3, 4}]], {{1, 4}, {2, 7}, {6, 8}}] -->

---

A lazy operand stays lazy, the contraction made against the body of the [Function]():

```wl
ArrayIndexContract["ij,j->i", {Function[t, {{Cos[t], -Sin[t]}, {Sin[t], Cos[t]}}], {1, 0}}]
```

<!-- => Function[t, {Cos[t], Sin[t]}] -->

### Dialects

The same contraction in the Wolfram list-of-shapes dialect, the input shapes given as a [RuleDelayed]() to the output shapes:

```wl
ArrayIndexContract[{{i_, j_}, {j_, k_}} :> {{i, k}}, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

A descriptor containing a space is tokenized by identifier, so the axes carry multi-character names:

```wl
ArrayIndexContract["b s d, d e -> b s e", {ArrayReshape[Range[8], {2, 2, 2}], {{1, 0}, {0, 1}}}]
```

<!-- => {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}} -->

### Containers

A contraction over [SparseArray]() operands keeps the container:

```wl
s = SparseArray[{{1, 0}, {0, 4}}];
squared = ArrayIndexContract["ij,jk->ik", {s, s}]
```

<!-- => a SparseArray summary box: rank 2, dimensions {2, 2}, 2 stored elements -->

The stored elements are those of the dense product:

```wl
Normal[squared]
```

<!-- => {{1, 0}, {0, 16}} -->

---

A descriptor emitting no contraction node keeps the container just the same, here a column scaling over a [SparseArray]():

```wl
scaled = ArrayIndexContract["ij,j->ij", {SparseArray[{{1, 0}, {0, 4}}], {10, 20}}]
```

<!-- => a SparseArray summary box: rank 2, dimensions {2, 2}, 2 stored elements -->

The stored elements are the scaled ones:

```wl
Normal[scaled]
```

<!-- => {{10, 0}, {0, 80}} -->

---

A contraction over [QuantityArray]() operands gives a [QuantityArray]() in the product of their units:

```wl
q = QuantityArray[{{1, 2}, {3, 4}}, "Meters"];
ArrayIndexContract["ij,jk->ik", {q, q}]
```

<!-- => a QuantityArray summary box: dimensions {2, 2}, unit "Meters"^2; magnitudes are {{7, 10}, {15, 22}} -->

---

The batch form of the same descriptor gives the same container at rank 3, the unit being lifted off the operands whatever steps are emitted:

```wl
batch = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}};
ArrayIndexContract["bij,bjk->bik", {QuantityArray[batch, "Meters"], QuantityArray[batch, "Meters"]}]
```

<!-- => a QuantityArray summary box: dimensions {2, 2, 2}, unit "Meters"^2; magnitudes are {{{7, 10}, {15, 22}}, {{67, 78}, {91, 106}}} -->

---

Where the result is rank 0 there is no [QuantityArray]() to build and the unit goes back on an ordinary [Quantity]():

```wl
q = QuantityArray[{{1, 2}, {3, 4}}, "Meters"];
ArrayIndexContract["ij->", {q}]
```

<!-- => Quantity[10, "Meters"] -->

---

Where the units cancel their product is a plain number and the result is unwrapped:

```wl
q = QuantityArray[{{1, 2}, {3, 4}}, "Meters"];
qinv = QuantityArray[{{1, 0}, {0, 1}}, 1/"Meters"];
ArrayIndexContract["ij,jk->ik", {q, qinv}]
```

<!-- => {{1, 2}, {3, 4}} -->

---

A [ByteArray]() has no container to rebuild and is materialized at the door:

```wl
ArrayIndexContract["i,i->", {ByteArray[{1, 2}], {3, 4}}]
```

<!-- => 11 -->

### Options

With `"DimensionMismatch" -> "Pad"` a shared axis of mismatched size takes the larger size, the shorter operand padded with 1s:

```wl
ArrayIndexContract["i,i->i", {{1, 2}, {3, 4, 5}}, "DimensionMismatch" -> "Pad"]
```

<!-- => {3, 8, 5} -->

---

With `"IndexMultiplicity" -> True` a repeated output axis is a tensor power, here the outer square of a vector:

```wl
ArrayIndexContract["i->ii", {{1, 2, 3}}, "IndexMultiplicity" -> True]
```

<!-- => {{1, 2, 3}, {2, 4, 6}, {3, 6, 9}} -->

---

With `"Inactive" -> True` the contraction is returned unevaluated, as a tree of the result's shape:

```wl
tree = ArrayIndexContract["bij,bjk->bik", {{{{1, 2}, {3, 4}}}, {{{5, 6}, {7, 8}}}}, "Inactive" -> True]
```

<!-- => Inactive[ArrayContract][Inactive[TensorProduct][SymbolicDeltaProductArray[{1, 1, 1}, {{1, 2, 3}}], {{{1, 2}, {3, 4}}}, {{{5, 6}, {7, 8}}}], {{1, 4}, {2, 7}, {6, 8}}] -->

[ArrayDimensions]() reads the shape off the tree:

```wl
ArrayDimensions[tree]
```

<!-- => {1, 2, 2} -->

[ArrayMaterialize]() computes it:

```wl
ArrayMaterialize[tree]
```

<!-- => {{{19, 22}, {43, 50}}} -->

---

With `"Targeting" -> Automatic`, the default, the targets mark the contracted axis exactly:

```wl
ArrayIndexContract["i [j], [j] k -> i k", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

With `False` the target wrappers are ignored and the repeated name alone contracts, so a target on the carried axis `i`, which `Automatic` declines, is read as the classic einsum descriptor:

```wl
ArrayIndexContract["[i] j, j k -> i k", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, "Targeting" -> False]
```

<!-- => {{19, 22}, {43, 50}} -->

### The compile-once path

A descriptor compiled against dimensions gives a plan object:

```wl
plan = ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}]
```

<!-- => an ArrayIndexPlan summary box: operands {{2, 2}, {2, 2}}, dimensions {2, 2} -->

The prepared plan stands in the descriptor position, and the contraction runs its steps:

```wl
ArrayIndexContract[plan, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

A prepared [ArrayIndexPattern]() stands there as well, the sizes being solved against the operands:

```wl
ArrayIndexContract[ArrayIndexPattern["ij,jk->ik"], {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

`"Combiner"` is read at execution rather than where a descriptor is compiled, so a prepared plan takes it:

```wl
plan = ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}];
ArrayIndexContract[plan, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, "Combiner" -> {Times, Plus}]
```

<!-- => {{19, 22}, {43, 50}} -->

## Properties and Relations

The descriptor lowers to [ArrayContract]() over the inactive [TensorProduct]() of the operands:

```wl
ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

That call written out by hand gives the same array:

```wl
ArrayContract[Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

[TensorContract]() over the built product gives it too, having formed the rank-4 tensor product first:

```wl
TensorContract[TensorProduct[{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

A batch axis carried by both operands runs the contraction inside it:

```wl
batch = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}};
ArrayIndexContract["bij,bjk->bik", {batch, batch}]
```

<!-- => {{{7, 10}, {15, 22}}, {{67, 78}, {91, 106}}} -->

---

Threading [Dot]() over the batch gives those same slices:

```wl
batch = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}};
MapThread[Dot, {batch, batch}]
```

<!-- => {{{7, 10}, {15, 22}}, {{67, 78}, {91, 106}}} -->

---

A single occurrence summed is a total over that level:

```wl
ArrayIndexContract["ij->i", {{{1, 2}, {3, 4}}}]
```

<!-- => {3, 7} -->

---

[Total]() at that level gives the same vector:

```wl
Total[{{1, 2}, {3, 4}}, {2}]
```

<!-- => {3, 7} -->

---

The product of two matrices, bound to a name:

```wl
product = ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

Its dimensions are the ones the descriptor names, `i` and `k`:

```wl
ArrayDimensions[product]
```

<!-- => {2, 2} -->

---

[ArrayIndexPlan]() reads those dimensions off the descriptor and the operand dimensions, with no data:

```wl
ArrayIndexPlan["ij,jk->ik", {{2, 2}, {2, 2}}]["OutputDimensions"]
```

<!-- => {2, 2} -->

## Possible Issues

An axis repeated within one input shape and kept on the output names a diagonal, which has no lowering here:

```wl
ArrayIndexContract["ii->i", {{{1, 2}, {3, 4}}}]
```

<!-- => ArrayIndexPlan::diagonal message, then ArrayIndexContract["ii->i", {{{1, 2}, {3, 4}}}] unevaluated -->

---

A repeated axis takes exactly two occurrences, so three in one operand is declined:

```wl
ArrayIndexContract["iii->", {ArrayReshape[Range[8], {2, 2, 2}]}]
```

<!-- => ArrayIndexPlan::occurrences message, then ArrayIndexContract["iii->", {{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}}] unevaluated -->

---

Under `Automatic` a target marks a contracted axis exactly, so a target on a carried axis is declined:

```wl
ArrayIndexContract["[i] j, j k -> i k", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => ArrayIndexPlan::target message, then ArrayIndexContract["[i] j, j k -> i k", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}] unevaluated -->

---

A target marks a contracted axis where an input shape carries it, so a target on the output side marks nothing:

```wl
ArrayIndexContract["i j -> i [j]", {{{1, 2}, {3, 4}}}]
```

<!-- => ArrayIndexPlan::targetplace message, then ArrayIndexContract["i j -> i [j]", {{{1, 2}, {3, 4}}}] unevaluated -->

---

A contraction that leaves no array has no lazy form, so over a lazy operand it gives a scalar expression in the operand's parameter rather than a lazy container:

```wl
ArrayIndexContract["i,i->", {Piecewise[{{{1, 2}, z < 0}}, {3, 4}], {1, 1}}]
```

<!-- => Piecewise[{{1, z < 0}}, 3] + Piecewise[{{2, z < 0}}, 4] -->

---

A [List]() is the operand list, so a bare matrix is read as two vector operands; give a single operand as a one-element list:

```wl
ArrayIndexContract["ij->i", {{1, 2}, {3, 4}}]
```

<!-- => ArrayIndexPlan::operands message, then ArrayIndexContract["ij->i", {{1, 2}, {3, 4}}] unevaluated -->

---

A [QuantityArray]() carrying a unit per column has no single unit to lift, and its elements carry their own units:

```wl
qper = QuantityArray[{{1, 2}, {3, 4}}, {"Meters", "Seconds"}];
ArrayIndexContract["ij->i", {qper}]
```

<!-- => three Quantity::compat messages and a General::stop, then {Quantity[1, "Meters"] + Quantity[2, "Seconds"], Quantity[3, "Meters"] + Quantity[4, "Seconds"]} -->

---

The sum of products is the pairing this lowers, and any other pairing is declined:

```wl
ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, "Combiner" -> {Plus, Times}]
```

<!-- => ArrayIndexContract::combiner message, then ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, "Combiner" -> {Plus, Times}] unevaluated -->

---

An option name `ArrayIndexContract` does not declare is declined before any setting is read:

```wl
ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, "Nonsense" -> 1]
```

<!-- => ArrayIndexContract::optionname message naming the three options, then ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, "Nonsense" -> 1] unevaluated -->
