---
Template: Symbol
Name: ArrayObject
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/ref/ArrayObject
Keywords: [array container, container handle, summary box, container kind, tier, introspection]
SeeAlso: [ArrayObjectQ, ArrayContainerQ, ArrayDimensions, ArrayRank, ArrayMaterialize, ArrayComputeNativeQ, ArrayNumericQ]
RelatedGuides: [Arrays]
---

## Usage

<code>[ArrayObject]()[*a*]</code> gives a handle around the array container *a*, formatted as a summary box showing its container kind and dimensions.

## Details & Options

- <code>[ArrayObject]()[*a*]["*prop*"]</code> gives the value of the property *prop*, and <code>[ArrayObject]()[*a*]["Properties"]</code> the list of supported properties.
- [ArrayObject]() accepts any expression satisfying [ArrayContainerQ](), in all three tiers. Any other input gives an `ArrayObject::nocontainer` message and stays unevaluated, and any number of arguments other than one gives an `ArrayObject::argx` message.
- Wrapping is idempotent: <code>[ArrayObject]()[[ArrayObject]()[*a*]]</code> gives <code>[ArrayObject]()[*a*]</code>.
- Supported properties:

| Property | Value |
|---|---|
| `"Data"` | the wrapped container, unchanged |
| `"Kind"` | the container kind, a string naming its head |
| `"Tier"` | `"Explicit"`, `"Lazy"` or `"Symbolic"` |
| `"Dimensions"` | [ArrayDimensions]() of the container |
| `"Rank"` | [ArrayRank]() of the container |
| `"ComputeNativeQ"` | [ArrayComputeNativeQ]() of the container |
| `"NumericQ"` | [ArrayNumericQ]() of the container |
| `"NumberQ"` | [ArrayNumberQ]() of the container |
| `"ElementType"` | the stored element type, where the container carries one |
| `"Normal"` | [ArrayMaterialize]() of the container |
| `"Properties"` | the list of supported properties |

- `"Normal"` is the only property that materializes; every other property is a shape or classification probe.
- An unknown property gives an `ArrayObject::noprop` message and stays unevaluated, and any number of arguments other than one property name gives an `ArrayObject::propx` message.
- `"Kind"` names the head carrying the container: a [SparseArray]() gives `"SparseArray"`, an array-valued [InterpolatingFunction]() application gives `"InterpolatingFunction"`, and an inactive tree gives the operation, so an [Inactive]() [TensorProduct]() gives `"TensorProduct"`. A [List]() gives `"PackedArray"` or `"List"` according to its packing, and a symbol registered in [$Assumptions]() gives `"Symbol"`.
- `"ElementType"` is given for the containers that store one, [NumericArray]() and [TabularColumn](); every other container gives `Missing["NotApplicable"]`.
- The collapsed summary box shows the kind and the dimensions. Expanding it adds the tier, the compute-native flag, the two numericity flags, and the element type, or the unit for a [QuantityArray]().
- The summary box renders for lazy and symbolic containers without materializing them: it reads only the shape and classification tiers, so an [NDSolveValue]()-backed application and a [MatrixSymbol]() draw a full box with no elements computed.
- Every function in the paclet takes an [ArrayObject]() wherever it takes a container, and gives the answer for the container it wraps. A result is never re-wrapped: [ArrayVector]() of a handle around a [SparseArray]() is a [SparseArray](), not another handle.
- A handle nested inside a list argument is not unwrapped, so <code>[ArrayContract]()[{*a*, *obj*}, *pairs*]</code> can give its result in a different container form than the raw-container call would. Pass `"Data"` in a list.
- A handle is re-validated on every use. If the container it wraps stops satisfying [ArrayContainerQ]() - an [$Assumptions]() entry registering a symbol is removed, say - the handle gives an `ArrayObject::nocontainer` message and `Missing["NotAContainer"]`, rather than falling through to the generic shape probe and reporting dimensions `{}` and rank 0. The classification predicates give [False]() for such a handle instead of messaging.

## Basic Examples

