---
Template: TechNote
Name: GPUBackedArrays
Title: GPU-Backed Arrays
Context: Wolfram`Arrays`
Paclet: Wolfram/Arrays
URI: Wolfram/Arrays/tutorial/GPUBackedArrays
Keywords: [GPUArray, device memory, compute native, element type, single precision, array container]
RelatedGuides: [Arrays]
---

A [GPUArray]() holds its elements in device memory rather than in the kernel's own heap. It reports its dimensions and its element type without a transfer, and arithmetic and [Dot]() run on the device and give back another [GPUArray](), so it is an explicit container that is also compute-native. This note covers its classification, its element types, why [ArrayComputable]() leaves it alone where a [NumericArray]() materializes, how it enters the type algebra, and what the single-precision device format and the transfer cost mean in practice.

## An Explicit, Compute-Native Container

Constructing a [GPUArray]() from a real matrix stores it on the device as a single-precision buffer:

```wl
g = GPUArray[{{1., 2.}, {3., 4.}}]
```

<!-- => GPUArray[NumericArray[<2,2>, "Real32"]] -->

---

The paclet admits it:

```wl
ArrayContainerQ[g]
```

<!-- => True -->

---

Its elements are in memory, so it is explicit rather than lazy or symbolic:

```wl
ArrayTier[g]
```

<!-- => "Explicit" -->

---

Its shape is read from the device buffer without copying anything back:

```wl
ArrayDimensions[g]
```

<!-- => {2, 2} -->

---

Arithmetic runs on the device, which is what the capability flag records:

```wl
ArrayComputeNativeQ[g]
```

<!-- => True -->

## Element Types Are Device Formats

Device buffers are single precision, so a real matrix becomes `"Real32"` whatever the precision of the input:

```wl
ArrayElementType[g]
```

<!-- => "Real32" -->

---

The domain follows from the type:

```wl
ArrayElementDomain[g]
```

<!-- => Reals -->

---

Complex input gets the complex device format:

```wl
gc = GPUArray[{{1. + 2. I, 3.}, {0., 4. I}}]
```

<!-- => GPUArray[NumericArray[<2,2>, "ComplexReal32"]] -->

---

```wl
ArrayElementDomain[gc]
```

<!-- => Complexes -->

---

Integer input is kept exact rather than cast to a float format:

```wl
gi = GPUArray[{{1, 2}, {3, 4}}]
```

<!-- => GPUArray[{{1, 2}, {3, 4}}] -->

---

```wl
ArrayElementType[gi]
```

<!-- => "Integer64" -->

## Computing Without Materializing

Because a [GPUArray]() computes natively, [ArrayComputable]() hands it back untouched:

```wl
ArrayComputable[g]
```

<!-- => GPUArray[NumericArray[<2,2>, "Real32"]] -->

---

A [NumericArray]() of the same values stores its elements but does not traverse them, so it materializes instead:

```wl
ArrayComputable[NumericArray[{{1., 2.}, {3., 4.}}, "Real64"]]
```

<!-- => {{1., 2.}, {3., 4.}} -->

---

A product of two device arrays stays on the device:

```wl
Dot[g, g]
```

<!-- => GPUArray[NumericArray[<2,2>, "Real32"]] -->

---

Its shape is available without a transfer:

```wl
ArrayDimensions[Dot[g, g]]
```

<!-- => {2, 2} -->

---

[ArrayMaterialize]() is the point at which the buffer is copied back to the kernel:

```wl
ArrayMaterialize[Dot[g, g]]
```

<!-- => {{7., 10.}, {15., 22.}} -->

## The Type Algebra

A device buffer joined with a host array widens rather than narrowing the host operand to device precision:

```wl
ArrayUnify[{g, NumericArray[{{1., 2.}, {3., 4.}}, "Real64"]}]["ElementType"]
```

<!-- => "Real64" -->

---

A [SparseArray]() of machine reals carries double precision too, so that join widens the same way:

```wl
ArrayUnify[{g, SparseArray[{{1., 0.}, {0., 2.}}]}]["ElementType"]
```

<!-- => "Real64" -->

---

An [ArrayObject]() wraps a device array like any other container:

```wl
ArrayObject[g]
```

<!-- => the ArrayObject summary box: explicit tier, dimensions {2, 2}, element type Real32 -->

## Performance

Device arithmetic is fast and transfers are not. On one machine at 1024 x 1024, a [Dot]() of two arrays already resident on the device took about 13 microseconds, while the same product on a packed [Real64]() list took about 5 milliseconds. Copying the result back added about 0.7 milliseconds, and uploading a [Real64]() list to the device took about 20 milliseconds.

Those numbers do not add up to a win for a single product: uploading two operands, multiplying and copying the result back took about 41 milliseconds against 5 milliseconds for the host product. The device pays off when several operations run between the upload and the download. Chaining eight products with one copy back took about 2.5 milliseconds, against about 59 milliseconds for the same chain on the host.

Uploading from a [Real32]() [NumericArray]() rather than a [Real64]() list costs about 1.2 milliseconds instead of 20, since no conversion is needed at the boundary.

## Possible Issues

Device buffers are single precision, so materializing a real array gives back the single-precision value rather than the one that went in:

```wl
ArrayMaterialize[GPUArray[{N[1/3]}]]
```

<!-- => {0.3333333432674408} -->

---

The host value it was built from carries the full machine precision:

```wl
{N[1/3]}
```

<!-- => {0.3333333333333333} -->

---

The device accepts vectors and matrices only, so a rank-3 array is not a [GPUArray]() and is not a container:

```wl
ArrayContainerQ[GPUArray[RandomReal[1, {2, 2, 2}]]]
```

<!-- => GPUArray::spec; False -->

---

Recognition goes through [GPUArrayQ]() rather than the head, so a malformed call, which stays inert with head [GPUArray](), is declined:

```wl
ArrayContainerQ[GPUArray["nonsense"]]
```

<!-- => GPUArray::spec; False -->

---

An integer device array holds exact integers, so it is numeric but not inexact:

```wl
ArrayNumberQ[gi]
```

<!-- => False -->

---

Timing device work needs care: an expression that constructs a [GPUArray]() inside the timed region allocates a fresh device buffer on every repetition, and repeated-timing functions evaluate their argument many times. Build the device arrays first and time only the operation:

```wl
a = GPUArray[{{1., 2.}, {3., 4.}}];
First @ AbsoluteTiming @ Do[Dot[a, a], {100}]
```

<!-- => a small number of seconds; the value varies between runs -->
