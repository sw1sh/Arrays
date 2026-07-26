---
Template: Symbol
Name: ArrayNumberQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayNumberQ
Keywords: [inexact numbers, machine numbers, numericity test, array container]
SeeAlso: [ArrayNumericQ, ArrayAllZeroQ, ArrayExplicitQ, ArrayExplicitValues, ArrayPack, ArrayMaterialize]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayNumberQ]()[*a*]</code> gives [True]() if all elements of an explicit array container are inexact numbers.

## Details & Options

- Elements are tested with [InexactNumberQ]() semantics: machine or arbitrary-precision [Real]() and [Complex]() numbers pass; exact values (integers, rationals, exact constants such as `Pi`) give [False]().
- The exact-fails rule lets consumers that branch exact-vs-numeric keep exact input on the exact path; [ArrayNumericQ]() is the looser test that accepts exact numeric values.
- For a [SparseArray]() only the explicitly stored values are tested; the implicit value is not inspected.
- [Real]() and [Complex]() packed arrays and [NumericArray]() objects are inexact by construction; [Integer]()-typed ones give [False](), as does [ByteArray](), which is unsigned 8-bit integer typed.
- A [QuantityArray]() is judged on its magnitudes, so integer-magnitude quantity arrays stay on the exact path like any other integer container.
- [TabularColumn]() and [Tabular]() decide off their column element types (`"Real*"` or `"ComplexReal*"` pass) without traversing the data; any [Missing]() entry disqualifies the container.
- A [Dataset]() reads inexactness off its stored type signature without traversing the data.
- An [EventSeries]() materializes its values and inspects them; a [DataStructure]() store is untyped, so its elements are inspected.
- Lazy and symbolic containers give [False](), as does any other input.
- [ArrayNumberQ]() mirrors the QuantumFramework `"NumberQ"` state property it replaces.

## Basic Examples

Exact numeric values give [False]():

```wl
ArrayNumberQ[{1, Pi}]
```

<!-- => False -->

Inexact numbers give [True]():

```wl
ArrayNumberQ[{1., 2.5}]
```

<!-- => True -->

A sparse array of reals:

```wl
ArrayNumberQ[SparseArray[{1., 2.}]]
```

<!-- => True -->

## Scope

### Explicit containers

An integer packed array is exact and gives [False](); a complex packed array is inexact:

```wl
{ArrayNumberQ[Developer`ToPackedArray[{1, 2, 3}]], ArrayNumberQ[Developer`ToPackedArray[{1. + 2. I, 3. - 1. I}]]}
```

<!-- => {False, True} -->

---

[NumericArray]() decides off its type:

```wl
{ArrayNumberQ[NumericArray[{1, 2, 3}, "Integer64"]], ArrayNumberQ[NumericArray[{1., 2.}]]}
```

<!-- => {False, True} -->

---

An integer [SparseArray]() stays on the exact path:

```wl
ArrayNumberQ[SparseArray[{1, 2, 3}]]
```

<!-- => False -->

### Wrapper containers

A [QuantityArray]() follows its magnitudes:

```wl
{ArrayNumberQ[QuantityArray[{1, 2}, "Meters"]], ArrayNumberQ[QuantityArray[{1., 2.}, "Meters"]]}
```

<!-- => {False, True} -->

---

A [TabularColumn]() decides off its element type:

```wl
{ArrayNumberQ[TabularColumn[{1, 2, 3}]], ArrayNumberQ[TabularColumn[{1., 2., 3.}]]}
```

<!-- => {False, True} -->

---

A [Tabular]() requires every column to be inexact-typed:

```wl
ArrayNumberQ[Tabular[{{1, 2.}, {3, 4.}}, {"x", "y"}]]
```

<!-- => False -->

---

A [Dataset]() decides off its type signature:

```wl
{ArrayNumberQ[Dataset[{1, 2, 3}]], ArrayNumberQ[Dataset[{1., 2., 3.}]]}
```

<!-- => {False, True} -->

---

A [ByteArray]() is integer typed and never inexact:

```wl
ArrayNumberQ[ByteArray[{1, 2, 3}]]
```

<!-- => False -->

### Lazy and symbolic containers

Lazy and symbolic containers give [False]():

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
{ArrayNumberQ[f[tau]], ArrayNumberQ[MatrixSymbol["M", {2, 3}]]}
```

<!-- => {False, False} -->

## Properties and Relations

[ArrayNumberQ]() implies [ArrayNumericQ](), but not conversely:

```wl
{ArrayNumericQ[{1, 2}], ArrayNumberQ[{1, 2}], ArrayNumberQ[N[{1, 2}]]}
```

<!-- => {True, False, True} -->

## Possible Issues

For a [SparseArray]() only the explicit values are tested, so an array with inexact explicit values passes even though its implicit zeros are exact integers:

```wl
ArrayNumberQ[SparseArray[{{1, 1} -> 1.}, {2, 2}]]
```

<!-- => True -->

Materializing shows the mixed exact/inexact elements:

```wl
Normal[SparseArray[{{1, 1} -> 1.}, {2, 2}]]
```

<!-- => {{1., 0}, {0, 0}} -->
