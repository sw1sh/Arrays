# Wolfram/Arrays

A domain-neutral abstraction over Wolfram Language array containers: one dispatch layer
for classifying, introspecting, and operating on arrays regardless of how they are
stored - explicit (`SparseArray`, packed arrays, `List`, `NumericArray`,
structured arrays, and shape-introspectable wrappers: `QuantityArray`,
`TabularColumn`, `Tabular`, `Dataset`, `ByteArray`, `EventSeries`, and
DataStructure array stores), lazy-parametric (array-valued inert applications such as
`InterpolatingFunction[...][t]` and `ParametricFunction`), and symbolic
(`VectorSymbol` / `MatrixSymbol` / `ArraySymbol`, assumption-registered symbols,
inactive tensor expression trees).

A container type is supported if its shape is introspectable without materializing and
a materialization path exists. In-container compute support is a per-type capability,
not a requirement - storage-only containers materialize before compute and re-wrap
where a reconstruction path exists.

`ArrayObject` wraps any supported container in a uniform, self-describing handle whose
summary box shows at a glance what kind of container it is and what shape it has. It is a
completeness feature and a thin veneer: no other kernel file mentions it, every other
function keeps operating on raw containers, and a handle is unwrapped to one - by
`ArrayObject[a]["Data"]`, or at the entry point of every exported function - before any
of them sees it. A result is never re-wrapped.

## Layout

```
Arrays/            this repository
    Arrays/        the paclet (PacletInfo.wl, Kernel/, Documentation/)
    Tests/         test suite and runner
    docs/          literate-markdown documentation sources
```

Load the paclet from source:

```wolfram
PacletDirectoryLoad["path/to/Arrays/Arrays"]
Needs["Wolfram`Arrays`"]
```

Run the tests:

```
wolframscript -f Tests/RunTests.wls
```

Build the documentation:

```
wolframscript -f build_docs.wls
```
