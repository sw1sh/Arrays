# Wolfram/Arrays

A domain-neutral abstraction over Wolfram Language array containers: one dispatch layer
for classifying, introspecting, and operating on arrays regardless of how they are
stored - explicit (`SparseArray`, packed arrays, `List`, `NumericArray`,
structured arrays, and shape-introspectable wrappers: `QuantityArray`,
`TabularColumn`, `Tabular`, `Dataset`, `ByteArray`, `EventSeries`, and
DataStructure array stores), lazy-parametric (array-valued expressions awaiting
parameters, applied like `InterpolatingFunction[...][t]` and `ParametricFunction`, or
unapplied like a bare single-coordinate `InterpolatingFunction` and an array-valued
`Function`), and symbolic
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

## Installation

Published on the Wolfram Paclet Repository as
[**Wolfram/Arrays**](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/Arrays/):

```wl
PacletInstall["Wolfram/Arrays"]

Needs["Wolfram`Arrays`"]
```

The documentation is also published as a site, with a feedback form on every page:
[**WolframArrays**](https://www.wolframcloud.com/obj/nikm/WolframArrays).

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

Build the documentation and the paclet with [PacletPage](https://github.com/WolframInstitute/PacletPage),
which `pacletpage.wl` fetches from GitHub together with
[MarkdownToNotebook](https://github.com/WolframInstitute/MarkdownToNotebook):

```
wolframscript -f build.wls                # docs/ into Arrays/Documentation and Arrays/ResourceDefinition.nb
wolframscript -f submit.wls --dry-run     # the archive in Arrays/build, checked to hold every page and to load
wolframscript -f submit.wls               # the submission to the Paclet Repository
wolframscript -f release.wls              # the paclet resource and the documentation site, in the connected account
```

`PACLETPAGE_REF` and `MTN_REF` pick the refs the two are fetched at, and `PACLETPAGE_PARALLEL` a
number of parallel kernels for the pages. A submission runs in a kernel connected to the Wolfram
Cloud as an account that owns the publisher `Wolfram`, and a release in one connected to the
account the site is published in.
