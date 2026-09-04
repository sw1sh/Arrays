Package["Wolfram`Arrays`"]

(* The three names below are the whole of what crosses this file's boundary, and
   they are read by IndexOperators.wl at call time.  Nothing declared elsewhere
   is spliced into a left-hand side here: the normalized term heads indexAxis
   and indexProduct belong to IndexNotation.wl and are matched only inside a
   right-hand side, where they are read as data rather than re-declared. *)
PackageScope[indexOperandDimensions]
PackageScope[indexSolvedDescriptor]
PackageScope[indexSolvedQ]


(* === the operand shape ===

   A plan is solved against dimension lists, and the entrance takes either
   arrays or the dimension lists themselves, so an operand is reduced to its
   shape HERE and the solver below never sees a container.  ArrayDimensions,
   never Dimensions: it shapes a container of any tier without materializing it,
   and it is the only reading that is right on the inactive tensor nodes this
   layer builds.  Anything that is not a container - a bare number, most of all -
   is a rank-0 operand, whose shape is the empty list that the scalar shape {}
   of a descriptor carries. *)

indexOperandDimensions[x_] := If[ArrayContainerQ[x], ArrayDimensions[x], {}]


(* === the solver state ===

   Size solving is a fixed point over a map from axis id to size that only ever
   grows, and every equation - an operand dimension, an inline or out-of-band
   binding fact, a composite factor resolved by division - reaches that map
   through indexMergeSize, which is the single place the two size refusals are
   raised.  Threading the map through both passes and the merge would turn every
   equation into a fold over an accumulator that is never read except by the
   merge, so the map is dynamically scoped instead and indexSolvedDescriptor is
   its only binder: the three symbols carry no global value, so a merge outside
   a solve fails loudly rather than writing somewhere.

   $indexNormalized carries the descriptor the sizes belong to, since a message
   names an axis by its display name and a literal axis is refused by a message
   of its own; $indexShapeIndex carries the input shape whose dimension a merge is
   matching, which is what the literal refusal names. *)


(* === entry point ===

   The order is forced by the system: the shape-free half is known before any
   operand is read, atomic axes unify against dimensions in one pass, and only
   then can a composite have a single unknown factor to divide out.  The
   normalized stage is embedded rather than discarded, because everything
   downstream - the axis table for the analysis, the source map for a message,
   the output shape for the final reshape - is read from it. *)

indexSolvedDescriptor[normalized_Association, shapes_List] :=
    Block[{$indexNormalized = normalized, $indexSizes = <||>, $indexShapeIndex = None},
        Module[{inputs = normalized["Inputs"], dimensions, composites},
            If[ Length[shapes] =!= Length[inputs],
                indexFail[
                    ArrayIndexPlan, "operands", {Length[shapes], Length[inputs]},
                    <|"Shapes" -> shapes|>
                ]
            ];
            indexSeedSizes[normalized];
            dimensions = indexAtomicPass[inputs, shapes];
            composites = indexCompositeEquations[dimensions];
            indexCompositePass[composites];
            indexResolvedCheck[normalized];
            <|
                "Normalized" -> normalized,
                "InputShapes" -> shapes,
                "AxisSizes" -> AssociationMap[indexAxisSize, Keys[normalized["Axes"]]],
                "OutputShapes" -> {Map[indexTermSize, First[normalized["Outputs"]]]},
                "Constraints" -> Join[normalized["Constraints"], dimensions]
            |>
        ]
    ]


(* === the shape-free half ===

   A literal term and a binding fact - an inline Annotation, a Labeled, or an
   out-of-band rule - are known sizes before any operand is looked at, and both
   spellings are replayed: the constraint records are the system the pattern
   object reports, the binding facts are the system as it was collected, and a
   fact that also has a record coalesces through indexMergeSize rather than one
   quietly shadowing the other.  Two facts that disagree fail here, before any
   dimension is read, which is what makes the failure independent of the order
   the facts were given in. *)

indexSeedSizes[normalized_Association] := (
    Scan[
        Function[c, indexMergeSize[c["Axis"], c["Size"]]],
        Cases[normalized["Constraints"], KeyValuePattern["Constraint" -> "KnownSize"]]
    ];
    Scan[
        Function[fact, indexMergeSize[fact["Axis"], fact["Size"]]],
        normalized["Bindings"]
    ]
)


