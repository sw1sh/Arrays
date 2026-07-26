---
Template: Symbol
Name: SimplifyArray
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/SimplifyArray
Keywords: [structural simplification, tensor contraction, tensor product, transpose, inactive expressions, symbolic arrays]
SeeAlso: [ArrayTranspose, ArrayContract, ArrayName, ArraySymbolicQ, ArrayMap, ArrayReplaceAll]
RelatedGuides: [Arrays]
---

## Usage

<code>[SimplifyArray]()[*a*]</code> removes trivial structural wrappers from a symbolic array expression.

## Details & Options

- The trivial wrappers removed are an empty contraction <code>[ArrayContract]()[*t*, {}]</code> or <code>[TensorContract]()[*t*, {}]</code>, a singleton tensor product <code>[TensorProduct]()[*t*]</code>, and an identity transpose <code>[Transpose]()[*t*, {}]</code> or <code>[Transpose]()[*t*, [Cycles]()[{}]]</code>.
- Both active and [Inactive]() forms of these wrappers are recognized.
- A nontrivial [TensorContract]() keeps its contraction and simplifies the expression inside.
- Any other input is returned unchanged.
- [ArrayTranspose]() and [ArrayContract]() apply [SimplifyArray]() to their results automatically.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - Structural-only simplifier: it removes exactly the trivial wrappers (empty contraction, singleton tensor product, identity transpose), in active and Inactive form, and returns anything else unchanged, so ArrayTranspose and ArrayContract can apply it to their results automatically without risk of rewriting nontrivial structure. -->

Remove an identity transpose:

```wl
SimplifyArray[Inactive[Transpose][MatrixSymbol["M", {2, 3}], {}]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

---

Remove a singleton tensor product:

```wl
SimplifyArray[Inactive[TensorProduct][MatrixSymbol["M", {2, 3}]]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

## Scope

An empty [ArrayContract]() is removed:

```wl
SimplifyArray[Inactive[ArrayContract][MatrixSymbol["M", {2, 3}], {}]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

---

An empty [TensorContract]() is removed:

```wl
SimplifyArray[Inactive[TensorContract][MatrixSymbol["M", {2, 3}], {}]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

---

An identity transpose given as an empty [Cycles]() permutation is removed:

```wl
SimplifyArray[Inactive[Transpose][MatrixSymbol["M", {2, 3}], Cycles[{}]]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

---

A nontrivial contraction is kept while the expression inside simplifies:

```wl
SimplifyArray[TensorContract[Inactive[TensorProduct][MatrixSymbol["A", {2, 2}]], {{1, 2}}]]
```

<!-- => TensorContract[MatrixSymbol["A", {2, 2}], {{1, 2}}] -->

---

Input without a trivial wrapper is returned unchanged:

```wl
SimplifyArray[{1, 2, 3}]
```

<!-- => {1, 2, 3} -->

## Properties and Relations

[ArrayContract]() simplifies its result automatically, so an empty contraction returns the container itself:

```wl
ArrayContract[MatrixSymbol["A", {2, 2}], {}]
```

<!-- => MatrixSymbol["A", {2, 2}] -->

---

[ArrayTranspose]() does too, so an identity permutation returns the container itself:

```wl
ArrayTranspose[MatrixSymbol["M", {2, 3}], Cycles[{}]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->
