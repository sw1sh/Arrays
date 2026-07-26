---
Template: Symbol
Name: ZeroArrayQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ZeroArrayQ
Keywords: [empty array, zero dimension, degenerate shape, array container]
SeeAlso: [ArrayDimensions, ArrayRank, ArrayAllZeroQ, ArrayContainerQ, ArrayExplicitLength, ReshapeArray]
RelatedGuides: [Arrays]
---

## Usage

<code>[ZeroArrayQ]()[*a*]</code> gives [True]() if any dimension of *a* is 0.

## Details & Options

- [ZeroArrayQ]() is a pure shape test: it checks whether 0 occurs in <code>[ArrayDimensions]()[*a*]</code> and never materializes the container.
- It works on containers of any tier, including the structural shape recursion of symbolic trees.
- A zero dimension marks a degenerate array with no elements; structural operations such as [ArrayTranspose]() and [ArrayContract]() short-circuit such containers to `{}`.
- [ZeroArrayQ]() tests the shape, not the values: an array whose elements are all zero but whose dimensions are positive gives [False](); use [ArrayAllZeroQ]() for the value test.
- Non-array input gives [False](), since its dimensions are `{}`.

## Basic Examples

An array with a zero dimension:

```wl
ZeroArrayQ[ConstantArray[1, {2, 0}]]
```

<!-- => True -->

A sparse matrix with positive dimensions is not a zero array, whatever its values:

```wl
ZeroArrayQ[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => False -->

The empty list has dimensions `{0}`:

```wl
ZeroArrayQ[{}]
```

<!-- => True -->

## Scope

A nested empty list has dimensions `{1, 0}`:

```wl
ZeroArrayQ[{{}}]
```

<!-- => True -->

---

A [SparseArray]() with a zero dimension is detected off its shape metadata:

```wl
ZeroArrayQ[SparseArray[{}, {2, 0}]]
```

<!-- => True -->

---

A symbolic container with positive declared dimensions gives [False]():

```wl
ZeroArrayQ[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => False -->

---

A lazy container reports off its output dimensions:

```wl
f = NDSolveValue[{v'[t] == {{0, 1}, {-1, 0}} . v[t], v[0] == {1., 0.}}, v, {t, 0, 1}];
ZeroArrayQ[f[tau]]
```

<!-- => False -->

## Properties and Relations

A nested empty list has a zero among its dimensions:

```wl
ArrayDimensions[{{}}]
```

<!-- => {1, 0} -->

---

[ZeroArrayQ]() is equivalent to membership of 0 in [ArrayDimensions]():

```wl
MemberQ[ArrayDimensions[{{}}], 0]
```

<!-- => True -->

---

[ZeroArrayQ]() tests the shape, so an all-zero matrix with positive dimensions gives [False]():

```wl
ZeroArrayQ[{{0, 0}, {0, 0}}]
```

<!-- => False -->

---

[ArrayAllZeroQ]() tests the values of the same matrix:

```wl
ArrayAllZeroQ[{{0, 0}, {0, 0}}]
```

<!-- => True -->

## Possible Issues

A scalar gives [False]() rather than staying unevaluated:

```wl
ZeroArrayQ[5]
```

<!-- => False -->

---

Any other non-array input gives [False]() as well:

```wl
ZeroArrayQ["junk"]
```

<!-- => False -->
