---
Template: Symbol
Name: ArrayMaterialize
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayMaterialize
Keywords: [materialize, normal form, wrapper container, quantity magnitude, lazy expansion, deferred tree]
SeeAlso: [ArrayPack, ArrayExplicitValues, ArrayExplicitQ, ArrayLazyQ, ArraySymbolicQ, ArrayComputeNativeQ, ArrayReplaceAll, ArrayDeclareShape, ArrayObject, ArrayCoerce]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayMaterialize]()[*a*]</code> gives an explicit array of scalar expressions for any array container: [Normal]() for explicit containers with wrapper-specific routes, per-scalar expansion for lazy containers, and the input itself for symbolic containers.

## Details & Options

- Explicit containers such as [SparseArray](), [NumericArray]() and structured arrays materialize via [Normal]().
- A [QuantityArray]() materializes via [QuantityMagnitude](), giving its packed magnitudes rather than the array of [Quantity]() expressions that [Normal]() builds. Units are container metadata, recoverable for a rebuild from <code>*a*["UnitBlock"]</code>.
- A named [Tabular]() materializes per column: each column materializes via [Normal]() to a packed vector and the columns recombine by [Transpose](). An anonymous all-numeric [Tabular]() converts to a packed matrix via [Normal]().
- An [EventSeries]() materializes as [Normal]() of its `"Values"` column. The time index is separate metadata, recoverable for a rebuild from <code>*a*["Times"]</code>.
- A [DataStructure]() array store (`"DynamicArray"` or `"FixedArray"`) materializes as an immediate packed snapshot of its elements: the handles have reference semantics, with copies aliasing the same store, so the snapshot is immune to later mutation of the source handle.
- A lazy array-valued [InterpolatingFunction]() application expands per scalar: each component becomes its own scalar interpolating function applied to the parameter.
- An array-valued [Piecewise]() threads its branch structure through every position, giving an array of scalar [Piecewise]() expressions that carry the same conditions.
- An unapplied [Function]() gives an array of scalar [Function]() expressions of the same parameters: the container is unapplied, so its elements are unapplied too. Where the body is an explicit array of the container shape the body is mapped over; where it is not, as for a shape declared with [ArrayDeclareShape](), each element wraps an [Indexed]() of the body instead.
- A source [NetGraph]() or [NetChain]() materializes as <code>*net*[]</code>, the one call that evaluates it.
- A lazy head with no per-scalar form, such as a [ParametricFunction](), expands through [Indexed](): every element is a scalar expression that substitutes to the right value, at the cost of one whole-array evaluation per element instead of one for the array.
- A deferred structural tree, one whose leaves are all explicit containers, materializes through [Activate](), which is the computation it defers.
- A leafless symbolic container has no elements to materialize and gives the input itself.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - QuantityArray routes through QuantityMagnitude rather than Normal because Normal builds an unpacked array of Quantity expressions, orders of magnitude slower than handing back the internal packed magnitudes essentially for free; a named Tabular goes per column because Normal on it yields row Associations; EventSeries reads Normal of its "Values" column because the raw "Values" property returns a TabularColumn-backed view rather than a plain list. A deferred tree is activated rather than handed back unchanged: returning the tree would make this the one tier whose materialization ArrayExplicitQ rejects, and would leave every materialize-then-operate fallback with nothing to fall back to. The Indexed expansion is the honest answer for a lazy head with no per-scalar form, trading one whole-array evaluation per element for correctness under substitution. -->

Materialize a sparse matrix:

```wl
ArrayMaterialize[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => {{0, 1}, {2, 0}} -->

---

A [QuantityArray]() materializes its packed magnitudes:

```wl
ArrayMaterialize[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"]]
```

<!-- => {{1., 2.}, {3., 4.}} -->

---

A symbolic container materializes to itself:

```wl
ArrayMaterialize[MatrixSymbol["M", {2, 3}]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

## Scope

A [NumericArray]() materializes via [Normal]():

```wl
ArrayMaterialize[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => {{1., 0.}, {0., 2.}} -->

---

A structured array expands to its full element grid:

```wl
ArrayMaterialize[SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]]
```

<!-- => {{0, 3.}, {-3., 0}} -->

---

A named [Tabular]() materializes to a matrix on the per-column route:

```wl
ArrayMaterialize[Tabular[{{1., 2.}, {3., 4.}, {5., 6.}}, {"a", "b"}]]
```

<!-- => {{1., 2.}, {3., 4.}, {5., 6.}} -->

---

An [EventSeries]() materializes its values, dropping the time index:

```wl
ArrayMaterialize[EventSeries[{{1., 2.}, {3., 4.}, {5., 6.}}, {{0, 1, 2}}]]
```

<!-- => {{1., 2.}, {3., 4.}, {5., 6.}} -->

---

A [ByteArray]() materializes to an integer vector:

```wl
ArrayMaterialize[ByteArray[{1, 2, 3, 255}]]
```

<!-- => {1, 2, 3, 255} -->

---

A [DataStructure]() array store materializes as a packed snapshot of its elements:

```wl
ds = CreateDataStructure["DynamicArray", {1., 2., 3.}];
ArrayMaterialize[ds]
```

<!-- => {1., 2., 3.} -->

---

An array-valued interpolating function applied to a symbolic parameter is a lazy container:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}]
```

<!-- => InterpolatingFunction[{{0., 1.}}, "<>"] summary box -->

It materializes per scalar, each component becoming its own scalar interpolation applied to the parameter:

```wl
expansion = ArrayMaterialize[f[tau]]
```

<!-- => {InterpolatingFunction[{{0., 1.}}, <>][tau], InterpolatingFunction[{{0., 1.}}, <>][tau]} -->

Substituting the parameter evaluates the per-scalar interpolations:

```wl
expansion /. tau -> 0.5
```

<!-- => {0.8775811345067771, -0.47942470176036955} -->

The original application at that parameter value gives those values back to interpolation accuracy:

```wl
f[0.5]
```

<!-- => {0.8775824340095093, -0.479425447892118} -->

---

An array-valued [Piecewise]() expands to an array of scalar [Piecewise]() expressions carrying the same condition:

```wl
ArrayMaterialize[Piecewise[{{{{1., 2.}, {3., 4.}}, zz < 0}}, {{5., 6.}, {7., 8.}}]]
```

<!-- => {{Piecewise[{{1., zz < 0}}, 5.], Piecewise[{{2., zz < 0}}, 6.]}, {Piecewise[{{3., zz < 0}}, 7.], Piecewise[{{4., zz < 0}}, 8.]}} -->

---

An unapplied [Function]() expands to an array of scalar [Function]() expressions of the same parameter:

```wl
ArrayMaterialize[Function[th, {{Cos[th], -Sin[th]}, {Sin[th], Cos[th]}}]]
```

<!-- => {{Function[th, Cos[th]], Function[th, -Sin[th]]}, {Function[th, Sin[th]], Function[th, Cos[th]]}} -->

---

Where the body is not an explicit array of the container shape, as for a shape declared with [ArrayDeclareShape](), each element indexes the body instead:

```wl
branchy = Function[q, If[q > 2, {1., 2.}, $Failed]];
ArrayDeclareShape[branchy, {2}];
ArrayMaterialize[branchy]
```

<!-- => {Function[q, Indexed[If[q > 2, {1., 2.}, $Failed], {1}]], Function[q, Indexed[If[q > 2, {1., 2.}, $Failed], {2}]]} -->

---

A source [NetGraph]() materializes by evaluating the net:

```wl
ArrayMaterialize[NetGraph[{NetArrayLayer["Array" -> {{1., 2., 3.}, {4., 5., 6.}}]}, {1 -> NetPort["Output"]}]]
```

<!-- => {{1., 2., 3.}, {4., 5., 6.}} -->

---

A deferred contraction tree over explicit matrices materializes to the value it defers:

```wl
tree = Inactive[TensorContract][
    Inactive[TensorProduct][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}]],
    {{2, 3}}
];
ArrayMaterialize[tree]
```

<!-- => {{38, 44, 50, 56}, {83, 98, 113, 128}} -->

## Properties and Relations

The `"UnitBlock"` metadata rebuilds a [QuantityArray]() around transformed magnitudes:

```wl
With[{qa = QuantityArray[{{1., 2.}, {3., 4.}}, "Seconds"]},
    QuantityMagnitude[QuantityArray[2 ArrayMaterialize[qa], qa["UnitBlock"]]]
]
```

<!-- => {{2., 4.}, {6., 8.}} -->

---

[Activate]() is the computation a deferred tree defers, and gives the array [ArrayMaterialize]() gives:

```wl
Activate[tree]
```

<!-- => {{38, 44, 50, 56}, {83, 98, 113, 128}} -->

---

A leafless symbolic tree has no value to compute, so it materializes to itself:

```wl
ArrayMaterialize[Inactive[TensorProduct][MatrixSymbol["A", {2, 3}], MatrixSymbol["B", {3, 4}]]]
```

<!-- => Inactive[TensorProduct][MatrixSymbol["A", {2, 3}], MatrixSymbol["B", {3, 4}]] -->

---

[ArrayPack]() packs the materialized data of a wrapper container:

```wl
ArrayPack[QuantityArray[{1, 2, 3}, "Meters"]]
```

<!-- => {1, 2, 3} (packed) -->

## Possible Issues

[Normal]() on a [QuantityArray]() builds an unpacked array of [Quantity]() expressions, not the magnitudes [ArrayMaterialize]() returns:

```wl
Normal[QuantityArray[{1., 2.}, "Meters"]]
```

<!-- => {Quantity[1., "Meters"], Quantity[2., "Meters"]} -->

---

[Normal]() on a named [Tabular]() gives a list of row associations, not a matrix:

```wl
Normal[Tabular[{{1., 2.}, {3., 4.}}, {"a", "b"}]]
```

<!-- => {<|"a" -> 1., "b" -> 2.|>, <|"a" -> 3., "b" -> 4.|>} -->

---

[DataStructure]() handles alias the same store, but the materialized snapshot is decoupled: mutating the source afterwards leaves the snapshot untouched:

```wl
store = CreateDataStructure["DynamicArray", {1., 2., 3.}];
snapshot = ArrayMaterialize[store];
store["Append", 4.];
snapshot
```

<!-- => {1., 2., 3.} -->

The store itself carries the appended element:

```wl
store["Elements"]
```

<!-- => {1., 2., 3., 4.} -->
