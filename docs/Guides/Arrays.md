---
Template: Guide
Name: Arrays
Title: Arrays
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/guide/Arrays
Description: Uniform classification, shape introspection and structural operations across explicit, lazy and symbolic array containers
Keywords: [array container, sparse array, packed array, numeric array, symbolic array, lazy array, materialization]
---

## Abstract

The Arrays paclet treats the many array representations of the Wolfram Language as one family of containers under a single admission criterion: the shape must be introspectable without materializing the elements, and a materialization path must exist. Containers come in three tiers. The explicit tier holds its elements in memory: [SparseArray](), packed and plain [List]() arrays, [NumericArray](), structured arrays such as [SymmetrizedArray](), and shape-introspectable wrapper containers ([QuantityArray](), [TabularColumn](), [Tabular](), [Dataset](), [ByteArray](), [EventSeries]() and [DataStructure]() array stores). The lazy tier is an inert array-valued expression whose head is registered in the tier: an array-valued [InterpolatingFunction]() applied to a symbolic time, a fully applied [ParametricFunction](), an unapplied array-valued [Function](), an array-valued [Piecewise](), and a source [NetGraph]() or [NetChain](). The symbolic tier has a shape and no addressable elements: [VectorSymbol](), [MatrixSymbol](), [ArraySymbol](), symbols registered in [$Assumptions](), structural trees over them, and the deferred contraction tree a tensor-network contraction returns unactivated. Whether a container also computes natively without materializing is a separate per-head capability flag, not an admission gate. The tiers and the element domains are ordered lattices, so a set of containers of different kinds has a common representation: [ArrayTier]() and [ArrayElementDomain]() read the two coordinates, [ArrayUnify]() joins them over an operand set, and [ArrayCoerce]() moves a single container up either lattice.

## Functions

### Tiers and classification

- `ArrayContainerQ` test whether an expression is a supported array container of any tier
- `ArrayTier` the tier a container belongs to, `"Explicit"`, `"Lazy"` or `"Symbolic"`
- `ArrayExplicitQ` test for an explicit container: `SparseArray`, packed or plain lists, `NumericArray`, structured arrays and shape-introspectable wrappers
- `ArrayLazyQ` test for a lazy container: an inert array-valued interpolating, parametric, function, piecewise or net expression
- `ArraySymbolicQ` test for a symbolic container: array symbols, assumption-registered symbols, and symbolic or deferred structural trees
- `ArrayComputeNativeQ` test whether an explicit container computes natively without materializing

### Shape and elements

- `ArrayDimensions` the dimensions of a container of any tier, without materializing it
- `ArrayRank` the number of dimensions of a container
- `ArrayDeclareShape` declare the shape of a lazy container that no shape probe settles
- `ZeroArrayQ` test whether any dimension of a container is zero
- `ArrayNumericQ` test whether all elements of an explicit container are numeric
- `ArrayNumberQ` test whether all elements of an explicit container are inexact numbers
- `ArrayAllZeroQ` test whether every element of an explicit container is provably zero

### Element types and coercion

- `ArrayElementDomain` the element domain of a container, from `Integers` up to `Complexes`
- `ArrayElementType` the concrete element type stored by a container that carries one
- `ArrayUnify` the common tier, domain and element type of a set of containers, with the operands coerced to it
- `ArrayCoerce` coerce a container up the tier and element lattices, refusing any move down them

### Stored values and materialization

- `ArrayExplicitValues` the explicitly stored values of a container, via an on-demand sparse wrap
- `ArrayExplicitPositions` the positions of the explicitly stored values
- `ArrayExplicitLength` the number of explicitly stored values
- `ArrayMaterialize` an explicit array of scalar expressions from a container of any tier
- `ArrayComputable` the least conversion of a container that makes native arithmetic work
- `ArrayPack` best-effort packed array conversion that never destroys exact values

### Structural operations

- `ArrayTranspose` transpose a container, composing nested permutations and keeping lazy containers lazy
- `ArrayContract` contract index pairs of a container or of a tensor product of containers
- `ArrayPart` part extraction that slices symbolic containers structurally
- `ArrayConjugate` conjugate a container, preserving explicit container heads
- `ArrayVector` flatten a container to a vector, with a fast sparse route at high rank
- `ReshapeArray` reshape a container to given dimensions, with optional padding
- `PadArray` pad a container, preserving `SparseArray` and `NumericArray` heads
- `SimplifyArray` remove trivial structural wrappers from a symbolic array expression
- `ArrayName` the name carried by a symbolic container

### Higher-order operations

- `ArrayMap` map a function over the elements of a container, preserving sparse structure and packing
- `ArrayReplaceAll` apply replacement rules, evaluating a lazy container a single time and applying a `Function` container rather than rewriting it

### Container handles

- `ArrayObject` a handle around any supported container, formatted as a summary box showing its container kind and dimensions, with properties for kind, tier, shape and classification
- `ArrayObjectQ` test whether an expression is a container handle

## Tech Notes

- [Array Containers](paclet:Wolfram/Arrays/tutorial/ArrayContainers)
- [Net-Backed Arrays](paclet:Wolfram/Arrays/tutorial/NetBackedArrays)
- [GPU-Backed Arrays](paclet:Wolfram/Arrays/tutorial/GPUBackedArrays)
