---
Template: Symbol
Name: ArrayDimensions
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayDimensions
Keywords: [array dimensions, tensor shape, shape introspection, structural tree, array container]
SeeAlso: [ArrayRank, ZeroArrayQ, ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ, ArrayDeclareShape, ArrayMaterialize, ArrayPart, ReshapeArray, ArrayObject]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayDimensions]()[*a*]</code> gives the dimensions of an array container of any tier without materializing it.

## Details & Options

- [ArrayDimensions]() never materializes its argument: every container tier has a shape route that introspects the container directly.
- Explicit containers ([SparseArray](), packed and plain [List]() arrays, structured arrays such as [SymmetrizedArray]()) use the standard tensor-dimension probe; [NumericArray]() and the wrapper containers [QuantityArray](), [TabularColumn](), [Tabular](), [Dataset](), [ByteArray](), [EventSeries]() and [DataStructure]() array stores introspect their shape metadata.
- An [EventSeries]() reports the dimensions of its values, so a scalar-valued series of length $n$ gives $\{n\}$, not $\{n, 1\}$; a [DataStructure]() store is rank 1 and gives its length.
- Each lazy head has its own shape route: an <code>[InterpolatingFunction]()[...][*t*]</code> reads the `"OutputDimensions"` property off the head, a [Piecewise]() takes the common shape of its branch values and default, and a source [NetGraph]() or [NetChain]() reads its output port, none of which evaluates the container.
- A [ParametricFunction]() application has no shape property, so its shape comes from one probe solve at a random parameter point, cached per object; later queries read the cache.
- The shape of an unapplied [Function]() comes from an [ArrayDeclareShape]() declaration where there is one, and otherwise from a formal-symbol probe and then a numeric probe, both of which evaluate the body of the [Function]().
- Symbolic containers give their declared dimensions: the second argument of [VectorSymbol](), [MatrixSymbol]() or [ArraySymbol](), or the dimensions registered for an atomic symbol in `$Assumptions` via [Vectors](), [Matrices]() or [Arrays]() domains.
- [ArrayDimensions]() recurses structurally through the nodes of a structural tree: <code>[Transpose]()[*t*, *perm*]</code> permutes (or rotates, for an integer, or swaps, for a two-way rule) the dimensions of *t*; <code>[Plus]()</code> keeps the common leading dimensions of its terms; <code>[Inactive]()[[TensorProduct]()]</code> concatenates dimensions; [TensorContract]() and [ArrayContract]() delete the contracted pairs; [Dot]() contracts the last level of each operand with the first of the next; [ArrayDot]() drops the levels its count or its index pairs contract; [ArrayReshape]() states its result shape outright; <code>[Inactive]()[[D]()][*t*, {*params*, *n*}]</code> appends *n* copies of the parameter count.
- Every node is matched in both its active and its inactive spelling, so the two forms a lowered tensor-network contraction carries report the same shape.
- A node whose operand has no known shape gives `{}`, and an enclosing node gives `{}` in turn; no index arithmetic runs on an unknown shape.
- Non-array input, including ragged lists, quietly gives `{}`; no messages leak from the shape probe.
- A rank-0 scalar also gives `{}`.

## Basic Examples

Get the dimensions of a large sparse array without touching its elements:

```wl
ArrayDimensions[SparseArray[{{1, 2} -> 1.}, {100, 100}]]
```

<!-- => {100, 100} -->

A symbolic matrix reports its declared dimensions:

```wl
ArrayDimensions[MatrixSymbol["M", {2, 3}]]
```

<!-- => {2, 3} -->

