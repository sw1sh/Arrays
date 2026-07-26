Package["Wolfram`Arrays`"]

PackageExport[ArrayVector]
PackageExport[ReshapeArray]
PackageExport[PadArray]


ArrayVector::usage = "ArrayVector[a] flattens an explicit array container to a vector, using a raw CSR construction for a SparseArray of rank above 11; a lazy container flattens its value grid and stays lazy; scalar numeric input passes through unchanged."

ReshapeArray::usage = "ReshapeArray[a, dims] reshapes an explicit array container to the given dimensions, preserving the container where ArrayReshape does; a lazy container reshapes its value grid and stays lazy.\nReshapeArray[a, dims, pad] pads with pad when the reshape needs more elements."

PadArray::usage = "PadArray[a, spec] pads an explicit array container with zeros according to spec, preserving the container where ArrayPad does; a NumericArray converts through Normal and re-wraps.\nPadArray[a, spec, padding] pads with the given padding."


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

ArrayVector[x_ ? NumericQ] := x

(* QuantityArray flattens natively and keeps its wrapper on the generic
   clause; the remaining wrappers flatten their materialized data. *)
ArrayVector[a_ ? opaqueWrapperQ] := Flatten[ArrayMaterialize[a]]

ArrayVector[a_ ? ArrayExplicitQ] := Flatten[a]

ArrayVector[expr : (f_InterpolatingFunction)[parameter_]] :=
    If[ArrayRank[expr] == 1, expr, reinterpolate[Flatten, f][parameter]] /; ArrayLazyQ[expr]


(* === reshape and pad (non-colliding System equivalents) === *)

(* QuantityArray reshapes natively via ArrayReshape and keeps its wrapper on
   the generic clauses; the remaining wrappers reshape materialized data. *)
ReshapeArray[a_ ? opaqueWrapperQ, dims : {___Integer ? NonNegative}] := ArrayReshape[ArrayMaterialize[a], dims]

ReshapeArray[a_ ? opaqueWrapperQ, dims : {___Integer ? NonNegative}, pad_] := ArrayReshape[ArrayMaterialize[a], dims, pad]

ReshapeArray[a_ ? ArrayExplicitQ, dims : {___Integer ? NonNegative}] := ArrayReshape[a, dims]

ReshapeArray[a_ ? ArrayExplicitQ, dims : {___Integer ? NonNegative}, pad_] := ArrayReshape[a, dims, pad]

ReshapeArray[expr : (f_InterpolatingFunction)[parameter_], dims : {___Integer ? NonNegative}] :=
    reinterpolate[ArrayReshape[#, dims] &, f][parameter] /; ArrayLazyQ[expr]

ReshapeArray[expr : (f_InterpolatingFunction)[parameter_], dims : {___Integer ? NonNegative}, pad_] :=
    reinterpolate[ArrayReshape[#, dims, pad] &, f][parameter] /; ArrayLazyQ[expr]


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
