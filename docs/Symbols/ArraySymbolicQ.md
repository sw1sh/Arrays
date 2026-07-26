---
Template: Symbol
Name: ArraySymbolicQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArraySymbolicQ
Keywords: [symbolic array, vector symbol, matrix symbol, assumptions, structural tree, tensor contraction, array container, predicate]
SeeAlso: [ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArrayComputeNativeQ, ArrayDimensions, ArrayMaterialize, ArrayName, SimplifyArray, ArrayTier]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArraySymbolicQ]()[*a*]</code> gives True if *a* is a symbolic array container: `VectorSymbol`, `MatrixSymbol`, `ArraySymbol`, an atomic symbol registered in `$Assumptions` as an element of `Vectors`, `Matrices` or `Arrays`, or a structural tree over array containers.

## Details & Options

- A symbolic container has a shape but no addressable elements: [ArrayDimensions]() computes the shape without evaluating anything, and the stored-value accessors give <code>Missing["NotExplicit"]</code>.
- The recognized structural nodes are <code>Inactive[D][*t*, ...]</code>, [Transpose](), <code>Inactive[TensorProduct]</code>, [Plus](), [TensorContract]() and [ArrayContract](), [Dot](), [ArrayDot]() and [ArrayReshape](). Each is matched in both its active and its inactive spelling, the two forms a lowered tensor-network contraction carries.
- A structural node is a container under either of two tests on its tensor operands: at least one operand is a symbolic container, which also carries the recursion through nested nodes; or every operand is an explicit container, which admits the deferred contraction tree that a tensor-network contraction returns unactivated.
- A deferred tree, one with no symbolic leaf anywhere, has a value and merely defers computing it: [ArrayMaterialize]() gives that value through [Activate](), and [ArrayPart]() and an element-level [ArrayMap]() go through the same materialization rather than reaching the expression tree. The leafless symbolic containers have no value, and [ArrayMaterialize]() gives the input itself.
- Only the tensor operands of a node are tested: the third argument of [ArrayDot]() is a contraction specification, and a pair list such as <code>{{3, 1}, {2, 2}}</code> would otherwise pass as a matrix.
- Recognizing a structural tree never probes the lazy tier, so it never evaluates a [Function]() leaf. A tree whose only non-explicit operand is a lazy container is not admitted; a tree that also carries a symbolic container is.
- `$Assumptions` may be a list, a single expression, or an `And` conjunction (the form `Assuming` and `Refine` produce); a single `Element` entry can register several symbols at once through `Alternatives` or a symbol list.
- A symbol with no matching `$Assumptions` entry is not a container.
- Structural operations keep the leafless symbolic containers in unevaluated or inactive form: [ArrayTranspose]() gives a `Transpose` wrapper and [ArrayContract]() a `TensorContract` wrapper.
- [ArrayName]() extracts the name of a symbolic container; [SimplifyArray]() removes trivial structural wrappers.

## Basic Examples

<!-- #| annotation: 27.07.26: Design review - deferred trees join the symbolic tier rather than getting one of their own: the tier is not "carries no values" but "has a shape and no addressable elements", and on that reading a deferred tree is a symbolic container with its leaves filled in, which is how the value-producing operations already had to answer for the inactive trees that predate any numeric leaf. Nothing in the deferred case needs a per-head registration the way the lazy tier does, since the node vocabulary is a closed set of System operations. The deferred test stops at the explicit tier deliberately: probing the lazy tier here would let mere classification of an arbitrary Inactive, Plus or Transpose expression evaluate a Function leaf at any depth. -->

A `MatrixSymbol` is a symbolic container:

```wl
ArraySymbolicQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => True -->

An atomic symbol registered in `$Assumptions` is a symbolic container:

```wl
Block[{$Assumptions = {Element[a, Matrices[{2, 2}]]}}, ArraySymbolicQ[a]]
```

<!-- => True -->

An unregistered symbol is not:

```wl
ArraySymbolicQ[symZ]
```

<!-- => False -->

---

A contraction tree over explicit matrices, the form a tensor-network contraction returns unactivated, is a container of the same tier:

```wl
tree = Inactive[TensorContract][
    Inactive[TensorProduct][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}]],
    {{2, 3}}
];
ArraySymbolicQ[tree]
```

<!-- => True -->

## Scope

### Symbolic array heads

A `VectorSymbol` is a symbolic container:

```wl
ArraySymbolicQ[VectorSymbol["v", 3]]
```

<!-- => True -->

---

A `MatrixSymbol` is a symbolic container:

```wl
ArraySymbolicQ[MatrixSymbol["M", {2, 3}]]
```

<!-- => True -->

---

An `ArraySymbol` of any rank is a symbolic container:

```wl
ArraySymbolicQ[ArraySymbol["T", {2, 3, 4}]]
```

<!-- => True -->

### Assumption-registered symbols

Registration is recognized inside an `And` conjunction, the form `Assuming` produces:

```wl
Block[{$Assumptions = Element[m, Matrices[{2, 2}]] && z > 0}, ArraySymbolicQ[m]]
```

<!-- => True -->

---

A single `Element` entry can register several symbols at once through `Alternatives`:

```wl
Block[{$Assumptions = {Element[p | q, Matrices[{3, 3}]]}}, ArraySymbolicQ[p]]
```

<!-- => True -->

---

The other symbol of the same entry is registered too, with the same declared dimensions:

```wl
Block[{$Assumptions = {Element[p | q, Matrices[{3, 3}]]}}, ArrayDimensions[q]]
```

<!-- => {3, 3} -->

### Structural trees

A `Transpose` of a symbolic container is a symbolic container:

```wl
ArraySymbolicQ[Transpose[MatrixSymbol["M", {2, 3}]]]
```

<!-- => True -->

---

A sum of symbolic containers is a symbolic container:

```wl
ArraySymbolicQ[MatrixSymbol["A", {2, 3}] + MatrixSymbol["B", {2, 3}]]
```

<!-- => True -->

---

An inactive tensor product of symbolic containers is a symbolic container:

```wl
ArraySymbolicQ[Inactive[TensorProduct][VectorSymbol["u", 2], MatrixSymbol["N", {3, 4}]]]
```

<!-- => True -->

---

A `TensorContract` of a symbolic container is a symbolic container:

```wl
ArraySymbolicQ[TensorContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}]]
```

<!-- => True -->

---

An inactive derivative of a symbolic container is a symbolic container:

```wl
ArraySymbolicQ[Inactive[D][VectorSymbol["v", 3], x]]
```

<!-- => True -->

---

One symbolic factor suffices in a mixed tree:

```wl
ArraySymbolicQ[Inactive[TensorProduct][{{1, 2}, {3, 4}}, MatrixSymbol["M", {2, 3}]]]
```

<!-- => True -->

### Deferred trees

Every leaf of the contraction tree above is an explicit container, so the tree is admitted with no symbolic operand at all:

```wl
tree
```

<!-- => Inactive[TensorContract][Inactive[TensorProduct][{{1, 2, 3}, {4, 5, 6}}, {{1, 2, 3, 4}, {5, 6, 7, 8}, {9, 10, 11, 12}}], {{2, 3}}] -->

Its shape is computed by recursing through the nodes:

```wl
ArrayDimensions[tree]
```

<!-- => {2, 4} -->

Unlike a leafless symbolic container, it has a value, and [ArrayMaterialize]() computes it:

```wl
ArrayMaterialize[tree]
```

<!-- => {{38, 44, 50, 56}, {83, 98, 113, 128}} -->

---

A [Dot]() of explicit matrices left inactive is a deferred tree as well:

```wl
ArraySymbolicQ[Inactive[Dot][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}]]]
```

<!-- => True -->

---

So is an inactive [ArrayDot]() with an explicit index-pair specification:

```wl
ArraySymbolicQ[Inactive[ArrayDot][ArrayReshape[Range[6], {2, 3}], ArrayReshape[Range[12], {3, 4}], {{2, 1}}]]
```

<!-- => True -->

---

And an inactive [ArrayReshape]():

```wl
ArraySymbolicQ[Inactive[ArrayReshape][ArrayReshape[Range[6], {2, 3}], {3, 2}]]
```

<!-- => True -->

---

An inactive [Transpose]() of an explicit matrix is a deferred tree, and materializing it performs the transposition:

```wl
ArrayMaterialize[Inactive[Transpose][ArrayReshape[Range[6], {2, 3}], {2, 1}]]
```

<!-- => {{1, 4}, {2, 5}, {3, 6}} -->

## Properties and Relations

[ArrayDimensions]() reads the declared shape, recursing through structural trees:

```wl
ArrayDimensions[TensorContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}]]
```

<!-- => {3} -->

---

[ArrayMaterialize]() of a symbolic container is the identity:

```wl
ArrayMaterialize[MatrixSymbol["M", {2, 3}]]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

## Possible Issues

A plain `List` array of symbolic scalars is an explicit-tier container, since it stores its elements:

```wl
ArrayExplicitQ[{{a1, a2}, {a3, a4}}]
```

<!-- => True -->

---

The same array is not a symbolic container:

```wl
ArraySymbolicQ[{{a1, a2}, {a3, a4}}]
```

<!-- => False -->

---

A symbolic container has no addressable elements, so the stored-value accessors decline to answer:

```wl
ArrayExplicitValues[MatrixSymbol["M", {2, 3}]]
```

<!-- => Missing["NotExplicit"] -->

---

A deferred tree shares that answer, since its elements are not computed either:

```wl
ArrayExplicitValues[tree]
```

<!-- => Missing["NotExplicit"] -->

---

A tree whose only non-explicit operand is a lazy container is not admitted, since recognizing it would evaluate that container:

```wl
probe = Function[t, {{t, 0.}, {0., t}}];
ArraySymbolicQ[Inactive[TensorProduct][probe, {{1, 2}, {3, 4}}]]
```

<!-- => False -->

The lazy leaf is a container on its own terms:

```wl
ArrayLazyQ[probe]
```

<!-- => True -->