<!-- #| annotation: 26.07.26: Design review - the object IS the wrapper expression: the head carries no constructor, only a rejection guard whose condition ends in False either way, so a container is left alone and anything else messages and stays unevaluated rather than yielding a half-formed object; the cost is that ArrayContainerQ runs on every evaluation instead of once at construction, bounded by ArrayQ on a plain nested List - O(n), and paid again on every property read and every render, which is the price of catching a handle whose container has stopped qualifying, since admission can lapse and a once-validated handle would go on reporting a shape it no longer has. Kind is derived by walking the head chain to the first Symbol rather than looked up in a table, so a head the classification tier admits later reports its own name instead of a stale label - "ParametricFunction", "Function" and "Piecewise" are unreachable Kinds today and cost nothing to keep reachable. Every exported function unwraps a handle at its entry point and returns a RAW container, never a rebuilt handle: "never rebuilt" settles the re-wrap question once for the whole surface, and it is what keeps the veneer thin, since no other kernel file mentions ArrayObject. The unwrapping clauses are not a convenience - the tier UpValues make a handle satisfy ArrayContainerQ and ArrayExplicitQ, the guards nearly every definition in the paclet is written against, so without them ArrayVector[obj] would match a_ ? ArrayExplicitQ and hand the wrapper straight to Flatten, a silent wrong answer rather than an inert expression. The box reads a QuantityArray unit through "UnitBlock", not QuantityUnit, which builds a full per-element array of units. Prior art: the kernel gives NumericArray, QuantityArray and InterpolatingFunction each their own summary box but no common handle across container heads, and Dataset wraps by converting the data it is given; this handle stores the container unchanged, is optional, and nothing else in the paclet depends on it. -->

A handle around a sparse matrix, formatted as a summary box:

```wl
ArrayObject[SparseArray[{{0, 1}, {2, 0}}]]
```

<!-- => ArrayObject summary box: kind SparseArray, dimensions {2, 2} -->

---

The kind of container in hand:

```wl
ArrayObject[SparseArray[{{0, 1}, {2, 0}}]]["Kind"]
```

<!-- => "SparseArray" -->

---

Its dimensions, read without materializing it:

```wl
ArrayObject[SparseArray[{{0, 1}, {2, 0}}]]["Dimensions"]
```

<!-- => {2, 2} -->

---

The wrapped container comes back unchanged:

```wl
ArrayObject[SparseArray[{{0, 1}, {2, 0}}]]["Data"]
```

<!-- => a SparseArray summary box: dimensions {2, 2}, 2 stored elements, Normal is {{0, 1}, {2, 0}} -->

---

The supported properties:

```wl
ArrayObject[{1., 2.}]["Properties"]
```

<!-- => {"ComputeNativeQ", "Data", "Dimensions", "ElementType", "Kind", "Normal", "NumberQ", "NumericQ", "Properties", "Rank", "Tier"} -->

## Scope

### Container kinds

A packed list is distinguished from a plain one:

```wl
ArrayObject[Range[3]]["Kind"]
```

<!-- => "PackedArray" -->

---

A nested list of symbols is a plain list:

```wl
ArrayObject[{{a1, a2}, {a3, a4}}]["Kind"]
```

<!-- => "List" -->

---

A structured array reports its own head:

```wl
ArrayObject[SymmetrizedArray[{{1, 2} -> 3.}, {2, 2}, Antisymmetric[{1, 2}]]]["Kind"]
```

<!-- => "SymmetrizedArray" -->

---

A [QuantityArray]() reports its head as well:

```wl
ArrayObject[QuantityArray[{1., 2.}, "Meters"]]["Kind"]
```

<!-- => "QuantityArray" -->

---

So does a [TabularColumn]():

```wl
ArrayObject[TabularColumn[{1., 2.}]]["Kind"]
```

<!-- => "TabularColumn" -->

---

And a [Tabular]():

```wl
ArrayObject[Tabular[{{1., 2.}, {3., 4.}}]]["Kind"]
```

<!-- => "Tabular" -->

---

And a [Dataset]():

```wl
ArrayObject[Dataset[{1, 2, 3}]]["Kind"]
```

<!-- => "Dataset" -->

---

And a [ByteArray]():

```wl
ArrayObject[ByteArray[{1, 2, 3}]]["Kind"]
```

<!-- => "ByteArray" -->

---

And an [EventSeries]():

```wl
ArrayObject[EventSeries[{1., 2.}, {{0, 1}}]]["Kind"]
```

<!-- => "EventSeries" -->

---

A dynamic array is named for the data structure that carries it:

```wl
ArrayObject[CreateDataStructure["DynamicArray", {1., 2.}]]["Kind"]
```

<!-- => "DataStructure" -->

---

A lazy container is named by the head that carries it:

```wl
v = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}];
ArrayObject[v[tau]]["Kind"]
```

<!-- => "InterpolatingFunction" -->

