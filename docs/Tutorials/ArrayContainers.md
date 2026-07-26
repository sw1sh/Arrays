---
Template: TechNote
Name: ArrayContainers
Title: Array Containers
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/tutorial/ArrayContainers
Keywords: [array container, materialization, lazy array, symbolic array, packed array, capability flag]
RelatedGuides: [Arrays]
---

The Wolfram Language stores arrays in many different containers: plain and packed lists, [SparseArray](), [NumericArray](), structured arrays, unit-carrying and tabular wrappers, interpolating functions awaiting a parameter, and purely symbolic array objects. The Arrays paclet treats them as one family under a single admission criterion: an expression is an array container when its shape is introspectable without materializing its elements and a materialization path exists. Containers fall into three tiers: explicit (the elements are in memory), lazy (an array-valued expression awaiting parameters) and symbolic (no elements at all, only a name and a shape). This note follows one small vector through four explicit containers, works the lazy and symbolic tiers end to end, and closes with the capability-flag model that separates admission from compute-nativeness.

## One Vector, Four Containers

The same four-element vector can live in a plain list, a [SparseArray](), a [NumericArray]() and a [QuantityArray](). The plain list holds the four values directly:

```wl
containers = {{1., 0., 2., 0.}, SparseArray[{1., 0., 2., 0.}], NumericArray[{1., 0., 2., 0.}], QuantityArray[{1., 0., 2., 0.}, "Meters"]};
containers[[1]]
```

<!-- => {1., 0., 2., 0.} -->

The [SparseArray]() stores only the two nonzero values:

```wl
containers[[2]]
```

<!-- => a SparseArray summary box: rank 1, dimensions {4}, 2 stored elements -->

The [NumericArray]() stores the values in a `Real64` buffer:

```wl
containers[[3]]
```

<!-- => a NumericArray summary box: Real64, dimensions {4} -->

The [QuantityArray]() carries the same magnitudes together with a unit:

```wl
containers[[4]]
```

<!-- => a QuantityArray summary box: dimensions {4}, unit meters -->

[ArrayExplicitQ]() recognizes the plain list as an explicit-tier container:

```wl
ArrayExplicitQ[containers[[1]]]
```

<!-- => True -->

The [SparseArray]() is explicit as well:

```wl
ArrayExplicitQ[containers[[2]]]
```

<!-- => True -->

So is the [NumericArray]():

```wl
ArrayExplicitQ[containers[[3]]]
```

<!-- => True -->

And so is the unit-carrying [QuantityArray]():

```wl
ArrayExplicitQ[containers[[4]]]
```

<!-- => True -->

[ArrayDimensions]() reads the shape of the plain list:

```wl
ArrayDimensions[containers[[1]]]
```

<!-- => {4} -->

For the [SparseArray]() the shape comes from the stored dimensions, not from the elements:

```wl
ArrayDimensions[containers[[2]]]
```

<!-- => {4} -->

For the [NumericArray]() it comes from the buffer metadata:

```wl
ArrayDimensions[containers[[3]]]
```

<!-- => {4} -->

For the [QuantityArray]() it comes from the wrapper, without unwrapping the units:

```wl
ArrayDimensions[containers[[4]]]
```

<!-- => {4} -->

[ArrayMaterialize]() returns the plain list unchanged:

```wl
ArrayMaterialize[containers[[1]]]
```

<!-- => {1., 0., 2., 0.} -->

It recovers the same packed vector from the [SparseArray]():

```wl
ArrayMaterialize[containers[[2]]]
```

<!-- => {1., 0., 2., 0.} -->

And from the [NumericArray]():

```wl
ArrayMaterialize[containers[[3]]]
```

<!-- => {1., 0., 2., 0.} -->

And from the [QuantityArray](), whose magnitudes are the same four values:

```wl
ArrayMaterialize[containers[[4]]]
```

<!-- => {1., 0., 2., 0.} -->

The materialization routes are per-head: for a [QuantityArray]() the route is [QuantityMagnitude](), which returns the internal packed magnitudes without conversion, with the units recoverable from the container metadata. Applying [Normal]() instead builds an unpacked list of [Quantity]() elements, orders of magnitude slower on large arrays:

```wl
Normal[containers[[4]]]
```

<!-- => {Quantity[1., "Meters"], Quantity[0., "Meters"], Quantity[2., "Meters"], Quantity[0., "Meters"]} -->

The sparse accessors read natively off a [SparseArray](); [ArrayExplicitValues]() gives the stored values:

```wl
ArrayExplicitValues[containers[[2]]]
```

<!-- => {1., 2.} -->

[ArrayExplicitPositions]() gives the positions those values occupy:

```wl
ArrayExplicitPositions[containers[[2]]]
```

<!-- => {{1}, {3}} -->

[ArrayExplicitLength]() gives how many values are stored:

```wl
ArrayExplicitLength[containers[[2]]]
```

<!-- => 2 -->

The same accessors extend to every other explicit container through an on-demand sparse wrap; here the nonzero values of the [NumericArray]():

```wl
ArrayExplicitValues[containers[[3]]]
```

<!-- => {1., 2.} -->

## The Lazy Tier

A lazy container is an array-valued expression with at least one non-numeric argument: the shape is known from the head, but the elements come into existence only when the parameters take numeric values. The canonical example is an array-valued [InterpolatingFunction]() applied to a symbolic time.

Solve a differential equation for a vector-valued function, giving an [InterpolatingFunction]() with vector output:

```wl
sol = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 10}]
```

<!-- => InterpolatingFunction summary box: domain {{0., 10.}}, output vector of length 2 -->

Applied to a symbolic time, it stays unevaluated:

```wl
state = sol[tau]
```

<!-- => InterpolatingFunction[{{0., 10.}}, ...][tau] -->

