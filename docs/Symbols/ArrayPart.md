---
Template: Symbol
Name: ArrayPart
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayPart
Keywords: [part, slicing, indexing, symbolic array, array container]
SeeAlso: [ArrayTranspose, ArrayContract, ArrayDimensions, ArrayName, ArrayMaterialize, ArraySymbolicQ, ArrayContainerQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayPart]()[*a*, {$i_1$, $i_2$, ...}]</code> gives the part of the array container *a* at the given indices.

## Details & Options

- An index entry [All]() keeps the corresponding level.
- Explicit containers take parts through [Part](), so a [SparseArray]() slice stays a [SparseArray]() and a [QuantityArray]() slice keeps its wrapper.
- Symbolic containers are sliced structurally, one index at a time, with the index applied to the container's name: a [MatrixSymbol]() row becomes a [VectorSymbol]() with the indexed name, a [VectorSymbol]() element becomes a rank-0 [ArraySymbol](), and an [ArraySymbol]() slice drops the indexed level, becoming a [MatrixSymbol]() when rank 2 remains.
- A level kept with [All]() is recorded on the name as an empty application, so a column of <code>[MatrixSymbol]()["M", {2, 3}]</code> is <code>[VectorSymbol]()["M"[][2], {2}]</code>.
- For an atomic symbol registered in `$Assumptions` as an element of [Matrices]() or [Arrays](), the symbol itself is returned and its `$Assumptions` entry is re-registered in place with the sliced dimensions.
- An empty index list gives *a* itself.

## Basic Examples

Take an element of an explicit array:

```wl
ArrayPart[{{1, 2}, {3, 4}}, {1, 2}]
```

<!-- => 2 -->

---

[All]() keeps a level, here extracting a column:

```wl
ArrayPart[{{1, 2}, {3, 4}}, {All, 2}]
```

<!-- => {2, 4} -->

---

A row of a symbolic matrix is a vector symbol with the indexed name:

```wl
ArrayPart[MatrixSymbol["M", {2, 3}], {1}]
```

<!-- => VectorSymbol["M"[1], 3, Reals] -->

## Scope

### Explicit containers

A [SparseArray]() slice stays sparse:

```wl
row = ArrayPart[SparseArray[{{0, 1}, {2, 0}}], {1}]
```

<!-- => a SparseArray summary box: rank 1, dimensions {2}, 1 stored element -->

Its elements are those of the first row:

```wl
Normal[row]
```

<!-- => {0, 1} -->

---

A [QuantityArray]() slice keeps its wrapper and units:

```wl
ArrayPart[QuantityArray[{{1., 2.}, {3., 4.}}, "Meters"], {1}]
```

<!-- => QuantityArray of {1., 2.} meters -->

### Symbolic containers

A column of a symbolic matrix records the kept level as an empty application on the name:

```wl
ArrayPart[MatrixSymbol["M", {2, 3}], {All, 2}]
```

<!-- => VectorSymbol["M"[][2], 2, Reals] -->

---

An element of a symbolic vector is a rank-0 array symbol:

```wl
ArrayPart[VectorSymbol["v", 3], {2}]
```

<!-- => ArraySymbol["v"[2], {}] -->

---

A slice of a rank-3 array symbol is a matrix symbol:

```wl
ArrayPart[ArraySymbol["T", {2, 3, 4}], {1}]
```

<!-- => MatrixSymbol["T"[1], {3, 4}, Reals] -->

---

Successive indices chain on the name:

```wl
ArrayPart[MatrixSymbol["M", {2, 3}], {1, 2}]
```

<!-- => ArraySymbol["M"[1][2], {}, Reals] -->

---

An assumption-registered symbol is returned as itself, with its registered dimensions sliced in place:

```wl
$Assumptions = {Element[symA, Matrices[{2, 2}]]};
ArrayPart[symA, {1}]
```

<!-- => symA -->

The `$Assumptions` entry now registers the sliced shape:

```wl
ArrayDimensions[symA]
```

<!-- => {2} -->

## Properties and Relations

An empty index list gives the container itself:

```wl
ArrayPart[{{1, 2}, {3, 4}}, {}]
```

<!-- => {{1, 2}, {3, 4}} -->

## Possible Issues

A lazy container is not sliced: the generic [Part]() route indexes the inert expression, returning its argument rather than an array part, so materialize first with [ArrayMaterialize]():

```wl
if = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayPart[if[tau], {1}]
```

<!-- => tau -->

---

Slicing an assumption-registered symbol mutates `$Assumptions`: the symbol's registered dimensions change globally, affecting every later use of the symbol:

```wl
$Assumptions = {Element[symB, Matrices[{2, 2}]]};
ArrayPart[symB, {1}];
$Assumptions
```

<!-- => {Element[symB, Vectors[2, Complexes]]} -->