(* === pass 1: atomic axes against dimensions ===

   One term stands for one dimension, a composite included, so a rank that does
   not match the term count is a refusal rather than a shorter zip.  Each
   dimension is checked to be a positive integer BEFORE it takes part in
   anything: Mod[n, 3] =!= 0 is True for a symbolic n, and every divisibility
   and equality test downstream would report a bogus mismatch on a dimension
   that is simply not a number.  A composite is deferred, since its factors
   cannot be divided out until every atomic axis it shares has been unified.

   The Dimension records this pass returns are both the solved stage's half of
   the constraint list and the composite equations themselves, read back by
   indexCompositeEquations - the equation IS the record. *)

indexAtomicPass[inputs_List, shapes_List] :=
    Catenate @ Table[
        Module[{terms = inputs[[k]], dims = shapes[[k]]},
            If[ Length[terms] =!= Length[dims],
                indexFail[
                    ArrayIndexPlan, "rank", {k, Length[terms], Length[dims]},
                    <|"Operand" -> k, "Terms" -> terms|>
                ]
            ];
            $indexShapeIndex = k;
            Table[
                Module[{term = terms[[p]], d = dims[[p]]},
                    If[ ! (IntegerQ[d] && Positive[d]),
                        indexFail[
                            ArrayIndexPlan, "dimension", {d, k},
                            <|"Operand" -> k, "Position" -> p, "Source" -> indexSourceOf[{"Inputs", k, p}]|>
                        ]
                    ];
                    If[Head[term] === indexAxis, indexMergeSize[First[term], d]];
                    <|"Constraint" -> "Dimension", "Operand" -> k, "Position" -> p, "Term" -> term, "Size" -> d|>
                ],
                {p, Length[terms]}
            ]
        ],
        {k, Length[inputs]}
    ]


(* A composite equation is its factor ids counted WITH multiplicity and in
   order, flattened through indexFlatTerms so that a composite of composites -
   which associativity has already flattened once at capture - cannot hide a
   factor from the count. *)

indexCompositeEquations[dimensions_List] :=
    Map[
        Function[c,
            <|"Operand" -> c["Operand"], "Factors" -> indexProductFactors[c["Term"]], "Size" -> c["Size"]|>
        ],
        Select[dimensions, Function[c, Head[c["Term"]] === indexProduct]]
    ]

indexProductFactors[term_] := Map[First, Map[First, indexFlatTerms[First[term]]]]


(* === pass 2: composites to a fixed point ===

   A composite resolves when exactly one factor OCCURRENCE is unknown, so the
   unknowns are counted with multiplicity: (a a) against 9 has one unknown axis
   but two occurrences and resolves nothing, while (2 c) against 6 has a known
   literal factor and resolves c to 3.  Counting distinct unknowns instead would
   answer 3 for the first and refuse the second.

   A sweep that resolves nothing ends the loop, and every composite is then
   revalidated through the all-known branch - which is also the branch that
   checks a composite that was fully known from the start.  Revalidating rather
   than trusting the sweep is what makes a composite consistent ACROSS operands:
   the factors an operand resolves are checked against every other dimension the
   same factors stand for. *)

indexCompositePass[composites_List] :=
    Module[{progressed = True},
        While[progressed,
            progressed = False;
            Scan[
                Function[c, If[indexResolveComposite[c], progressed = True]],
                composites
            ]
        ];
        Scan[indexCheckComposite, composites]
    ]

indexResolveComposite[c_Association] :=
    Module[{unknown = Select[c["Factors"], indexUnsizedQ], product},
        Length[unknown] === 1 && (
            $indexShapeIndex = c["Operand"];
            product = Times @@ Lookup[$indexSizes, DeleteCases[c["Factors"], First[unknown]]];
            If[ ! Divisible[c["Size"], product],
                indexFail[
                    ArrayIndexPlan, "composite", {c["Operand"], product, c["Size"]},
                    <|"Operand" -> c["Operand"], "Axes" -> c["Factors"]|>
                ]
            ];
            indexMergeSize[First[unknown], Quotient[c["Size"], product]];
            True
        )
    ]

indexCheckComposite[c_Association] :=
    Module[{unknown = Select[c["Factors"], indexUnsizedQ], product},
        If[ unknown =!= {},
            indexFail[
                ArrayIndexPlan, "unresolved", {indexAxisNames[unknown]},
                <|"Axes" -> unknown, "Operand" -> c["Operand"]|>
            ]
        ];
        product = Times @@ Lookup[$indexSizes, c["Factors"]];
        If[ product =!= c["Size"],
            indexFail[
                ArrayIndexPlan, "composite", {c["Operand"], product, c["Size"]},
                <|"Operand" -> c["Operand"], "Axes" -> c["Factors"]|>
            ]
        ]
    ]


