---
Template: Symbol
Name: ArrayContract
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayContract
Keywords: [tensor contraction, trace, tensor product, operand set, array container, symbolic array]
SeeAlso: [ArrayTranspose, ArrayPart, SimplifyArray, ArrayDimensions, ArrayMaterialize, ArraySymbolicQ, ArrayContainerQ, ArrayUnify, ArrayTier]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayContract]()[*a*, *pairs*]</code> contracts the given index *pairs* of the array container *a*.

<code>[ArrayContract]()[[Inactive]()[[TensorProduct]()][$a_1$, $a_2$, ...], *pairs*]</code> contracts index pairs of the operand set $a_1$, $a_2$, ....

## Details & Options

- *pairs* is a list of slot groups <code>{{$s_1$, $t_1$}, ...}</code>, as in [TensorContract](). A group of two slots is an ordinary contraction, a group of one slot sums that slot, and a group of three or more is a generalized trace over the slots it names.
- Every slot names a level the operands have, and names it once. A specification that does not is left as an inactive [TensorContract]() node, without the tensor product being built.
- A [List]() argument is one array, whose own levels the *pairs* number: contracting the two levels of a plain nested-list matrix is its trace, matching its [SparseArray]() form. The equivalence holds for a [List]() whose elements are not themselves array containers; a list that holds one is read as an operand set given in place of a node and is declined.
- An operand set is spelled as an inactive [TensorProduct](), over whose concatenated operand levels the *pairs* run. A list that holds an array container and is not a list of plain [List]()s is such a set given in place of a node, and gives an `ArrayContract::operands` message and stays unevaluated. A declined call is not an array container: it has no tier and no dimensions, no accessor answers for it, and [Normal]() of it is the call itself, its operands unconverted.
- The operands of a node are contracted against each other and the tensor product is never built, which is what keeps the containers: an all-[SparseArray]() set gives a [SparseArray](), packed operands give a packed array, exact operands stay exact, and a [QuantityArray]() set gives a [QuantityArray]() carrying the product of the units.
- A contraction over a [SparseArray]() whose background is not zero, and one over two structured atoms such as [SymmetrizedArray](), is dense, that being what contracting the operands pairwise gives. A single structured operand keeps its structure, [TensorContract]() preserving [SymmetrizedArray]() structure natively.
- A node of ONE operand has no product to keep that operand out of, so it is contracted bare and gives what contracting the container itself gives.
- The result is a container of the tier [ArrayUnify]() joins the operands to. Explicit operands contract through the node, which evaluates immediately: contracting the two levels of a matrix gives its trace.
- An operand set carrying a symbolic container gives an inactive [TensorContract]() node, and [ArrayDimensions]() reads the contracted shape off that node without materializing it.
- An operand set carrying exactly one lazy container and no symbolic one is contracted against the value grid, the branch values or the body of that operand and stays lazy where its head supplies a lazy-preserving rebuild.
- An operand set carrying several lazy containers, and a contraction that leaves no array at all, have no lazy form between them: every lazy operand is expanded per scalar and the contraction is explicit, giving an array, or for a full contraction a scalar, of expressions that substitute to the contracted values.
- [TensorContract]() does not evaluate on the heads that are not [ArrayQ](), so a [NumericArray](), a [ByteArray](), a [Dataset](), a [Tabular]() and an [ArrayObject]() handle contract their materialized data, alone or as an operand of a node. A [QuantityArray]() is [ArrayQ]() and contracts natively, keeping its unit.
- An empty contraction <code>{}</code> gives *a* itself, via [SimplifyArray](); over a node of several operands it is their outer product.
- If any dimension of *a*, or of any operand of a node, is 0, the result is the empty array `{}`.

## Basic Examples

<!-- #| annotation: 05.09.26: Design review - an operand SET is spelled Inactive[TensorProduct][a1, a2, ...] and a List is ONE array, because one spelling cannot carry both readings. A List of containers told from a single array by whether every element is itself a List reads an operand set of plain nested Lists as one array and answers a different question, silently and in a container that looks right, so such a list is declined with a message naming the node spelling rather than answered. The node is the one place in the paclet where containers of different kinds meet, so it dispatches on the tier ArrayUnify joins its operands to rather than on whichever operand's form happens to survive TensorContract. Its operands are contracted against each other and the product is never built, which is where the container preservation comes from: each pairwise contraction is the operands' own arithmetic, where building the product first flattens all of it. -->

Contracting the two levels of a matrix gives its trace:

```wl
ArrayContract[SparseArray[{{1, 2}, {3, 4}}], {{1, 2}}]
```

<!-- => 5 -->

---

