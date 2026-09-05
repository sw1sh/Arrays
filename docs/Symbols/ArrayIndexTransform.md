---
Template: Symbol
Name: ArrayIndexTransform
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayIndexTransform
Keywords: [index notation, rearrange, reshape, transpose, broadcast, unit axis, container preservation]
SeeAlso: [ArrayIndexContract, ArrayIndexPattern, ArrayIndexPlan, ReshapeArray, ArrayTranspose, ArrayDimensions, ArrayMaterialize]
RelatedGuides: [Arrays]
RelatedTutorials: [IndexNotation]
---

## Usage

<code>[ArrayIndexTransform]()[*desc*, *array*]</code> rearranges the array container *array* according to the index descriptor *desc*.

<code>[ArrayIndexTransform]()[*desc*, *array*, *bindings*]</code> takes axis sizes out of band from a list of rules.

<code>[ArrayIndexTransform]()[*plan*, *array*]</code> executes a prepared [ArrayIndexPlan]().

## Details & Options

- A rearrangement is one input shape to one output shape, over the axes it keeps: each shape is a list of axis terms, and the descriptor names where every axis of the input goes.
- *desc* is a descriptor in the classic einsum dialect (`"ij->ji"`), in the einx identifier dialect (`"(i j) -> i j"`), or in the Wolfram list-of-shapes dialect (`{{i_, j_}} :> {{j, i}}`), and an [ArrayIndexPattern]() or an [ArrayIndexPlan]() may stand in its place; [ArrayIndexPattern]() compiles it and owns the tokenizing rules and the axis spellings.
- A composite on the input side splits its dimension into its factors, the leftmost factor outermost; a composite on the output side merges its factors back into one dimension.
- A literal `1` is a unit axis: it is squeezed on the input side and inserted on the output side.
- An axis present only on the output side is repeated to the size a binding rule or an inline [Annotation]() gives it; the binding keys are [ArrayIndexPattern]()'s.
- With no output shape given the descriptor is shape-preserving: `"DefaultOutput"` here is `"Identity"`, where a contraction infers the output from the axes occurring exactly once. See [ArrayIndexPattern]().
- A prepared object carries the `"DefaultOutput"` its own construction resolved, and `"Identity"` is the default of [ArrayIndexTransform]() alone, so an arrowless descriptor prepared by [ArrayIndexPattern]() or [ArrayIndexPlan]() is rearranged by the contracted reading rather than by the identity one.
- The steps emitted are one reshape that splits composites and squeezes unit axes, one broadcast for the repeated axes, one transpose into the output order, and one reshape that merges composites and inserts unit axes, each only where it is not the identity, so a pure permutation is a single [ArrayTranspose]() and a pure split a single [ReshapeArray](). [ArrayIndexPlan]() reports the steps a descriptor emits.
- A bare array is the operand; a one-element list whose element has the rank the input shape names is the wrapped spelling of the same operand.
- The steps keep the container they are handed. A [SparseArray]() and a packed array come back as themselves, and a [QuantityArray]() comes back a [QuantityArray]() in its own unit, the steps running on its magnitudes. A [NumericArray](), a [TabularColumn](), a [Tabular](), a [Dataset](), an [EventSeries]() and a [ByteArray]() are materialized first and come back as plain arrays, and an [ArrayObject]() is unwrapped at the door and comes back as the bare container it holds; [ArrayIndexContract]() states the rule the unit follows.
- An axis on the input and absent from the output would be summed rather than moved, so it is declined and [ArrayIndexContract]() is named; the same holds for an axis repeated within one operand and for an anonymous axis.
- The operand set is joined and the explicit tier is required; [ArrayMaterialize]() brings a lazy or symbolic operand to one.
- `"DefaultOutput"` and `"Targeting"` are read where a descriptor is compiled, as a *bindings* list is, so a prepared [ArrayIndexPattern]() or [ArrayIndexPlan]() carries what its own construction resolved and is declined all three; an option name [ArrayIndexTransform]() does not declare is declined before any setting is read. See [ArrayIndexPlan]().

## Basic Examples

