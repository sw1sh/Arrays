Package["Wolfram`Arrays`"]

PackageExport[ArrayVector]
PackageExport[ReshapeArray]
PackageExport[PadArray]

ArrayVector::usage ="ArrayVector[a] flattens an explicit array container to a vector, using a raw CSR construction for a SparseArray of rank above 11; a lazy container stays lazy where its head supplies a lazy-preserving rebuild and materializes through ArrayMaterialize where it does not, as for a ParametricFunction; a deferred structural tree stays deferred, gaining an Inactive[ArrayReshape] node rather than being computed; a leafless symbolic array such as a MatrixSymbol has no elements to restructure and is left unevaluated; a rank-1 container of any tier passes through unchanged, as does a scalar - anything with no array structure, whether or not it is a number, since flattening one is the identity."

ReshapeArray::usage = "ReshapeArray[a, dims] reshapes an explicit array container to the given dimensions, preserving the container where ArrayReshape does; a lazy container stays lazy where its head supplies a lazy-preserving rebuild and materializes through ArrayMaterialize where it does not, as for a ParametricFunction; a deferred structural tree stays deferred, gaining an Inactive[ArrayReshape] node rather than being computed; a leafless symbolic array is left unevaluated.\nReshapeArray[a, dims, pad] pads with pad when the reshape needs more elements."

PadArray::usage = "PadArray[a, spec] pads an explicit array container with zeros according to spec, preserving the container where ArrayPad does; a NumericArray converts through Normal and re-wraps; a lazy container stays lazy where its head supplies a lazy-preserving rebuild and materializes through ArrayMaterialize where it does not, as for a ParametricFunction.\nPadArray[a, spec, padding] pads with the given padding."


(* === flatten to vector === *)