---

A symbolic container reports its array-symbol head:

```wl
ArrayObject[MatrixSymbol["M", {2, 3}]]["Kind"]
```

<!-- => "MatrixSymbol" -->

---

An inactive tree reports the operation rather than [Inactive]():

```wl
ArrayObject[Inactive[TensorProduct][VectorSymbol["u", 2], MatrixSymbol["N", {3, 4}]]]["Kind"]
```

<!-- => "TensorProduct" -->

---

A symbol registered in [$Assumptions]() is reported as a symbol:

```wl
Block[{$Assumptions = {Element[a, Matrices[{2, 2}]]}}, ArrayObject[a]["Kind"]]
```

<!-- => "Symbol" -->

### Tiers

A wrapper container storing its elements is on the explicit tier:

```wl
ArrayObject[QuantityArray[{1., 2.}, "Meters"]]["Tier"]
```

<!-- => "Explicit" -->

---

An array-valued interpolation awaiting its parameter is on the lazy tier:

```wl
v = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}];
ArrayObject[v[tau]]["Tier"]
```

<!-- => "Lazy" -->

---

An array symbol, which has no elements at all, is on the symbolic tier:

```wl
ArrayObject[MatrixSymbol["M", {2, 3}]]["Tier"]
```

<!-- => "Symbolic" -->

### Shape and classification

The rank of a symbolic container:

```wl
ArrayObject[ArraySymbol["T", {2, 3, 4}]]["Rank"]
```

<!-- => 3 -->

---

A [SparseArray]() computes natively, without being materialized first:

```wl
ArrayObject[SparseArray[{{0, 1}, {2, 0}}]]["ComputeNativeQ"]
```

<!-- => True -->

---

A [NumericArray]() does not:

```wl
ArrayObject[NumericArray[{1., 2.}]]["ComputeNativeQ"]
```

<!-- => False -->

---

An array of symbols is not numeric:

```wl
ArrayObject[{{a1, a2}, {a3, a4}}]["NumericQ"]
```

<!-- => False -->

---

An array of exact integers is numeric but not inexact:

```wl
ArrayObject[{{1, 2}, {3, 4}}]["NumberQ"]
```

<!-- => False -->

### Element types

A [NumericArray]() reports the type it stores:

```wl
ArrayObject[NumericArray[{1, 2}, "Integer32"]]["ElementType"]
```

<!-- => "Integer32" -->

---

A container that stores no element type reports a missing value:

```wl
ArrayObject[SparseArray[{1., 2.}]]["ElementType"]
```

<!-- => Missing["NotApplicable"] -->

### Materialization

`"Normal"` routes through [ArrayMaterialize](), so a [QuantityArray]() gives its packed magnitudes:

```wl
ArrayObject[QuantityArray[{1., 2.}, "Meters"]]["Normal"]
```

<!-- => {1., 2.} -->

---

[Normal]() applied to the handle gives the same result:

```wl
Normal[ArrayObject[ByteArray[{1, 2, 3}]]]
```

<!-- => {1, 2, 3} -->

---

A symbolic container has no elements to materialize and gives itself:

```wl
ArrayObject[MatrixSymbol["M", {2, 3}]]["Normal"]
```

<!-- => MatrixSymbol["M", {2, 3}] -->

### Summary box

The box of a lazy container is drawn without evaluating the interpolation:

```wl
v = NDSolveValue[{f'[t] == {{0, 1}, {-1, 0}} . f[t], f[0] == {1., 0.}}, f, {t, 0, 1}];
ArrayObject[v[tau]]
```

<!-- => ArrayObject summary box: kind InterpolatingFunction, dimensions {2} -->

---

A symbolic container, which has no elements, draws a full box too:

```wl
ArrayObject[MatrixSymbol["M", {2, 3}]]
```

<!-- => ArrayObject summary box: kind MatrixSymbol, dimensions {2, 3} -->

## Properties and Relations

A handle around a [NumericArray]():

```wl
obj = ArrayObject[NumericArray[{{1., 0.}, {0., 2.}}]]
```

<!-- => ArrayObject summary box: kind NumericArray, dimensions {2, 2} -->

---

[ArrayContainerQ]() accepts the handle:

```wl
ArrayContainerQ[obj]
```

<!-- => True -->

---

[ArrayDimensions]() reads the shape of the container it wraps:

```wl
ArrayDimensions[obj]
```

<!-- => {2, 2} -->

---

So does [ArrayRank]():