An operand set is spelled as an inactive [TensorProduct](), and contracting the second level of one matrix against the first of the next is their product:

```wl
product = ArrayContract[Inactive[TensorProduct][SparseArray[{{1, 2}, {3, 4}}], SparseArray[{{5, 6}, {7, 8}}]], {{2, 3}}]
```

<!-- => a SparseArray summary box: rank 2, dimensions {2, 2}, 4 stored elements -->

The operands are contracted against each other, so the product is never built and the [SparseArray]() survives:

```wl
Normal[product]
```

<!-- => {{19, 22}, {43, 50}} -->

---

A [List]() argument is one array, whose own levels the pairs number:

```wl
ArrayContract[{{1, 2}, {3, 4}}, {{1, 2}}]
```

<!-- => 5 -->

---

A symbolic container stays in inactive [TensorContract]() form:

```wl
contraction = ArrayContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}]
```

<!-- => TensorContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}] -->

The contracted shape reads off the wrapper:

```wl
ArrayDimensions[contraction]
```

<!-- => {3} -->

## Scope

### Explicit containers

Contracting the two levels of two vector operands is their inner product:

```wl
ArrayContract[Inactive[TensorProduct][SparseArray[{1., 2.}], SparseArray[{3., 4.}]], {{1, 2}}]
```

<!-- => 11. -->

---

A node takes any number of operands, and one group per contracted pair chains them:

```wl
chain = ArrayContract[Inactive[TensorProduct][SparseArray[{{1, 2}, {3, 4}}], SparseArray[{{5, 6}, {7, 8}}], SparseArray[{{1, 0}, {0, 1}}]], {{2, 3}, {4, 5}}]
```

<!-- => a SparseArray summary box: rank 2, dimensions {2, 2}, 4 stored elements -->

The identity operand leaves the product of the first two:

```wl
Normal[chain]
```

<!-- => {{19, 22}, {43, 50}} -->

---

An empty pair list over a node of two operands is their outer product:

```wl
outer = ArrayContract[Inactive[TensorProduct][SparseArray[{1, 2}], SparseArray[{3, 4}]], {}]
```

<!-- => a SparseArray summary box: rank 2, dimensions {2, 2}, 4 stored elements -->

The elements are the pairwise products:

```wl
Normal[outer]
```

<!-- => {{3, 4}, {6, 8}} -->

---

A group of one slot sums that slot:

```wl
rowsums = ArrayContract[Inactive[TensorProduct][SparseArray[{{1, 2}, {3, 4}}]], {{2}}]
```

<!-- => a SparseArray summary box: rank 1, dimensions {2}, 2 stored elements -->

The second level is summed away, leaving the row sums:

```wl
Normal[rowsums]
```

<!-- => {3, 7} -->

---

A group of three or more slots is a generalized trace over the slots it names:

```wl
ArrayContract[Inactive[TensorProduct][{1, 2}, {3, 4}, {5, 6}], {{1, 2, 3}}]
```

<!-- => 63 -->

---

Contracting a [SymmetrizedArray]() keeps the structured atom:

```wl
contracted = ArrayContract[SymmetrizedArray[{{1, 2, 1, 2} -> 1.}, {2, 2, 2, 2}, Symmetric[{1, 2}]], {{1, 3}}]
```

<!-- => a SymmetrizedArray summary box: dimensions {2, 2}, no residual symmetry, 1 rule -->

The contracted elements are those of the dense computation:

```wl
Normal[contracted]
```

<!-- => {{0, 0}, {0, 1.}} -->

### Wrapper containers

A [QuantityArray]() contracts natively, so the trace of a matrix of lengths is a length:

```wl
ArrayContract[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"], {{1, 2}}]
```

<!-- => Quantity[5., "Meters"] -->

---

A node of two of them carries the product of the units:

```wl
ArrayContract[Inactive[TensorProduct][QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"], QuantityArray[{{5., 6.}, {7., 8.}}, "Meters"]], {{2, 3}}]
```

<!-- => a QuantityArray summary box: dimensions {2, 2}, unit "Meters"^2 -->

---

[TensorContract]() does not evaluate on a [NumericArray](), so that operand contracts its materialized data:

```wl
ArrayContract[NumericArray[{{1., 2.}, {3., 4.}}, "Real64"], {{1, 2}}]
```

<!-- => 5. -->

### Lazy containers

An operand set carrying exactly one lazy container is contracted against the body of that operand and stays lazy:

```wl
rotated = ArrayContract[Inactive[TensorProduct][SparseArray[{{1, 2}, {3, 4}}], Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]], {{2, 3}}]
```