<!-- #| annotation: 04.09.26: Design review - the effects a rearrangement admits are checked against the descriptor alone, before sizes are solved, so an axis that would be summed is declined on its spelling and the message names ArrayIndexContract, rather than surfacing as a shape that does not add up once the operand is read. -->

Exchange the two axes of a matrix:

```wl
ArrayIndexTransform["ij->ji", {{1, 2}, {3, 4}}]
```

<!-- => {{1, 3}, {2, 4}} -->

---

Split a vector into a matrix, the composite on the input side giving up its factors:

```wl
ArrayIndexTransform["(i j) -> i j", Range[6], {"i" -> 2}]
```

<!-- => {{1, 2, 3}, {4, 5, 6}} -->

---

Merge two axes into one, the composite on the output side:

```wl
ArrayIndexTransform["i j -> (i j)", {{1, 2}, {3, 4}}]
```

<!-- => {1, 2, 3, 4} -->

---

An axis present only on the output side is repeated to the size the binding gives it:

```wl
ArrayIndexTransform["i -> i j", {1, 2}, {"j" -> 3}]
```

<!-- => {{1, 1, 1}, {2, 2, 2}} -->

## Scope

### Rearranging

One descriptor splits a composite and permutes the factors it produced:

```wl
ArrayIndexTransform["(i j) -> j i", Range[6], {"i" -> 2}]
```

<!-- => {{1, 4}, {2, 5}, {3, 6}} -->

---

A literal `1` on the input side is a unit axis and is squeezed:

```wl
ArrayIndexTransform["i 1 -> i", {{1}, {2}, {3}}]
```

<!-- => {1, 2, 3} -->

---

A literal `1` on the output side inserts a unit axis:

```wl
ArrayIndexTransform["i -> i 1", {1, 2, 3}]
```

<!-- => {{1}, {2}, {3}} -->

---

With no output shape given the descriptor is the identity:

```wl
ArrayIndexTransform["i j", {{1, 2}, {3, 4}}]
```

<!-- => {{1, 2}, {3, 4}} -->

---

The same permutation in the list-of-shapes dialect:

```wl
ArrayIndexTransform[{{i_, j_}} :> {{j, i}}, {{1, 2}, {3, 4}}]
```

<!-- => {{1, 3}, {2, 4}} -->

---

An inline [Annotation]() gives the repeated axis its size in the descriptor itself:

```wl
ArrayIndexTransform[{{i_}} :> {{i, Annotation[j, 3]}}, {1, 2}]
```

<!-- => {{1, 1, 1}, {2, 2, 2}} -->

### Containers

A [SparseArray]() comes back a [SparseArray]():

```wl
transposed = ArrayIndexTransform["ij->ji", SparseArray[{{1, 0}, {0, 4}}]]
```

<!-- => a SparseArray summary box: rank 2, dimensions {2, 2}, 2 stored elements -->

The stored elements sit on the diagonal, which the exchange leaves where it is:

```wl
Normal[transposed]
```

<!-- => {{1, 0}, {0, 4}} -->

---

A [QuantityArray]() splits into a matrix in its own unit, the steps running on its magnitudes:

```wl
split = ArrayIndexTransform["(i j) -> i j", QuantityArray[Range[6], "Meters"], {"i" -> 2}]
```

<!-- => a QuantityArray summary box: dimensions {2, 3}, unit meters -->

The magnitudes underneath are the split ones:

```wl
QuantityMagnitude[split]
```

<!-- => {{1, 2, 3}, {4, 5, 6}} -->

---

A [NumericArray]() is materialized at the door and comes back a plain array:

```wl
ArrayIndexTransform["ij->ji", NumericArray[{{1, 2}, {3, 4}}, "Integer32"]]
```

<!-- => {{1, 3}, {2, 4}} -->

---

A [Tabular]() rearranges its materialized data:

```wl
ArrayIndexTransform["ij->ji", Tabular[{{1., 2.}, {3., 4.}}]]
```

<!-- => {{1., 3.}, {2., 4.}} -->

---

A [TabularColumn]() is materialized the same way, here under a repeat:

```wl
ArrayIndexTransform["i -> i j", TabularColumn[{1, 2}], {"j" -> 2}]
```