```wl
ArrayRank[obj]
```

<!-- => 2 -->

---

[ArrayComputeNativeQ]() gives the answer for the wrapped [NumericArray]():

```wl
ArrayComputeNativeQ[obj]
```

<!-- => False -->

---

And [ArrayNumberQ]() reports its inexact machine reals:

```wl
ArrayNumberQ[obj]
```

<!-- => True -->

---

The tier predicates agree with the `"Tier"` property, so a handle around an array symbol is not explicit:

```wl
ArrayExplicitQ[ArrayObject[MatrixSymbol["M", {2, 3}]]]
```

<!-- => False -->

---

Nor is it lazy:

```wl
ArrayLazyQ[ArrayObject[MatrixSymbol["M", {2, 3}]]]
```

<!-- => False -->

---

It is symbolic:

```wl
ArraySymbolicQ[ArrayObject[MatrixSymbol["M", {2, 3}]]]
```

<!-- => True -->

---

[ArrayMaterialize]() on a handle materializes the container it wraps:

```wl
ArrayMaterialize[ArrayObject[SparseArray[{{0, 1}, {2, 0}}]]]
```

<!-- => {{0, 1}, {2, 0}} -->

---

Wrapping an existing handle gives the handle back, rather than a handle around a handle:

```wl
ArrayObject[ArrayObject[{1., 2.}]]
```

<!-- => ArrayObject summary box: kind List, dimensions {2} -->

---

The kind is the kind of the innermost container, not [ArrayObject]():

```wl
ArrayObject[ArrayObject[{1., 2.}]]["Kind"]
```

<!-- => "List" -->

---

A structural operation takes a handle and gives back the container, never another handle:

```wl
ArrayVector[ArrayObject[SparseArray[{{0, 1}, {2, 0}}]]]
```

<!-- => SparseArray summary box: rank-1, 2 stored elements; Normal is {0, 1, 2, 0} -->

---

The transpose of a handle is the transposed array:

```wl
Normal[ArrayTranspose[ArrayObject[SparseArray[{{0, 1}, {2, 0}}]], {2, 1}]]
```

<!-- => {{0, 2}, {1, 0}} -->

---

Reading a part of a handle reads the part of the array it wraps:

```wl
ArrayPart[ArrayObject[{{1., 2.}, {3., 4.}}], {1, 2}]
```

<!-- => 2. -->

## Possible Issues

Input that is not an array container stays unevaluated after an `ArrayObject::nocontainer` message, and an [Association]() is rejected for the reason [ArrayContainerQ]() rejects it, its entry multiset not being a faithful shape:

```wl
ArrayObject[<|1 -> 1.5, 2 -> 2.5|>]
```

<!-- => ArrayObject::nocontainer message, then ArrayObject[<|1 -> 1.5, 2 -> 2.5|>] unevaluated -->

---

An unknown property stays unevaluated after an `ArrayObject::noprop` message:

```wl
ArrayObject[{1., 2.}]["Bogus"]
```

<!-- => ArrayObject::noprop message, then ArrayObject[{1., 2.}]["Bogus"] unevaluated -->

---

So does a call with anything other than one property name:

```wl
ArrayObject[{1., 2.}]["Kind", "Tier"]
```

<!-- => ArrayObject::propx message, then ArrayObject[{1., 2.}]["Kind", "Tier"] unevaluated -->

---

Admission can lapse: a handle around a symbol registered in [$Assumptions]() stops being a handle once that entry is removed, and says so rather than reporting a shape it no longer has:

```wl
staleObj = Block[{$Assumptions = {Element[symStale, Matrices[{2, 2}]]}}, ArrayObject[symStale]];
ArrayDimensions[staleObj]
```

<!-- => ArrayObject::nocontainer message, then Missing["NotAContainer"] -->

---

The classification predicates answer for such a handle instead of messaging:

```wl
ArrayObjectQ[staleObj]
```

<!-- => False -->

---

A handle nested inside a list argument is not unwrapped at the entry point, so the contraction is taken on the array the handle materializes to and the result comes back in a different container form than the same call on raw containers; pass `"Data"` in the list to keep the forms identical:

```wl
ArrayContract[{SparseArray[{{0, 1}, {2, 0}}], ArrayObject[SparseArray[{{0, 1}, {2, 0}}]]}, {{1, 3}}]
```

<!-- => Inactive[TensorProduct] wrapping a 2x2 SparseArray whose Normal is {{4, 0}, {0, 1}} -->