(* === the merge ===

   Every size in the system arrives here, so this is where an axis is pinned to
   one size across the whole descriptor and where the two refusals that name
   both sizes are raised.  An equal fact coalesces silently - the same axis on
   two operands of the same extent is the ordinary case, not a re-declaration -
   and a disagreement is a refusal whichever side arrived first.  A literal or
   unit axis gets its own message, since its size is written in the descriptor
   and the operand is what disagrees with it. *)

indexMergeSize[id_Integer, n_Integer] :=
    Module[{known = Lookup[$indexSizes, id, None]},
        Which[
            known === None,
                AssociateTo[$indexSizes, id -> n],
            known === n,
                $indexSizes,
            MatchQ[$indexNormalized["Axes"][id]["Kind"], "Literal" | "Unit"],
                indexFail[
                    ArrayIndexPlan, "literal", {indexAxisLabel[$indexNormalized, id], $indexShapeIndex, n},
                    <|"Axis" -> id, "Source" -> indexSourceOf[$indexNormalized["Axes"][id]["Source"]]|>
                ],
            True,
                indexFail[
                    ArrayIndexPlan, "conflict", {indexAxisLabel[$indexNormalized, id], known, n},
                    <|"Axis" -> id, "Source" -> indexSourceOf[$indexNormalized["Axes"][id]["Source"]]|>
                ]
        ]
    ]

indexUnsizedQ[id_Integer] := ! KeyExistsQ[$indexSizes, id]

indexAxisSize[id_Integer] := Lookup[$indexSizes, id]


(* === what is left over ===

   Every axis of the table must have a size, including one that reaches no
   operand: an axis on the output and on no input is a broadcast, and it takes
   its size from a binding fact or from nowhere at all.  Naming all of them in
   one message rather than the first says which sizes have to be supplied
   together. *)

indexResolvedCheck[normalized_Association] :=
    Module[{missing = Select[Keys[normalized["Axes"]], indexUnsizedQ]},
        If[ missing =!= {},
            indexFail[
                ArrayIndexPlan, "unresolved", {indexAxisNames[missing]},
                <|"Axes" -> missing|>
            ]
        ]
    ]

indexAxisNames[ids_List] :=
    StringRiffle[
        Map[Function[id, indexAxisLabel[$indexNormalized, id]], DeleteDuplicates[ids]],
        ", "
    ]

indexSourceOf[path_List] := Lookup[$indexNormalized["SourceMap"], Key[path], None]


(* A term stands for one dimension on either side, so the output dimensions are
   read the same way the input dimensions were checked: an axis gives its size
   and a composite multiplies its factors out, which is the merge the final
   reshape performs.  A literal keeps its size and a unit axis gives the 1 that
   same reshape inserts. *)

indexTermSize[term_] :=
    If[ Head[term] === indexAxis,
        indexAxisSize[First[term]],
        Times @@ Lookup[$indexSizes, indexProductFactors[term]]
    ]


(* === the stage predicate ===

   Total, and called from the pipeline rather than only from tests: indexPlanQ
   runs it over the stage a plan carries, so an ArrayIndexPlan whose solved
   descriptor does not describe its own steps is declined at the entrance with
   the malformed-plan message instead of executed.  The checks are the
   invariants of the stage - one size per axis of the table, a dimension list
   per input shape, exactly one output shape - and And short-circuits, so a
   missing key is answered before any check that reads it. *)

indexSolvedQ[solved_Association] :=
    TrueQ @ And[
        ContainsAll[Keys[solved], {"Normalized", "InputShapes", "AxisSizes", "OutputShapes", "Constraints"}],
        indexNormalizedQ[solved["Normalized"]],
        MatchQ[solved["InputShapes"], {{___Integer} ...}],
        AllTrue[Catenate[solved["InputShapes"]], Positive],
        Length[solved["InputShapes"]] === Length[solved["Normalized"]["Inputs"]],
        AssociationQ[solved["AxisSizes"]],
        Keys[solved["AxisSizes"]] === Keys[solved["Normalized"]["Axes"]],
        MatchQ[Values[solved["AxisSizes"]], {___Integer}],
        AllTrue[solved["AxisSizes"], Positive],
        MatchQ[solved["OutputShapes"], {{___Integer}}],
        AllTrue[First[solved["OutputShapes"]], Positive],
        MatchQ[solved["Constraints"], {___Association}]
    ]

indexSolvedQ[_] := False
