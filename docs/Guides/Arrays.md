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

The Arrays paclet treats the many array representations of the Wolfram Language as one family of containers under a single admission criterion: the shape must be introspectable without materializing the elements, and a materialization path must exist. Containers come in three tiers. The explicit tier holds its elements in memory: [SparseArray](), packed and plain [List]() arrays, [NumericArray](), structured arrays such as [SymmetrizedArray](), and shape-introspectable wrapper containers ([QuantityArray](), [TabularColumn](), [Tabular](), [Dataset](), [ByteArray](), [EventSeries]() and [DataStructure]() array stores). The lazy tier is an array-valued expression awaiting parameters, such as an array-valued [InterpolatingFunction]() applied to a symbolic time. The symbolic tier has no elements at all: [VectorSymbol](), [MatrixSymbol](), [ArraySymbol](), symbols registered in [$Assumptions](), and structural inactive trees over them. Whether a container also computes natively without materializing is a separate per-head capability flag, not an admission gate.

## Functions

### Tier predicates

- `ArrayContainerQ` test whether an expression is a supported array container of any tier
- `ArrayExplicitQ` test for an explicit container: `SparseArray`, packed or plain lists, `NumericArray`, structured arrays and shape-introspectable wrappers
- `ArrayLazyQ` test for a lazy parametric container, an array-valued expression with a non-numeric argument
- `ArraySymbolicQ` test for a symbolic container: array symbols, assumption-registered symbols and structural inactive trees
- `ArrayComputeNativeQ` test whether an explicit container computes natively without materializing

### Shape and element predicates

- `ArrayDimensions` the dimensions of a container of any tier, without materializing it
- `ArrayRank` the number of dimensions of a container
- `ZeroArrayQ` test whether any dimension of a container is zero
- `ArrayNumericQ` test whether all elements of an explicit container are numeric
- `ArrayNumberQ` test whether all elements of an explicit container are inexact numbers
- `ArrayAllZeroQ` test whether every element of an explicit container is provably zero

### Stored values and materialization

- `ArrayExplicitValues` the explicitly stored values of a container, via an on-demand sparse wrap
- `ArrayExplicitPositions` the positions of the explicitly stored values
- `ArrayExplicitLength` the number of explicitly stored values
- `ArrayMaterialize` an explicit array of scalar expressions from a container of any tier
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
- `ArrayReplaceAll` apply replacement rules, evaluating a lazy container a single time

### Container handles

- `ArrayObject` a handle around any supported container, formatted as a summary box showing its container kind and dimensions, with properties for kind, tier, shape and classification
- `ArrayObjectQ` test whether an expression is a container handle

## Tech Notes

- [Array Containers](paclet:Wolfram/Arrays/tutorial/ArrayContainers)
