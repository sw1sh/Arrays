---
Template: Symbol
Name: ArrayNumericQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayNumericQ
Keywords: [numeric array, numericity test, element type, array container]
SeeAlso: [ArrayNumberQ, ArrayAllZeroQ, ArrayExplicitQ, ArrayExplicitValues, ArrayContainerQ, ArrayMaterialize, ArrayPack]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayNumericQ]()[*a*]</code> gives [True]() if all elements of an explicit array container are numeric.

## Details & Options

- Elements are tested with [NumericQ]() semantics: exact numeric constants such as `Pi` or `Sqrt[2]` count as numeric; use [ArrayNumberQ]() to require inexact numbers.
- For a [SparseArray]() only the explicitly stored values are tested; the implicit value is not inspected.
- Packed arrays, [NumericArray]() and [ByteArray]() are numeric by construction; a [QuantityArray]() is numeric-with-units by construction.
- [TabularColumn]() and [Tabular]() decide off their column element types (`"Integer*"`, `"UnsignedInteger*"`, `"Real*"`, `"ComplexReal*"`) without traversing the data; any [Missing]() entry disqualifies the container.
- A [Dataset]() reads numericity and shape off its stored type signature in one call, without traversing the data.
- An [EventSeries]() decides off the element type of its `"Values"` column, including the `"ListVector"` type a vector-valued series carries, and inspects the values only where that type settles nothing, as `"NumberExpression"` and `"IntegerExpression"` do not: they cover complex, rational and big-integer values alike. A [DataStructure]() store is untyped, so its elements are inspected.
- Lazy and symbolic containers give [False](); a lazy head applied to all-numeric arguments is an explicit array and is tested elementwise.
- Any other input gives [False]().

## Basic Examples

A numeric sparse matrix:

```wl
ArrayNumericQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => True -->

Exact constants count as numeric:

```wl
ArrayNumericQ[{1, Pi}]
```

<!-- => True -->

A symbolic element disqualifies the array:

```wl
ArrayNumericQ[{1, x1}]
```

<!-- => False -->

## Scope

### Explicit containers

A [NumericArray]() is numeric by construction:

```wl
ArrayNumericQ[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => True -->

---

A [SparseArray]() tests its explicitly stored values:

```wl
ArrayNumericQ[SparseArray[{1 -> x1}, 3]]
```

<!-- => False -->

---

A structured array such as [SymmetrizedArray]() is tested elementwise:

```wl
ArrayNumericQ[SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]]
```

<!-- => True -->

### Wrapper containers

A [QuantityArray]() is numeric-with-units by construction:

```wl
ArrayNumericQ[QuantityArray[{1., 2., 3.}, "Meters"]]
```

<!-- => True -->

---

A string-typed [TabularColumn]() is not numeric:

```wl
ArrayNumericQ[TabularColumn[{"a", "b"}]]
```

<!-- => False -->

---

A [Missing]() entry disqualifies an otherwise numeric column:

```wl
ArrayNumericQ[TabularColumn[{1., Missing[], 3.}]]
```

<!-- => False -->

---

A [Tabular]() with a missing entry in any column is disqualified, off its structure metadata alone:

```wl
ArrayNumericQ[Tabular[{{1, Missing["bad"]}, {2, 3.5}}, {"x", "y"}]]
```

<!-- => False -->

---

A [Dataset]() decides off its type signature:

```wl
ArrayNumericQ[Dataset[{{1., 2.}, {3., 4.}}]]
```

<!-- => True -->

---

A [ByteArray]() is numeric by construction:

```wl
ArrayNumericQ[ByteArray[{1, 2, 3, 255}]]
```

<!-- => True -->

---

A [DataStructure]() array store inspects its elements:

```wl
ArrayNumericQ[CreateDataStructure["DynamicArray", {1., 2., 3.}]]
```

<!-- => True -->

### Lazy and symbolic containers

A lazy container with a symbolic parameter gives [False]():

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayNumericQ[f[tau]]
```

<!-- => False -->

---

Applied to a numeric argument, the same head is an explicit array and tests numeric:

```wl
ArrayNumericQ[f[0.5]]
```

<!-- => True -->

---

Symbolic containers give [False]():

```wl
ArrayNumericQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => False -->

## Properties and Relations

An exact integer array is numeric:

```wl
ArrayNumericQ[{1, 2}]
```

<!-- => True -->

---

[ArrayNumberQ]() is stricter, requiring inexact numbers, so the same array is not a number array:

```wl
ArrayNumberQ[{1, 2}]
```

<!-- => False -->

## Possible Issues

For a [SparseArray]() only the explicit values are tested, so a symbolic implicit value goes unnoticed:

```wl
ArrayNumericQ[SparseArray[{}, {2, 2}, x1]]
```

<!-- => True -->

Materializing shows the array is entirely symbolic; use [ArrayAllZeroQ]() or [ArrayMaterialize]() when the implicit value matters:

```wl
ArrayMaterialize[SparseArray[{}, {2, 2}, x1]]
```

<!-- => {{x1, x1}, {x1, x1}} -->
