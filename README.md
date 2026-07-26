# WolframInstitute/ArrayUtilities

A domain-neutral abstraction over Wolfram Language array containers: one dispatch layer
for classifying, introspecting, and operating on arrays regardless of how they are
stored - explicit (`SparseArray`, packed arrays, `List`, `NumericArray`,
structured arrays), lazy-parametric (array-valued inert applications such as
`InterpolatingFunction[...][t]` and `ParametricFunction`), and symbolic
(`VectorSymbol` / `MatrixSymbol` / `ArraySymbol`, assumption-registered symbols,
inactive tensor expression trees).

Admission criterion: a container type is supported if its shape is introspectable
without materializing and a materialization path exists. In-container compute support
is a per-type capability, not a requirement - storage-only containers materialize
before compute and re-wrap where a reconstruction path exists.

## Layout

The paclet is nested one level deep so this repository can be consumed as a git
submodule:

```
ArrayUtilities/            this repo
    ArrayUtilities/        the paclet (PacletInfo.wl, Kernel/)
    Tests/                 test suite + runner
```

Load the paclet from source:

```wolfram
PacletDirectoryLoad["path/to/ArrayUtilities/ArrayUtilities"]
Needs["WolframInstitute`ArrayUtilities`"]
```

Run the tests:

```
wolframscript -f Tests/RunTests.wls
```

## Lineage

The symbolic tier and the `Array*` API shape follow
`Wolfram`TensorNetworks`IndexArray`ArrayUtilities`; the flatten-to-vector fast path
(`ArrayVector`) and lazy InterpolatingFunction handling originate in
`Wolfram/QuantumFramework`, whose `QuantumState` container generalization is the
primary consumer.
