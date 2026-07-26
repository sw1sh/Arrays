---
Template: Symbol
Name: ArraySymbolicQ
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArraySymbolicQ
Keywords: [symbolic array, vector symbol, matrix symbol, assumptions, array container, predicate]
SeeAlso: [ArrayContainerQ, ArrayExplicitQ, ArrayLazyQ, ArrayComputeNativeQ, ArrayDimensions, ArrayName, SimplifyArray]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArraySymbolicQ]()[*a*]</code> gives True if *a* is a symbolic array container: `VectorSymbol`, `MatrixSymbol`, `ArraySymbol`, an atomic symbol registered in `$Assumptions` as an element of `Vectors`, `Matrices` or `Arrays`, or a structural inactive tree of such containers.

## Details & Options

- A symbolic container has a declared shape but no addressable elements: [ArrayDimensions]() reads the declared dimensions, and the stored-value accessors give <code>Missing["NotExplicit"]</code>.
- Recognized structural trees over symbolic containers: <code>Inactive[D][*t*, …]</code>, `Transpose` and <code>Inactive[Transpose]</code>, <code>Inactive[TensorProduct]</code> with at least one symbolic factor, `Plus` with at least one symbolic term, and `TensorContract` or [ArrayContract]() in active or inactive form.
- `$Assumptions` may be a list, a single expression, or an `And` conjunction (the form `Assuming` and `Refine` produce); a single `Element` entry can register several symbols at once through `Alternatives` or a symbol list.
- A symbol with no matching `$Assumptions` entry is not a container.
- Structural operations keep symbolic containers in unevaluated or inactive form: [ArrayTranspose]() gives a `Transpose` wrapper, [ArrayContract]() a `TensorContract` wrapper, and [ArrayMaterialize]() returns the input itself.
- [ArrayName]() extracts the name of a symbolic container; [SimplifyArray]() removes trivial structural wrappers.

## Basic Examples

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

## Scope

### Symbolic array heads

All three symbolic array heads qualify:

```wl
ArraySymbolicQ /@ {VectorSymbol["v", 3], MatrixSymbol["M", {2, 3}], ArraySymbol["T", {2, 3, 4}]}
```

<!-- => {True, True, True} -->

### Assumption-registered symbols

Registration is recognized inside an `And` conjunction, the form `Assuming` produces:

```wl
Block[{$Assumptions = Element[m, Matrices[{2, 2}]] && z > 0}, ArraySymbolicQ[m]]
```

<!-- => True -->

---

A single `Element` entry can register several symbols at once through `Alternatives`:

```wl
Block[{$Assumptions = {Element[p | q, Matrices[{3, 3}]]}}, {ArraySymbolicQ[p], ArrayDimensions[q]}]
```

<!-- => {True, {3, 3}} -->

### Structural trees

Transposes, sums, inactive tensor products, contractions and inactive derivatives of symbolic containers are symbolic containers:

```wl
ArraySymbolicQ /@ {Transpose[MatrixSymbol["M", {2, 3}]], MatrixSymbol["A", {2, 3}] + MatrixSymbol["B", {2, 3}], Inactive[TensorProduct][VectorSymbol["u", 2], MatrixSymbol["N", {3, 4}]], TensorContract[ArraySymbol["S", {2, 3, 2}], {{1, 3}}], Inactive[D][VectorSymbol["v", 3], x]}
```

<!-- => {True, True, True, True, True} -->

---

One symbolic factor suffices in a mixed tree:

```wl
ArraySymbolicQ[Inactive[TensorProduct][{{1, 2}, {3, 4}}, MatrixSymbol["M", {2, 3}]]]
```

<!-- => True -->

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

---

A symbolic container has no explicitly stored values:

```wl
ArrayExplicitValues[MatrixSymbol["M", {2, 3}]]
```

<!-- => Missing["NotExplicit"] -->

## Possible Issues

A plain `List` array of symbolic scalars is an explicit-tier container, not a symbolic one:

```wl
Through[{ArrayExplicitQ, ArraySymbolicQ}[{{a1, a2}, {a3, a4}}]]
```

<!-- => {True, False} -->
