---
Template: Paclet
ResourceType: Paclet
Name: Wolfram/Arrays
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
Description: Domain-neutral array container utilities over explicit, lazy, and symbolic array tiers
ContributedBy: Nikolay Murzin
Keywords: [array container, sparse array, packed array, numeric array, symbolic array, lazy array, tensor, shape introspection, materialization]
MainGuide: Documentation/English/Guides/Arrays.nb
License: MIT
WolframVersion: 14.1+
Categories: [Core Language & Structure, Data Manipulation & Analysis]
SourceControlURL: https://github.com/sw1sh/Arrays
---

## Usage

The Arrays paclet is a domain-neutral abstraction over the array containers of the Wolfram Language: one dispatch layer for classifying, introspecting and operating on an array regardless of how it is stored. An expression is admitted as a container when its shape is introspectable without materializing its elements and a materialization path exists. Containers fall into three tiers. Explicit containers hold their elements in memory: [SparseArray](), packed and plain [List]() arrays, [NumericArray](), structured arrays such as [SymmetrizedArray](), and the shape-introspectable wrappers [QuantityArray](), [TabularColumn](), [Tabular](), [Dataset](), [ByteArray](), [EventSeries]() and [DataStructure]() array stores. Lazy parametric containers are array-valued inert applications awaiting their parameters, admitted through a registry of heads: an array-valued [InterpolatingFunction](), a [ParametricFunction](), an unapplied [Function](), an array-valued [Piecewise](). Symbolic containers have no elements at all: [VectorSymbol](), [MatrixSymbol]() and [ArraySymbol](), symbols registered in [$Assumptions](), and inactive tensor trees over them. Whether a container also computes in place, without materializing, is a per-head capability rather than a requirement for admission.

- <code>[ArrayContainerQ]()</code>, <code>[ArrayExplicitQ]()</code>, <code>[ArrayLazyQ]()</code>, <code>[ArraySymbolicQ]()</code>, <code>[ArrayComputeNativeQ]()</code> classify a container by tier and capability
- <code>[ArrayDimensions]()</code>, <code>[ArrayRank]()</code>, <code>[ZeroArrayQ]()</code>, <code>[ArrayNumericQ]()</code>, <code>[ArrayNumberQ]()</code>, <code>[ArrayAllZeroQ]()</code> read shape and element properties
- <code>[ArrayExplicitValues]()</code>, <code>[ArrayExplicitPositions]()</code>, <code>[ArrayExplicitLength]()</code>, <code>[ArrayMaterialize]()</code>, <code>[ArrayPack]()</code> reach the stored values and materialize
- <code>[ArrayTranspose]()</code>, <code>[ArrayContract]()</code>, <code>[ArrayPart]()</code>, <code>[ArrayConjugate]()</code>, <code>[ArrayVector]()</code>, <code>[ReshapeArray]()</code>, <code>[PadArray]()</code>, <code>[SimplifyArray]()</code>, <code>[ArrayName]()</code> operate structurally
- <code>[ArrayMap]()</code>, <code>[ArrayReplaceAll]()</code> apply functions and rules to a container
- <code>[ArrayObject]()</code>, <code>[ArrayObjectQ]()</code> wrap a container in a self-describing handle

## Details & Options

- Every container of every tier answers [ArrayDimensions]() and [ArrayRank]() without materializing, and has an [ArrayMaterialize]() route.
- [ArrayContainerQ]() is the top-level admission predicate, equivalent to <code>[ArrayExplicitQ]()[*a*] || [ArrayLazyQ]()[*a*] || [ArraySymbolicQ]()[*a*]</code>.
- [ArrayComputeNativeQ]() is the capability flag, not an admission gate. [SparseArray](), packed and plain lists, [QuantityArray]() and [TabularColumn]() are compute-native; [NumericArray](), structured arrays and the remaining wrapper containers are storage-only, as are all lazy and symbolic containers.
- A storage-only container is materialized before compute and re-wrapped in its own head where a reconstruction path exists.
- Structural operations keep a lazy container lazy, and slice a symbolic container structurally: [ArrayPart]() of a [MatrixSymbol]() is a named [VectorSymbol]().
- [ArrayReplaceAll]() substitutes into a lazy container as a whole, evaluating it a single time, where [ArrayMaterialize]() expands it into one inert application per element.
- [ArrayObject]() is a handle around any supported container, formatted as a summary box. Every function takes a handle wherever it takes a container, and gives back a raw container rather than another handle.
- [Association]() is not admitted: its [Dimensions]() and [Normal]() report the entry multiset rather than the represented vector, so it has neither a faithful shape nor a faithful materialization.

## Basic Examples

A sparse matrix is an explicit-tier container:

```wl
ArrayExplicitQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => True -->

Its shape comes from the stored dimensions, not from the elements:

```wl
ArrayDimensions[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => {2, 2} -->

---

A unit-carrying wrapper is an explicit container as well:

```wl
ArrayExplicitQ[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"]]
```

<!-- => True -->

Its shape is read from the wrapper, without unwrapping the units:

```wl
ArrayDimensions[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"]]
```

<!-- => {2, 2} -->

A [NumericArray]() is admitted on the same shape criterion, but is storage-only rather than compute-native:

```wl
ArrayComputeNativeQ[NumericArray[{1., 2.}]]
```

<!-- => False -->

---

An array symbol carries a name and declared dimensions and no elements:

```wl
ArraySymbol["T", {2, 3, 4}]
```

<!-- => ArraySymbol["T", {2, 3, 4}] -->

It belongs to the symbolic tier:

```wl
ArraySymbolicQ[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => True -->

Shape flows structurally through an unevaluated [Transpose]():

```wl
ArrayDimensions[Transpose[MatrixSymbol["M", {2, 3}]]]
```

<!-- => {3, 2} -->

---

Solving a differential equation for a vector-valued function gives an array-valued [InterpolatingFunction]():

```wl
sol = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 10}]
```

<!-- => InterpolatingFunction summary box: domain {{0., 10.}}, output vector of length 2 -->

Applied to a symbolic time it stays unevaluated, awaiting its parameter:

```wl
state = sol[tau]
```

<!-- => InterpolatingFunction[{{0., 10.}}, ...][tau] -->

That expression is a lazy-tier container:

```wl
ArrayLazyQ[state]
```

<!-- => True -->

Its shape comes from the output dimensions of the interpolating function, with nothing evaluated:

```wl
ArrayDimensions[state]
```

<!-- => {2} -->

Supplying the parameter substitutes into the container as a whole, evaluating the interpolation a single time:

```wl
ArrayReplaceAll[state, tau -> 0.5]
```

<!-- => {0.877582, -0.479425} -->

---

A handle around a container is formatted as a summary box showing its kind and dimensions:

```wl
ArrayObject[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => ArrayObject summary box: kind NumericArray, dimensions {2, 2} -->

The box of a lazy container is drawn without evaluating the interpolation:

```wl
ArrayObject[state]
```

<!-- => ArrayObject summary box: kind InterpolatingFunction, dimensions {2} -->

## Hero Image

```wl
MatrixPlot[SparseArray[Nest[KroneckerProduct[{{1, 1}, {1, 0}}, #] &, {{1, 1}, {1, 0}}, 4]], ImageSize -> 480]
```

## Author Notes

This paclet was developed with the assistance of Claude (Anthropic). The kernel sources, the test suite, and the literate-markdown documentation sources under `docs` from which the reference pages, the guide, the tech note and this definition notebook are built are model-generated; they were supervised, reviewed and hand-edited by Nikolay Murzin, who is responsible for the result.