That expression is a lazy-tier container:

```wl
ArrayLazyQ[state]
```

<!-- => True -->

The shape comes from the output dimensions of the interpolating function, without any evaluation:

```wl
ArrayDimensions[state]
```

<!-- => {2} -->

A numeric argument evaluates immediately, giving the vector of values at that time:

```wl
sol[0.5]
```

<!-- => {0.877582, -0.479425} -->

That result is an explicit container:

```wl
ArrayExplicitQ[sol[0.5]]
```

<!-- => True -->

It is not a lazy container, since nothing is left awaiting a parameter:

```wl
ArrayLazyQ[sol[0.5]]
```

<!-- => False -->

[ArrayReplaceAll]() substitutes into the whole expression at once, so supplying the time parameter evaluates the interpolating function a single time:

```wl
ArrayReplaceAll[state, tau -> 0.5]
```

<!-- => {0.877582, -0.479425} -->

[ArrayMaterialize]() instead expands the container per scalar, one interpolation of the parameter for each element:

```wl
ArrayMaterialize[state]
```

<!-- => {InterpolatingFunction[...][tau], InterpolatingFunction[...][tau]} -->

Sampling the one-shot substitution across the domain traces the trajectory of the solution:

```wl
Table[ArrayReplaceAll[state, tau -> t1], {t1, 0., 1., 0.5}]
```

<!-- => {{1., 0.}, {0.877582, -0.479425}, {0.540302, -0.841471}} -->

Structural operations keep the container lazy: an element-level [ArrayMap]() with a numeric-valued function reinterpolates the value grid instead of materializing:

```wl
chopped = ArrayMap[Chop, state]
```

<!-- => InterpolatingFunction[{{0., 10.}}, ...][tau], the reinterpolated value grid -->

The mapped result is still a lazy container:

```wl
ArrayLazyQ[chopped]
```

<!-- => True -->

## The Symbolic Tier

A symbolic container has no elements: [VectorSymbol](), [MatrixSymbol]() and [ArraySymbol]() carry a name and declared dimensions, a plain symbol becomes symbolic by registering in [$Assumptions](), and structural trees of inactive transposes, tensor products, contractions and sums over such containers are containers themselves. Shape flows through the structure.

A matrix symbol carries a name and declared dimensions, and no elements at all:

```wl
m = MatrixSymbol["M", {2, 3}]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

It belongs to the symbolic tier:

```wl
ArraySymbolicQ[m]
```

<!-- => True -->

Its shape comes from the declared dimensions:

```wl
ArrayDimensions[m]
```

<!-- => {2, 3} -->

Shape flows structurally through [Transpose](), which stays unevaluated on a symbolic container:

```wl
ArrayDimensions[Transpose[m]]
```

<!-- => {3, 2} -->

[ArrayTranspose]() composes nested transpositions into a single permutation:

```wl
composed = ArrayTranspose[Transpose[ArraySymbol["T", {2, 3, 4}], {2, 3, 1}], {2, 3, 1}]
```

<!-- => Transpose[ArraySymbol["T", {2, 3, 4}], {3, 1, 2}] -->

The composed transpose reports its permuted shape:

```wl
ArrayDimensions[composed]
```

<!-- => {3, 4, 2} -->

[ArrayPart]() slices a symbolic matrix structurally, producing a named symbolic row:

```wl
ArrayPart[m, {1}]
```

<!-- => VectorSymbol["M"[1], 3, Reals] -->

A plain symbol registered in [$Assumptions]() as a matrix is also a symbolic container:

```wl
$Assumptions = {Element[a, Matrices[{2, 2}]]};
ArraySymbolicQ[a]
```

<!-- => True -->

Its shape is read off the registered assumption:

```wl
ArrayDimensions[a]
```

<!-- => {2, 2} -->

## Capability Flags

Admission to the container family is shape-based; whether elementwise arithmetic and [Dot]() also run natively on the container without materializing is a separate per-head capability flag, [ArrayComputeNativeQ](). [SparseArray](), packed and plain lists, [QuantityArray]() and [TabularColumn]() are compute-native; [NumericArray](), structured arrays and the remaining wrapper containers ([Tabular](), [Dataset](), [ByteArray](), [EventSeries](), [DataStructure]() stores) are storage-only, as are all lazy and symbolic containers. [Association]() is not admitted: its [Dimensions]() and [Normal]() report the entry multiset rather than the represented vector, so it has neither a faithful shape nor a faithful materialization.

Of the four explicit containers above, the plain list is compute-native:

```wl
ArrayComputeNativeQ[containers[[1]]]
```

<!-- => True -->

So is the [SparseArray]():

```wl
ArrayComputeNativeQ[containers[[2]]]
```

<!-- => True -->

The [NumericArray]() is storage-only:

```wl
ArrayComputeNativeQ[containers[[3]]]
```

<!-- => False -->

The [QuantityArray]() is compute-native again:

```wl
ArrayComputeNativeQ[containers[[4]]]
```

<!-- => True -->

Operations on a storage-only container materialize first; mapping over the [NumericArray]() yields a plain packed list:

```wl
ArrayMap[2 # &, containers[[3]]]
```

<!-- => {2., 0., 4., 0.} -->

Where a native route exists, the container head is preserved; conjugation converts through [Normal]() and re-wraps the [NumericArray]():

```wl
conjugated = ArrayConjugate[containers[[3]]]
```

<!-- => a NumericArray summary box: Real64, dimensions {4} -->

Its real elements come back unchanged:

```wl
Normal[conjugated]
```

<!-- => {1., 0., 2., 0.} -->

The flag lets callers choose their route: compute in place on native containers, or materialize once and compute on the packed data. Every container, native or not, answers the classification, shape and accessor questions without materializing.