(* ArrayVector subsumes the QuantumFramework SparseArrayFlatten helper: raw CSR
   construction for a SparseArray of rank above 11 (Flatten degrades there),
   scalar passthrough, generic Flatten for the explicit tier. The name follows
   the Array* scheme without colliding with System`ArrayFlatten. *)

ArrayVector[sa_SparseArray] := With[{dims = sa["Dimensions"]},
    With[{
        (* if all dimensions are equal don't fold *)
        cs = If[Equal @@ dims, dims ^ Range[Length[dims] - 1, 0, -1], Reverse @ FoldList[Times, 1, dims[[-1 ;; 2 ;; -1]]]],
        ps = Catenate @ MapThread[ConstantArray, {Range[0, dims[[1]] - 1], Differences @ sa["RowPointers"]}]
    },
        SparseArray[
            Automatic,
            {Times @@ dims},
            sa["ImplicitValue"],
            {
                1,
                {
                    {0, sa["ExplicitLength"]},
                    List /@ (1 + First[cs] * ps + Total[Thread[Rest[cs] #] & /@ (sa["ColumnIndices"] - 1), {2}])
                },
                sa["ExplicitValues"]
            }
        ]
    ] /; Length[dims] > 11
]

(* Flattening a SCALAR is the identity, and whether the scalar happens to be a
   number is beside the point.  A fully contracted tensor network leaves one,
   and it is symbolic the moment the network carries a parameter: the NumericQ
   test covered only half of that case, so a parametrised circuit contracted to
   a scalar came back as an inert ArrayVector[expr] and was stored downstream as
   an amplitude.

   A scalar here is something with no array structure at all - not a List, and
   not a container of any tier.  A ragged list is neither, and stays
   unevaluated as it did: it has a flatten, just not one this paclet promises. *)

scalarQ[x_] := ! ListQ[x] && ! ArrayContainerQ[x]

ArrayVector[x_ ? scalarQ] := x

(* QuantityArray flattens natively and keeps its wrapper on the generic
   clause; the remaining wrappers flatten their materialized data. *)
ArrayVector[a_ ? opaqueWrapperQ] := Flatten[ArrayMaterialize[a]]

ArrayVector[a_ ? ArrayExplicitQ] := Flatten[a]

(* A rank-1 lazy container is already a vector, so it passes through before any
   rebuild is attempted: flattening it could only turn a lazy container into a
   materialized one for no gain. *)
ArrayVector[a_ ? lazyContainerQ] := If[ArrayRank[a] == 1, a, lazyStructuralOp[Flatten, a]]

(* Flattening a deferred structural tree is a reshape to rank 1, and
   Inactive[ArrayReshape] is itself an admitted structural node
   (Classification.wl), so the flatten is one more node on the tree rather than
   a reason to compute it.  ArrayTranspose already works this way - its generic
   clause leaves Transpose unevaluated on a symbolic operand - and this brings
   the shape-only operations into line.

   Materializing here instead would defeat the tier: the whole point of a
   deferred tree is that its value is not computed until something actually
   needs the numbers.

   A leafless symbolic array is left alone: a MatrixSymbol has no elements to
   restructure, so declining is the honest answer and the call stays
   unevaluated, as it always did. *)
ArrayVector[a_ ? deferredTreeQ] := If[ArrayRank[a] == 1, a,
    Inactive[ArrayReshape][a, {Times @@ ArrayDimensions[a]}]
]

(* The rank-1 passthrough is promised for a container of any tier, so it holds
   for a symbolic one too: a VectorSymbol is already a vector. *)
ArrayVector[a_ ? ArraySymbolicQ] /; ArrayRank[a] == 1 := a


(* === reshape and pad (non-colliding System equivalents) === *)

(* QuantityArray reshapes natively via ArrayReshape and keeps its wrapper on
   the generic clauses; the remaining wrappers reshape materialized data. *)
ReshapeArray[a_ ? opaqueWrapperQ, dims : {___Integer ? NonNegative}] := ArrayReshape[ArrayMaterialize[a], dims]

ReshapeArray[a_ ? opaqueWrapperQ, dims : {___Integer ? NonNegative}, pad_] := ArrayReshape[ArrayMaterialize[a], dims, pad]

ReshapeArray[a_ ? ArrayExplicitQ, dims : {___Integer ? NonNegative}] := ArrayReshape[a, dims]

ReshapeArray[a_ ? ArrayExplicitQ, dims : {___Integer ? NonNegative}, pad_] := ArrayReshape[a, dims, pad]

ReshapeArray[a_ ? lazyContainerQ, dims : {___Integer ? NonNegative}] :=
    lazyStructuralOp[ArrayReshape[#, dims] &, a]

ReshapeArray[a_ ? lazyContainerQ, dims : {___Integer ? NonNegative}, pad_] :=
    lazyStructuralOp[ArrayReshape[#, dims, pad] &, a]

ReshapeArray[a_ ? deferredTreeQ, dims : {___Integer ? NonNegative}] :=
    Inactive[ArrayReshape][a, dims]

ReshapeArray[a_ ? deferredTreeQ, dims : {___Integer ? NonNegative}, pad_] :=
    Inactive[ArrayReshape][a, dims, pad]


(* ArrayPad does not support NumericArray, so it converts through Normal and
   re-wraps, mirroring the ArrayConjugate NumericArray clause. *)

PadArray[a_NumericArray, spec_] := NumericArray[ArrayPad[Normal[a], spec]]

PadArray[a_NumericArray, spec_, padding_] := NumericArray[ArrayPad[Normal[a], spec, padding]]

(* ArrayPad on a QuantityArray degrades to a mixed List of Quantity elements
   and plain padding, so every wrapper (QuantityArray included) pads its
   materialized data. *)
PadArray[a_ ? wrapperExplicitQ, spec_] := ArrayPad[ArrayMaterialize[a], spec]

PadArray[a_ ? wrapperExplicitQ, spec_, padding_] := ArrayPad[ArrayMaterialize[a], spec, padding]

PadArray[a_ ? ArrayExplicitQ, spec_] := ArrayPad[a, spec]

PadArray[a_ ? ArrayExplicitQ, spec_, padding_] := ArrayPad[a, spec, padding]

(* A lazy container pads the way it reshapes: through the head's
   lazy-preserving rebuild where it has one, and through ArrayMaterialize where
   it does not.  Without these clauses the lazy tier matched no definition at
   all and PadArray came back unevaluated, which reads downstream as "not a
   container" rather than as the padded array. *)

PadArray[a_ ? lazyContainerQ, spec_] := lazyStructuralOp[ArrayPad[#, spec] &, a]

PadArray[a_ ? lazyContainerQ, spec_, padding_] := lazyStructuralOp[ArrayPad[#, spec, padding] &, a]
