---
Template: Symbol
Name: ArrayAllZeroQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayAllZeroQ
Keywords: [zero array, zero test, null array, array container]
SeeAlso: [ZeroArrayQ, ArrayNumericQ, ArrayNumberQ, ArrayExplicitValues, ArrayExplicitLength, ArrayMaterialize]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayAllZeroQ]()[*a*]</code> gives [True]() if every element of an explicit array container is provably zero.

## Details & Options

- Zeros are tested with <code>[TrueQ]()[*x* == 0]</code>, so exact `0` and inexact `0.` both count, while a symbolic element that is not provably zero gives [False]().
- A [SparseArray]() is tested off its implicit value and explicitly stored values, without densifying.
- Wrapper containers test their materialized data; for a [QuantityArray]() this means zero magnitudes count as zero, matching its magnitude-based materialization.
- [ArrayAllZeroQ]() tests the values, not the shape: an array with a zero dimension has no elements and gives [True]() vacuously; use [ZeroArrayQ]() for the shape test.
- Lazy and symbolic containers give [False](), as does any other input: an all-zero interpolation is not detected without materializing.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - Sound-but-conservative predicate: zeros are tested with TrueQ[x == 0], so exact and inexact zeros count while an unproven symbolic element gives False. Lazy and symbolic containers give False rather than staying unevaluated because a Q-predicate always returns True or False; an all-zero interpolation is therefore not detected without materializing. -->

An empty sparse array is all zero without densifying:

```wl
ArrayAllZeroQ[SparseArray[{}, {2, 2}]]
```

<!-- => True -->

---

A single nonzero element gives [False]():

```wl
ArrayAllZeroQ[{{0, 1}}]
```

<!-- => False -->

---

Exact and inexact zeros both count:

```wl
ArrayAllZeroQ[{{0., 0}, {0, 0.}}]
```

<!-- => True -->

## Scope

A symbolic explicit value is not provably zero:

```wl
ArrayAllZeroQ[SparseArray[{1 -> x1}, 3]]
```

<!-- => False -->

---

A [SymmetrizedArray]() whose independent components are zero:

```wl
ArrayAllZeroQ[SymmetrizedArray[{{1, 2} -> 0.}, {2, 2}, Antisymmetric[{1, 2}]]]
```

<!-- => True -->

---

A [QuantityArray]() counts zero magnitudes as zero:

```wl
ArrayAllZeroQ[QuantityArray[{0, 0}, "Meters"]]
```

<!-- => True -->

---

A [NumericArray]() of zeros:

```wl
ArrayAllZeroQ[NumericArray[{0., 0.}]]
```

<!-- => True -->

---

A [ByteArray]() of zero bytes:

```wl
ArrayAllZeroQ[ByteArray[{0, 0}]]
```

<!-- => True -->

---

A lazy container gives [False]() without materializing:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ArrayAllZeroQ[f[tau]]
```

<!-- => False -->

---

A symbolic container gives [False]():

```wl
ArrayAllZeroQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => False -->

## Properties and Relations

[ArrayAllZeroQ]() tests the values and [ZeroArrayQ]() the shape:

```wl
{ArrayAllZeroQ[{{0, 0}, {0, 0}}], ZeroArrayQ[{{0, 0}, {0, 0}}]}
```

<!-- => {True, False} -->

---

A [SparseArray]() with zero implicit value and no explicitly stored values is all zero; [ArrayExplicitLength]() counts the stored values:

```wl
{ArrayExplicitLength[SparseArray[{}, {2, 2}]], ArrayAllZeroQ[SparseArray[{}, {2, 2}]]}
```

<!-- => {0, True} -->

## Possible Issues

The implicit value of a [SparseArray]() is tested, so a symbolic background gives [False]() even with no explicitly stored values:

```wl
ArrayAllZeroQ[SparseArray[{}, {2, 2}, x1]]
```

<!-- => False -->

---

An array with a zero dimension has no elements, so the test is vacuously [True]():

```wl
ArrayAllZeroQ[{}]
```

<!-- => True -->