<!-- => Function[th, {{Cos[th] + 2*Sin[th], 2*Cos[th] - Sin[th]}, {3*Cos[th] + 4*Sin[th], 4*Cos[th] - 3*Sin[th]}}] -->

The result is a container of the tier the operands join to:

```wl
ArrayTier[rotated]
```

<!-- => "Lazy" -->

### Symbolic containers

An operand set mixing an explicit container with a symbolic one gives an inactive [TensorContract]() node, with the pairs indexing the concatenated levels:

```wl
ArrayContract[Inactive[TensorProduct][SparseArray[{{1, 0}, {0, 1}}], VectorSymbol["u", 2]], {{1, 3}}]
```

<!-- => TensorContract[Inactive[TensorProduct][SparseArray[...], VectorSymbol["u", 2]], {{1, 3}}] -->

---

Contracting the two levels of two symbolic vectors carries their inner product instead of performing it:

```wl
ArrayContract[Inactive[TensorProduct][VectorSymbol["u", 2], VectorSymbol["w", 2]], {{1, 2}}]
```

<!-- => TensorContract[Inactive[TensorProduct][VectorSymbol["u", 2], VectorSymbol["w", 2]], {{1, 2}}] -->

---

An empty contraction gives the container itself:

```wl
ArrayContract[MatrixSymbol["M", {2, 3}], {}]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

## Properties and Relations

Contracting both levels of an explicit container takes its trace:

```wl
ArrayContract[SparseArray[{{1, 2}, {3, 4}}], {{1, 2}}]
```

<!-- => 5 -->

---

[TensorContract]() on the dense form gives that same value:

```wl
TensorContract[{{1, 2}, {3, 4}}, {{1, 2}}]
```

<!-- => 5 -->

---

A node of two operands contracts them against each other:

```wl
ArrayContract[Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

[TensorContract]() over the built [TensorProduct]() gives that same array, having formed the rank-4 product first:

```wl
TensorContract[TensorProduct[{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

A tensor product with a zero-dimensional factor contracts to the empty array:

```wl
ArrayContract[Inactive[TensorProduct][{}, {1, 2}], {{1, 2}}]
```

<!-- => {} -->

## Possible Issues

A list of array containers is declined, a [List]() argument already meaning one array:

```wl
ArrayContract[{SparseArray[{1., 2.}], SparseArray[{3., 4.}]}, {{1, 2}}]
```

<!-- => ArrayContract::operands message, then ArrayContract[{SparseArray[...], SparseArray[...]}, {{1, 2}}] unevaluated -->

The same operands under an inactive [TensorProduct]() are the operand set the pairs run over:

```wl
ArrayContract[Inactive[TensorProduct][SparseArray[{1., 2.}], SparseArray[{3., 4.}]], {{1, 2}}]
```

<!-- => 11. -->

---

A list holding a container beside a bare scalar names a set as plainly, and is declined too:

```wl
declined = ArrayContract[{2, SparseArray[{{1, 2}, {3, 4}}]}, {{1, 2}}]
```

<!-- => ArrayContract::operands message, then ArrayContract[{2, SparseArray[...]}, {{1, 2}}] unevaluated -->

A declined call is not an array container, so it has no tier:

```wl
ArrayTier[declined]
```

<!-- => Missing["NotAContainer"] -->

[Normal]() of a declined call is the call itself, its operands unconverted, rather than a densified list read as the single array the call was declined as:

```wl
Normal[declined]
```

<!-- => ArrayContract[{2, SparseArray[{{1, 2}, {3, 4}}]}, {{1, 2}}] unevaluated -->

---

A bare scalar is an operand of rank 0 under the node spelling, and the set contracts:

```wl
ArrayContract[Inactive[TensorProduct][2, SparseArray[{{1, 2}, {3, 4}}]], {{1, 2}}]
```

<!-- => 10 -->

---

A list of plain nested-list matrices is one rank-3 array, so the pairs number its own levels and the result is not a matrix product:

```wl
ArrayContract[{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{2, 3}}]
```

<!-- => {5, 13} -->

Under an inactive [TensorProduct]() those same two matrices are two operands:

```wl
ArrayContract[Inactive[TensorProduct][{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}], {{2, 3}}]
```

<!-- => {{19, 22}, {43, 50}} -->

---

Operands whose background is not zero are contracted pairwise into a dense array, there being no sparse structure left to keep:

```wl
ArrayContract[Inactive[TensorProduct][SparseArray[{{1, 1} -> 2}, {2, 2}, 1], SparseArray[{{1, 1} -> 2}, {2, 2}, 1]], {{2, 3}}]
```

<!-- => {{5, 3}, {3, 2}} -->