<!-- => {{1, 1}, {2, 2}} -->

### The compile-once path

A prepared [ArrayIndexPlan]() stands in the descriptor position and is executed as it stands:

```wl
ArrayIndexTransform[ArrayIndexPlan["ij->ji", {{2, 2}}], {{1, 2}, {3, 4}}]
```

<!-- => {{1, 3}, {2, 4}} -->

## Properties and Relations

A descriptor naming a permutation and nothing else emits one transpose step:

```wl
ArrayIndexTransform["ij->ji", {{1, 2}, {3, 4}}]
```

<!-- => {{1, 3}, {2, 4}} -->

---

[ArrayTranspose]() with that permutation gives the same array:

```wl
ArrayTranspose[{{1, 2}, {3, 4}}, {2, 1}]
```

<!-- => {{1, 3}, {2, 4}} -->

---

A descriptor that only splits a composite emits one reshape step:

```wl
ArrayIndexTransform["(i j) -> i j", Range[6], {"i" -> 2}]
```

<!-- => {{1, 2, 3}, {4, 5, 6}} -->

---

[ReshapeArray]() to the solved dimensions gives the same array:

```wl
ReshapeArray[Range[6], {2, 3}]
```

<!-- => {{1, 2, 3}, {4, 5, 6}} -->

---

[ArrayIndexPlan]() reports the steps a rearrangement runs, here a reshape and then a transpose:

```wl
ArrayIndexPlan["(i j) -> j i", {{6}}, {"i" -> 2}]["Steps"]
```

<!-- => {<|"Step" -> "Reshape", "Inputs" -> {1}, "Output" -> 2, "Frame" -> {1, 2}, "Dimensions" -> {2, 3}|>, <|"Step" -> "Transpose", "Inputs" -> {2}, "Output" -> 3, "Permutation" -> {2, 1}, "Frame" -> {2, 1}, "Dimensions" -> {3, 2}|>} -->

## Possible Issues

An axis on the input and absent from the output would be summed, which is [ArrayIndexContract]()'s work:

```wl
ArrayIndexTransform["ij->i", {{1, 2}, {3, 4}}]
```

<!-- => ArrayIndexTransform::effect message naming the axis j and ArrayIndexContract, then ArrayIndexTransform["ij->i", {{1, 2}, {3, 4}}] unevaluated -->

---

A literal axis is squeezed only where it is `1`, so a literal `3` dropped from the output is declined the same way:

```wl
ArrayIndexTransform["i 3 -> i", {{1, 2}, {3, 4}}]
```

<!-- => ArrayIndexTransform::effect message naming the axis 3, then ArrayIndexTransform["i 3 -> i", {{1, 2}, {3, 4}}] unevaluated -->

---

A repeated axis with no binding and no [Annotation]() has no size to repeat to:

```wl
ArrayIndexTransform["i -> i j", {1, 2}]
```

<!-- => ArrayIndexPlan::unresolved message, then ArrayIndexTransform["i -> i j", {1, 2}] unevaluated -->

---

A descriptor naming two input shapes is not a rearrangement:

```wl
ArrayIndexTransform["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}]
```

<!-- => ArrayIndexTransform::arity message, then ArrayIndexTransform["ij,jk->ik", {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}] unevaluated -->

---

An operand that joins to the lazy tier is declined, and [ArrayMaterialize]() brings it to the explicit tier; [ArrayIndexContract]() carries the symbolic case:

```wl
ArrayIndexTransform["ij->ji", Function[t, {{1, 2}, {3, 4}}]]
```

<!-- => ArrayIndexTransform::tier message naming the Lazy tier, then ArrayIndexTransform["ij->ji", Function[t, {{1, 2}, {3, 4}}]] unevaluated -->

---

A prepared plan carries the settings its own construction resolved, so a compile-time option given here is declined; see [ArrayIndexPlan]():

```wl
ArrayIndexTransform[ArrayIndexPlan["ij->ji", {{2, 2}}], {{1, 2}, {3, 4}}, "Targeting" -> True]
```

<!-- => ArrayIndexPlan::prepared message, then the call unevaluated, the prepared plan shown as its summary box -->
