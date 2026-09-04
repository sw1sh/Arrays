---
Template: Symbol
Name: ArrayIndexContract
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayIndexContract
Keywords: [index notation, einsum, tensor contraction, trace, hyperedge, batch matrix product, quantity array]
SeeAlso: [ArrayIndexTransform, ArrayIndexPattern, ArrayIndexPlan, ArrayContract, ArrayTranspose, ArrayMaterialize, ArrayTier, ArrayUnify]
RelatedGuides: [Arrays]
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
- Operands sharing an axis the output carries are aligned to a common frame and multiplied elementwise before the contraction, which is what makes a batch matrix product, a Hadamard product and a column scaling ordinary descriptors.
- With no output shape written the output is the axes occurring exactly once, in first-occurrence order rather than sorted; [ArrayIndexPattern]() owns the `"DefaultOutput"` rule and the difference between an empty output side and a missing one.
- The steps keep the container they are handed: a [SparseArray]() and a packed array come back as themselves whatever steps the descriptor emits, a merge that emits no contraction node included.
- The contraction step is lowered to an inactive [TensorContract]() over the inactive [TensorProduct]() of its operands and handed to [ArrayMaterialize](); a rank-0 operand is kept out of the product and multiplied back in.
- With the sum-of-products combiner every step is linear in its operands, so the unit of a [QuantityArray]() is lifted off it, the steps run on the magnitudes, and the product of the units goes back on the result.
- The result is a [QuantityArray]() in the product unit whatever steps the descriptor emits, an ordinary [Quantity]() where the result is rank 0 and there is no [QuantityArray]() to build, and an unwrapped array where the units cancel and their product is a plain number.
- A [QuantityArray]() carrying a unit per column has no single unit to lift; one such operand leaves the whole operand set as it stands, and the elements carry their own units.
- A [NumericArray](), a [TabularColumn](), a [Tabular](), a [Dataset](), an [EventSeries]() and a [ByteArray]() are materialized first, [TensorProduct]() having no evaluation on those heads, and an [ArrayObject]() is unwrapped at the door and the result is the bare container it holds; [ArrayIndexTransform]() keeps the same door.
- A [List]() in the second argument is the operand list, so a single array operand is given as a one-element list.
- The operand set is joined and the explicit tier is required; [ArrayMaterialize]() brings a lazy or symbolic operand to one, and [ArrayTier]() is what the gate reads.
- The options are:

| Option | Settings |
|---|---|
| `"Combiner"` | `{Times, Plus}`, the sum of products an inactive [TensorContract]() over an inactive [TensorProduct]() expresses |
| `"DefaultOutput"` | `"Contracted"` (default) or `"Identity"` |
| `"Targeting"` | `Automatic` (default), `True`, `False` |

- With `"Targeting" -> Automatic` an explicit target marks a contracted axis exactly; with `True` every contracted axis carries a target; with `False` target wrappers are ignored and a repeated name alone contracts, which is the classic einsum reading.
- `"Combiner"` is read at execution, so a prepared [ArrayIndexPlan]() takes it as a descriptor does. `"Targeting"`, `"DefaultOutput"` and a *bindings* list are read where a descriptor is compiled, so a prepared object carries what its own construction resolved and is declined all three; [ArrayIndexPlan]() owns that rule. An option name `ArrayIndexContract` does not declare is declined before any setting is read.

## Basic Examples

<!-- #| annotation: 04.09.26: Design review - the contraction is built as an inactive TensorContract over an inactive TensorProduct and handed to ArrayMaterialize rather than to ArrayContract, for two independent reasons: ArrayContract's list form is guarded by ! AllTrue[arrays, ListQ], so an operand set of plain nested Lists falls through to its single-array clause and is reported as a ragged tensor, and its node form goes through SimplifyArray, whose singleton tensor-product rule maps INTO the product, so a contraction over SparseArray operands gave a list of sparse rows where a rank-2 SparseArray was asked for. TensorContract takes a slot group of any length, so a hyperedge needs no pairwise decomposition and the plan carries groups rather than pairs. The unit lift is descriptor-wide rather than one wrapper rule per primitive: with the sum-of-products combiner the plan is multilinear in its operands and registers 1..n are read once each, so the result scales by each operand's unit exactly once, no step depends on the units, and the held plan expression is unchanged - what it runs on is the magnitudes. The tier gate is a refusal and not a materialization: the merge and broadcast steps have no form that keeps a lazy or symbolic operand lazy or symbolic across them, and declining leaves the caller the choice ArrayMaterialize gives them. -->

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

### The aligned merge

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

### Dialects

The same contraction in the Wolfram list-of-shapes dialect, the input shapes given as a [RuleDelayed]() to the output shapes:

```wl
ArrayIndexContract[{{i_, j_}, {j_, k_}} :> {{i, k}}, {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

A descriptor containing whitespace is tokenized by identifier, so the axes carry multi-character names:

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

The descriptor lowers to a [TensorContract]() over the [TensorProduct]() of the operands:

```wl
ArrayIndexContract["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

That node contracted by hand gives the same array:

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

An operand set that joins to the symbolic tier is declined, and [ArrayMaterialize]() brings such an operand to the explicit tier; [ArrayIndexTransform]() declines a lazy operand the same way:

```wl
ArrayIndexContract["ij,jk->ik", {MatrixSymbol["A", {2, 2}], {{5, 6}, {7, 8}}}]
```

<!-- => ArrayIndexContract::tier message, then ArrayIndexContract["ij,jk->ik", {MatrixSymbol["A", {2, 2}], {{5, 6}, {7, 8}}}] unevaluated -->

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