A lazy array-valued interpolating function reports its output dimensions without evaluating:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayDimensions[f[tau]]
```

<!-- => {2} -->

## Scope

### Explicit containers

A [NumericArray]() introspects its dimensions directly:

```wl
ArrayDimensions[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => {2, 2} -->

---

A structured array such as [SymmetrizedArray]() reports its shape without densifying:

```wl
ArrayDimensions[SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]]
```

<!-- => {2, 2} -->

---

Wrapper containers introspect their shape metadata; a [QuantityArray]() of magnitudes with units:

```wl
ArrayDimensions[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"]]
```

<!-- => {2, 2} -->

---

A [Tabular]() reports rows and columns:

```wl
ArrayDimensions[Tabular[{{1., 2.}, {3., 4.}, {5., 6.}}, {"a", "b"}]]
```

<!-- => {3, 2} -->

---

A [ByteArray]() is a rank-1 container:

```wl
ArrayDimensions[ByteArray[{1, 2, 3, 255}]]
```

<!-- => {4} -->

---

An [EventSeries]() reports the dimensions of its values:

```wl
ArrayDimensions[EventSeries[{{1., 2.}, {3., 4.}, {5., 6.}}, {{0, 1, 2}}]]
```

<!-- => {3, 2} -->

---

A [DataStructure]() array store gives its length:

```wl
ArrayDimensions[CreateDataStructure["DynamicArray", {1., 2., 3.}]]
```

<!-- => {3} -->

### Lazy containers

An array-valued [Piecewise]() takes the common shape of its branch values and its default, without evaluating any condition:

```wl
pw = Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}];
ArrayDimensions[pw]
```

<!-- => {2, 2} -->

---

A source [NetGraph]() reports the dimensions of its output port, without running the net:

```wl
net = NetGraph[{NetArrayLayer["Array" -> {{1., 2., 3.}, {4., 5., 6.}}]}, {1 -> NetPort["Output"]}];
ArrayDimensions[net]
```

<!-- => {2, 3} -->

---

A fully applied [ParametricFunction]() reports the shape of one cached probe solve:

```wl
pf = ParametricNDSolveValue[{y'[t] == {{0, pa}, {-pa, 0}} . y[t], y[0] == {1., 0.}}, y, {t, 0, 1}, {pa}];
ArrayDimensions[pf[aa][tt]]
```

<!-- => {2} -->

---

The shape of an unapplied [Function]() comes from a probe that evaluates its body:

```wl
ArrayDimensions[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]]
```

<!-- => {2, 2} -->

---

An [ArrayDeclareShape]() declaration supplies the shape a probe cannot discover, and keeps the probes from running:

```wl
branchy = Function[q, If[q > 2, {1., 2.}, $Failed]];
ArrayDeclareShape[branchy, {2}];
ArrayDimensions[branchy]
```

<!-- => {2} -->

### Symbolic containers

An atomic symbol registered in `$Assumptions` gives its registered dimensions:

```wl
$Assumptions = {Element[symA, Matrices[{2, 2}]]};
ArrayDimensions[symA]
```

<!-- => {2, 2} -->

---

Symbolic dimensions pass through unevaluated:

```wl
ArrayDimensions[VectorSymbol["v", n]]
```

<!-- => {n} -->

### Structural recursion

[Transpose]() with a permutation permutes the dimensions:

```wl
ArrayDimensions[Transpose[ArraySymbol["T", {2, 3, 4}], {2, 3, 1}]]
```

<!-- => {4, 2, 3} -->

---

An integer transpose specification rotates the dimensions:

```wl
ArrayDimensions[Transpose[ArraySymbol["T", {2, 3, 4}], 2]]
```

<!-- => {3, 4, 2} -->

---

A two-way rule swaps a pair of levels:

```wl
ArrayDimensions[Transpose[ArraySymbol["T", {2, 3, 4}], 1 <-> 3]]
```

<!-- => {4, 3, 2} -->

---

A sum of symbolic arrays keeps the common dimensions:

```wl
ArrayDimensions[MatrixSymbol["A", {2, 3}] + MatrixSymbol["B", {2, 3}]]
```

<!-- => {2, 3} -->

---

An inactive tensor product concatenates the factor dimensions:

```wl
ArrayDimensions[Inactive[TensorProduct][VectorSymbol["u", 2], MatrixSymbol["N", {3, 4}]]]
```

<!-- => {2, 3, 4} -->

---

A tensor contraction deletes the contracted levels:

```wl
ArrayDimensions[TensorContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}]]
```

<!-- => {3} -->

---

An inactive gradient with respect to a parameter list appends the parameter count:

```wl
ArrayDimensions[Inactive[D][VectorSymbol["v", 3], {{p1, p2}}]]
```

<!-- => {3, 2} -->

---

A second-order derivative appends it twice:

```wl
ArrayDimensions[Inactive[D][VectorSymbol["v", 3], {{p1, p2}, 2}]]
```

<!-- => {3, 2, 2} -->

---

The same recursion answers for a deferred tree, whose leaves are explicit arrays:

```wl
tree = Inactive[TensorContract][
    Inactive[TensorProduct][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}]],
    {{2, 3}}
];
ArrayDimensions[tree]
```

<!-- => {2, 4} -->

---

An inactive [Dot]() contracts the last level of each operand with the first of the next:

```wl
ArrayDimensions[Inactive[Dot][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}]]]
```

<!-- => {2, 4} -->

---

An [ArrayDot]() with an explicit index-pair specification drops the contracted levels of both operands:

```wl
ArrayDimensions[Inactive[ArrayDot][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}], {{2, 1}}]]
```

<!-- => {2, 4} -->

---

An integer specification contracts that many trailing levels of the first operand against the same number of leading levels of the second:

```wl
ArrayDimensions[Inactive[ArrayDot][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}], 1]]
```

<!-- => {2, 4} -->

---

An [ArrayReshape]() node states its result shape outright:

```wl
ArrayDimensions[Inactive[ArrayReshape][ArrayReshape[Range[6], {2, 3}], {3, 2}]]
```

<!-- => {3, 2} -->

---

An operand of unknown shape leaves the enclosing node with no shape either:

```wl
ArrayDimensions[Inactive[TensorContract][Inactive[TensorProduct][unknownA, unknownB], {{1, 2}}]]
```

<!-- => {} -->

## Properties and Relations

A rank-3 symbolic tensor has three dimensions:

```wl
ArrayDimensions[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => {2, 3, 4} -->

---

[ArrayRank]() is the length of that list:

```wl
ArrayRank[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => 3 -->

---

A degenerate [SparseArray]() reports a dimension of 0:

```wl
ArrayDimensions[SparseArray[{}, {2, 0}]]
```

<!-- => {2, 0} -->

---

[ZeroArrayQ]() tests whether any dimension is 0:

```wl
ZeroArrayQ[SparseArray[{}, {2, 0}]]
```

<!-- => True -->

## Possible Issues

Ragged input gives `{}` quietly, with no message:

```wl
ArrayDimensions[{1, {2}}]
```

<!-- => {} -->

---

A scalar is rank 0 and also gives `{}`:

```wl
ArrayDimensions[7]
```

<!-- => {} -->

---

An [Association]() is not an admitted container, since its shape reports the entry multiset rather than the represented vector; it gives `{}`:

```wl
ArrayDimensions[<|1 -> 1.5, 2 -> 2.5|>]
```

<!-- => {} -->

---

[Dimensions]() reads the expression tree of a lazy or deferred container rather than the array it stands for; on the [Piecewise]() above it reports the argument count:

```wl
Dimensions[pw]
```

<!-- => {2} -->

[ArrayDimensions]() reports the shape of the array instead:

```wl
ArrayDimensions[pw]
```

<!-- => {2, 2} -->

---

The same holds for an unapplied [Function]():

```wl
Dimensions[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]]
```

<!-- => {2} -->

---

And for a deferred contraction tree, where [Dimensions]() counts the arguments of the outer node:

```wl
Dimensions[tree]
```

<!-- => {2} -->
