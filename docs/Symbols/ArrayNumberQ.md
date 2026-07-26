---
Template: Symbol
Name: ArrayNumberQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayNumberQ
Keywords: [inexact numbers, machine numbers, numericity test, array container]
SeeAlso: [ArrayNumericQ, ArrayAllZeroQ, ArrayExplicitQ, ArrayExplicitValues, ArrayPack, ArrayMaterialize, ArrayElementDomain]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayNumberQ]()[*a*]</code> gives [True]() if all elements of an explicit array container are inexact numbers.

## Details & Options

- Elements are tested with [InexactNumberQ]() semantics: machine or arbitrary-precision [Real]() and [Complex]() numbers pass; exact values (integers, rationals, exact constants such as `Pi`) give [False]().
- [ArrayNumericQ]() is the looser test that accepts exact numeric values.
- For a [SparseArray]() only the explicitly stored values are tested; the implicit value is not inspected.
- [Real]() and [Complex]() packed arrays and [NumericArray]() objects are inexact by construction; [Integer]()-typed ones give [False](), as does [ByteArray](), which is unsigned 8-bit integer typed.
- A [QuantityArray]() is judged on its magnitudes, so integer-magnitude quantity arrays stay on the exact path like any other integer container.
- [TabularColumn]() and [Tabular]() decide off their column element types (`"Real*"` or `"ComplexReal*"` pass) without traversing the data; any [Missing]() entry disqualifies the container.
- A [Dataset]() reads inexactness off its stored type signature without traversing the data.
- An [EventSeries]() decides off the element type of its `"Values"` column, including the `"ListVector"` type a vector-valued series carries, and inspects the values only where that type settles nothing, as `"NumberExpression"` and `"IntegerExpression"` do not: they cover complex, rational and big-integer values alike. A [DataStructure]() store is untyped, so its elements are inspected.
- Lazy and symbolic containers give [False](), as does any other input.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - ArrayNumberQ replaces the QuantumFramework "NumberQ" state property; the exact-fails rule (InexactNumberQ semantics, exact values give False) lets consumers that branch exact-vs-numeric keep exact input on the exact path, with ArrayNumericQ as the looser exact-accepting test. -->

Exact numeric values give [False]():

```wl
ArrayNumberQ[{1, Pi}]
```

<!-- => False -->

---

Inexact numbers give [True]():

```wl
ArrayNumberQ[{1., 2.5}]
```

<!-- => True -->

---

A sparse array of reals:

```wl
ArrayNumberQ[SparseArray[{1., 2.}]]
```

<!-- => True -->

## Scope

### Explicit containers

An integer packed array is exact and gives [False]():

```wl
ArrayNumberQ[Developer`ToPackedArray[{1, 2, 3}]]
```

<!-- => False -->

---

A complex packed array is inexact by construction:

```wl
ArrayNumberQ[Developer`ToPackedArray[{1. + 2. I, 3. - 1. I}]]
```

<!-- => True -->

---

An [Integer]()-typed [NumericArray]() gives [False]():

```wl
ArrayNumberQ[NumericArray[{1, 2, 3}, "Integer64"]]
```

<!-- => False -->

---

A [Real]()-typed [NumericArray]() gives [True]():

```wl
ArrayNumberQ[NumericArray[{1., 2.}]]
```

<!-- => True -->

---

An integer [SparseArray]() stays on the exact path:

```wl
ArrayNumberQ[SparseArray[{1, 2, 3}]]
```

<!-- => False -->

### Wrapper containers

A [QuantityArray]() with integer magnitudes stays on the exact path:

```wl
ArrayNumberQ[QuantityArray[{1, 2}, "Meters"]]
```

<!-- => False -->

---

A [QuantityArray]() with real magnitudes is inexact:

```wl
ArrayNumberQ[QuantityArray[{1., 2.}, "Meters"]]
```

<!-- => True -->

---

An integer-typed [TabularColumn]() gives [False]():

```wl
ArrayNumberQ[TabularColumn[{1, 2, 3}]]
```

<!-- => False -->

---

A `"Real*"`-typed [TabularColumn]() gives [True]():

```wl
ArrayNumberQ[TabularColumn[{1., 2., 3.}]]
```

<!-- => True -->

---

A [Tabular]() requires every column to be inexact-typed:

```wl
ArrayNumberQ[Tabular[{{1, 2.}, {3, 4.}}, {"x", "y"}]]
```

<!-- => False -->

---

An integer [Dataset]() reads exactness off its type signature:

```wl
ArrayNumberQ[Dataset[{1, 2, 3}]]
```

<!-- => False -->

---

A real [Dataset]() reads inexactness off its type signature:

```wl
ArrayNumberQ[Dataset[{1., 2., 3.}]]
```

<!-- => True -->

---

A [ByteArray]() is integer typed and never inexact:

```wl
ArrayNumberQ[ByteArray[{1, 2, 3}]]
```

<!-- => False -->

### Lazy and symbolic containers

A lazy container gives [False]() without materializing:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayNumberQ[f[tau]]
```

<!-- => False -->

---

A symbolic container gives [False]():

```wl
ArrayNumberQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => False -->

## Properties and Relations

An exact integer list is numeric:

```wl
ArrayNumericQ[{1, 2}]
```

<!-- => True -->

---

The same list is not inexact, so [ArrayNumericQ]() does not imply [ArrayNumberQ]():

```wl
ArrayNumberQ[{1, 2}]
```

<!-- => False -->

---

Applying [N]() moves it onto the inexact path, where both predicates hold:

```wl
ArrayNumberQ[N[{1, 2}]]
```

<!-- => True -->

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
