Package["Wolfram`Arrays`"]

PackageScope[indexOperationAnalysis]
PackageScope[indexAdmitEffects]
PackageScope[indexExecutionPlan]
PackageScope[indexPlanQ]


(* === the middle of the compiler ===

   Two values are built here.  The OPERATION ANALYSIS says what a descriptor
   does to each of its axes; the EXECUTION PLAN says how.  They are separated
   because the analysis is purely structural - it reads the normalized
   descriptor and never a size - so a parsed pattern can report its effects with
   no operand in sight, while the plan needs the solved sizes for every
   dimension it writes down.

   Nothing in this file matches a normalized term in a definition left-hand
   side.  indexAxis and indexProduct belong to IndexNotation.wl, and a term
   reaches this file already flattened by indexFlatTerms, so an axis id is read
   out by part rather than by pattern.

   The message templates live in IndexOperators.wl beside the symbols that own
   them; a refusal here throws through indexFail and is turned into a message at
   the public boundary. *)


(* The diagnostic payload of a refusal about one axis: its id, and the held
   surface fragment it was captured from.  The path is wrapped in Key because a
   path is itself a List, and a bare List key reads as several keys. *)

indexAxisSource[normalized_Association, id_Integer] :=
    With[{path = Lookup[Lookup[normalized["Axes"], id, <||>], "Source", None]},
        <|"Axis" -> id, "Source" -> Lookup[normalized["SourceMap"], Key[path], None]|>
    ]

indexAxisNames[normalized_Association, ids_List] := Map[Function[id, indexAxisLabel[normalized, id]], ids]


(* === frames === *)

(* A FRAME is the axis content of a shape after the two structural erasures the
   lift performs on the way in: a CircleTimes composite is flattened to its
   factors, because the split reshape gives each factor its own dimension, and a
   unit axis is dropped, because the same reshape squeezes it.  Nothing else is
   erased - a literal of size two or more keeps its slot and is summed like any
   other axis the output does not carry.

   An input frame is NOT duplicate-free: an axis repeated within one operand
   occurs twice and is resolved into a trace by the plan's self-contraction
   step.  An output frame is duplicate-free, since a repeated output axis was
   already declined at normalization.

   The path of every surviving input occurrence is kept beside its frame
   position, because "Targets" is keyed by path: an occurrence is what a target
   sits on, and a target may sit on a composite, in which case it stands for
   every factor under it. *)

indexFrames[normalized_Association] :=
    Module[{axes = normalized["Axes"], shapes = normalized["Inputs"], frames, positions = {}, units = {}, outFrame = {}},
        frames = Table[
            Module[{frame = {}},
                Do[
                    With[{id = leaf[[1, 1]], path = Join[{"Inputs", k}, leaf[[2]]]},
                        If[ axes[id]["Kind"] === "Unit",
                            AppendTo[units, <|"Effect" -> "UnitAxis", "Axis" -> id, "Side" -> "Inputs", "Source" -> path|>],
                            AppendTo[frame, id];
                            AppendTo[positions, path -> {k, Length[frame]}]
                        ]
                    ],
                    {leaf, indexFlatTerms[shapes[[k]]]}
                ];
                frame
            ],
            {k, Length[shapes]}
        ];
        Do[
            With[{id = leaf[[1, 1]], path = Join[{"Outputs", 1}, leaf[[2]]]},
                If[ axes[id]["Kind"] === "Unit",
                    AppendTo[units, <|"Effect" -> "UnitAxis", "Axis" -> id, "Side" -> "Outputs", "Source" -> path|>],
                    AppendTo[outFrame, id]
                ]
            ],
            {leaf, indexFlatTerms[First[normalized["Outputs"]]]}
        ];
        <|"InputFrames" -> frames, "OutputFrame" -> outFrame, "Positions" -> positions, "Units" -> units|>
    ]


(* === effect classification === *)

(* One axis, one effect, and the occurrence policy is checked in the same place
   that assigns it, so an effect that exists is admissible and the analysis
   carries no list of violations.

   The branches are ordered from the most local evidence outwards.  Three
   occurrences in one operand is a generalized diagonal with no lowering here;
   two in one operand and any elsewhere mixes a trace with a contraction, which
   the pairwise trace cannot express; two in one operand and kept on the output
   is the diagonal "ii->i", which is declined by name rather than answered with
   row sums.  What survives is the trace, the carry and the contraction.

   A "Contracted" axis with ONE occurrence is not a separate effect: an axis the
   output drops is summed over every slot that carries it, and one slot is the
   degenerate case of that, not a different operation. *)

indexClassifyAxis[normalized_Association, id_Integer, inputs_List, outputs_List] :=
    Module[{repeat = If[inputs === {}, 0, Max[Counts[inputs[[All, 1]]]]]},
        Which[
            inputs === {},
                <|"Effect" -> "Broadcast", "Axis" -> id, "Outputs" -> outputs|>,
            repeat >= 3 || (repeat === 2 && Length[inputs] > 2),
                indexFail[ArrayIndexPlan, "occurrences",
                    {indexAxisLabel[normalized, id], Length[inputs]}, indexAxisSource[normalized, id]],
            repeat === 2 && outputs =!= {},
                indexFail[ArrayIndexPlan, "diagonal",
                    {indexAxisLabel[normalized, id]}, indexAxisSource[normalized, id]],
            repeat === 2,
                <|"Effect" -> "SelfContracted", "Axis" -> id, "Inputs" -> inputs|>,
            outputs =!= {},
                <|"Effect" -> "Carried", "Axis" -> id, "Inputs" -> inputs, "Outputs" -> outputs|>,
            True,
                <|"Effect" -> "Contracted", "Axis" -> id, "Inputs" -> inputs|>
        ]
    ]


(* === the global axis order and the merge set === *)

(* Output axes first, then the contracted ones, then whatever is left.  Putting
   the output axes first is what makes the final permutation the identity in the
   common case; the order is otherwise arbitrary, and it is fixed here so that
   every operand is lifted into the SAME frame. *)

indexGlobalOrder[outFrame_List, effects_List, frames_List] :=
    DeleteDuplicates @ Join[
        outFrame,
        Map[Function[record, record["Axis"]], Cases[effects, KeyValuePattern["Effect" -> "Contracted"]]],
        Catenate[frames]
    ]

(* Merging identifies one axis across several operands by multiplying them
   elementwise in a common frame - the diagonal that TensorContract has no
   spelling for.  It is needed exactly for an axis the OUTPUT carries and two or
   more operands supply: a batch index.  An axis the output drops needs no
   merge, because summing over one slot per operand is what a contraction group
   already does.

   Merging fewer operands than every one touching an output axis is deliberate:
   an expand-and-multiply materializes the full outer product of its members, so
   the members are kept to those that actually share an index. *)

indexMergeSet[outFrame_List, frames_List] :=
    Module[{flat = Catenate[frames], shared, members},
        shared = Select[outFrame, Function[id, Count[flat, id] >= 2]];
        members = Select[Range[Length[frames]], Function[k, IntersectingQ[frames[[k]], shared]]];
        If[Length[members] >= 2, members, {}]
    ]


(* === targeting === *)

(* A target is recorded per path, and a path may name a composite, so an
   occurrence counts as targeted when SOME target path is a prefix of it.  A
   target that is a prefix of no input occurrence - one on the output side, or
   on an axis the frame dropped - is a target on nothing and is refused by
   name: the marked-versus-contracted comparison below has nothing of it to
   show, and both of that message's sets can be empty while the stray target
   is the whole problem. *)

indexPathPrefixQ[prefix_List, path_List] :=
    Length[prefix] <= Length[path] && Take[path, Length[prefix]] === prefix

(* The axes under a target path, read from the descriptor's own terms rather
   than from the surviving occurrences: a target that survives nowhere still
   sits somewhere, and its refusal names the axes it sits on. *)
indexTargetPathAxes[normalized_Association, paths_List] :=
    Module[{leaves},
        leaves = Join[
            Catenate @ Table[
                Map[Function[leaf, {Join[{"Inputs", k}, leaf[[2]]], leaf[[1, 1]]}],
                    indexFlatTerms[normalized["Inputs"][[k]]]],
                {k, Length[normalized["Inputs"]]}
            ],
            Map[Function[leaf, {Join[{"Outputs", 1}, leaf[[2]]], leaf[[1, 1]]}],
                indexFlatTerms[First[normalized["Outputs"]]]]
        ];
        DeleteDuplicates @ Catenate @ Map[
            Function[t, Map[Last, Select[leaves, Function[leaf, indexPathPrefixQ[t, First[leaf]]]]]],
            paths
        ]
    ]

indexTargetedOccurrences[normalized_Association, frames_List, positions_List, effects_List, targeting_] :=
    Module[{targets = Keys[normalized["Targets"]], occurrences, matched, unmatched, marked, wanted},
        If[targeting === False, occurrences = {},
            occurrences = Values @ Select[positions,
                Function[place, AnyTrue[targets, Function[t, indexPathPrefixQ[t, First[place]]]]]];
            matched = Select[targets,
                Function[t, AnyTrue[positions, Function[place, indexPathPrefixQ[t, First[place]]]]]];
            unmatched = Complement[targets, matched];
            If[ unmatched =!= {},
                indexFail[ArrayIndexPlan, "targetplace",
                    {indexAxisNames[normalized, indexTargetPathAxes[normalized, unmatched]]},
                    <|"Targets" -> unmatched|>
                ]
            ];
            (* The comparison is between AXES and not between occurrences: a
               target marks the axis it sits on, so one bracket on one operand
               marks a contracted axis that occurs on two, and the marked set is
               what the refusal names.  Comparing occurrence lists instead would
               refuse "i [j], j k -> i k" with a message naming j on both sides
               of its own mismatch. *)
            marked = DeleteDuplicates[Map[Function[place, Extract[frames, place]], occurrences]];
            wanted = Map[Function[record, record["Axis"]],
                Cases[effects, KeyValuePattern["Effect" -> "Contracted" | "SelfContracted"]]];
            (* With Automatic the check runs only once the descriptor has spelled
               a target at all, which is what lets an untargeted einsum
               descriptor contract by repeated name.  With True it always runs,
               so a contracted axis with no target is a refusal. *)
            If[ (targeting === True || targets =!= {}) && Sort[marked] =!= Sort[wanted],
                indexFail[ArrayIndexPlan, "target",
                    {indexAxisNames[normalized, marked], indexAxisNames[normalized, wanted]},
                    <|"Targets" -> targets|>
                ]
            ]
        ];
        occurrences
    ]


(* === the analysis === *)

indexOperationAnalysis[normalized_Association, targeting_] :=
    Module[{parts, frames, outFrame, positions, units, unitRecords, inputOccurrences, outputOccurrences,
            effects, order, selfContracted, reduced, merge, mergeFrame},
        If[ ! MatchQ[targeting, True | Automatic | False],
            indexFail[ArrayIndexPlan, "option", {targeting, "Targeting"}, <|"Option" -> "Targeting"|>]
        ];
        parts = indexFrames[normalized];
        frames = parts["InputFrames"];
        outFrame = parts["OutputFrame"];
        positions = parts["Positions"];
        units = parts["Units"];
        (* An occurrence is a {operand, framePosition} pair, and the whole
           classification reads these two tables.  Grouping by axis keeps the
           occurrences of one axis in operand-then-position order, which is the
           order the contraction groups and the trace pairs are read in. *)
        inputOccurrences = GroupBy[
            Catenate @ Table[{frames[[k, p]], {k, p}}, {k, Length[frames]}, {p, Length[frames[[k]]]}],
            First -> Last
        ];
        outputOccurrences = GroupBy[Table[{outFrame[[q]], {1, q}}, {q, Length[outFrame]}], First -> Last];
        unitRecords = GroupBy[units, Function[unit, unit["Axis"]], First];
        (* Axis ids are allocated in first-occurrence order, so walking the axis
           table in key order gives the effect records in that order too, and
           every id in the table occurs somewhere by construction. *)
        effects = Table[
            If[ KeyExistsQ[unitRecords, id],
                unitRecords[id],
                indexClassifyAxis[normalized, id, Lookup[inputOccurrences, id, {}], Lookup[outputOccurrences, id, {}]]
            ],
            {id, Keys[normalized["Axes"]]}
        ];
        order = indexGlobalOrder[outFrame, effects, frames];
        (* The merge is computed against the frames a trace has already left:
           a self-contracted axis is gone before any operand is lifted, so it
           can neither join a merge frame nor be broadcast into one. *)
        selfContracted = Map[Function[record, record["Axis"]], Cases[effects, KeyValuePattern["Effect" -> "SelfContracted"]]];
        reduced = Map[Function[frame, Select[frame, Function[id, ! MemberQ[selfContracted, id]]]], frames];
        merge = indexMergeSet[outFrame, reduced];
        mergeFrame = If[ merge === {},
            {},
            With[{content = Catenate[reduced[[merge]]]}, Select[order, Function[id, MemberQ[content, id]]]]
        ];
        <|
            "Normalized" -> normalized,
            "InputFrames" -> frames,
            "OutputFrame" -> outFrame,
            "Effects" -> effects,
            "GlobalOrder" -> order,
            "MergeSet" -> merge,
            "MergeFrame" -> mergeFrame,
            "Targeting" -> targeting,
            "TargetedOccurrences" -> indexTargetedOccurrences[normalized, frames, positions, effects, targeting]
        |>
    ]


(* === entrance policy === *)

(* The entry symbol is compared rather than matched, because the public heads
   are declared in IndexOperators.wl and a left-hand side here would freeze
   against whichever file loaded first.  A contraction admits every effect the
   analysis can produce; a rearrangement admits every effect that moves an axis
   and none that sums one, so the axis that would be summed is named and
   ArrayIndexContract is named beside it. *)

indexAdmitEffects[analysis_Association, sym_Symbol] :=
    Module[{normalized = analysis["Normalized"], summed},
        If[ sym === ArrayIndexTransform,
            If[ Length[analysis["InputFrames"]] > 1,
                indexFail[ArrayIndexTransform, "arity",
                    {Length[analysis["InputFrames"]], Length[normalized["Outputs"]]}, <||>]
            ];
            summed = FirstCase[analysis["Effects"], KeyValuePattern["Effect" -> "Contracted" | "SelfContracted"], None];
            If[ summed =!= None,
                indexFail[ArrayIndexTransform, "effect",
                    {indexAxisLabel[normalized, summed["Axis"]]}, indexAxisSource[normalized, summed["Axis"]]]
            ]
        ];
        analysis
    ]


(* === the plan === *)

(* ArrayTranspose and Transpose take the SCATTER permutation: input level i
   goes to output level perm[[i]].  The planner always knows the GATHER instead
   - which input position supplies each output position - and Ordering turns one
   into the other.  current and wanted are the same set, duplicate-free. *)

indexGatherPermutation[current_List, wanted_List] :=
    Ordering[Flatten[Map[Function[id, FirstPosition[current, id]], wanted]]]

(* Every step carries "Step", "Inputs", "Output", "Frame" and "Dimensions"; its
   own fields sit between the register it writes and the shape of what it
   writes, so a step reads as verb, operands, result, argument, shape. *)

indexEmit[step_String, inputs_List, output_Integer, own_Association, frame_List, dims_List] :=
    Join[<|"Step" -> step, "Inputs" -> inputs, "Output" -> output|>, own, <|"Frame" -> frame, "Dimensions" -> dims|>]


(* The plan is a single-assignment register file: registers 1 to n hold the
   operands as given, each step writes one fresh register, and every register is
   read at most once - so the whole plan renders to one nested expression whose
   only open positions are the operand slots, which is the Function that
   "Expression" hands back.

   The seven passes are the alignment core: lift each operand into a common
   axis order, combine, contract, and lower the result back onto the output
   shape.  A step is emitted only when it is not the identity, which is why a
   pure permutation comes out as a single ArrayTranspose and a pure split as a
   single ReshapeArray.

   The expand-and-multiply of pass 3 is applied to the merge members ONLY and
   never to the contraction operands: lifting every operand to the full global
   frame, as the einx lowering does, would materialize the entire outer product
   before summing it, while a contraction group over the inactive tensor product
   never builds one. *)

indexExecutionPlan[analysis_Association, solved_Association] :=
    Module[{
            sizes = solved["AxisSizes"], inputShapes = solved["InputShapes"], effects = analysis["Effects"],
            outFrame = analysis["OutputFrame"], outDims = First[solved["OutputShapes"]],
            merge = analysis["MergeSet"], mergeFrame = analysis["MergeFrame"],
            frames, dims, regs, steps = {}, next, n, traces, live, scalars, tensors, combine,
            slotFrame, slotDims, groups, dropped, result, resultFrame, resultDims, spread, factors
        },
        frames = analysis["InputFrames"];
        n = Length[frames];
        regs = Range[n];
        next = n + 1;
        dims = Table[Lookup[sizes, frames[[k]]], {k, n}];

        (* 1.  Split and squeeze.  One reshape does both: splitting a composite
               and dropping a unit axis each preserve the element count, and
               ReshapeArray preserves element order, so the leftmost factor of a
               composite lands on the outermost axis. *)
        Do[
            If[ dims[[k]] =!= inputShapes[[k]],
                AppendTo[steps, indexEmit["Reshape", {regs[[k]]}, next, <||>, frames[[k]], dims[[k]]]];
                regs[[k]] = next++
            ],
            {k, n}
        ];

        (* 2.  Self-contraction.  A trace is taken before anything else touches
               the operand, so every frame is duplicate-free from here on and
               the merge and the contraction never see a repeated slot. *)
        traces = GroupBy[
            Cases[effects, KeyValuePattern["Effect" -> "SelfContracted"]],
            Function[effect, effect["Inputs"][[1, 1]]],
            Function[group, Sort[Map[Function[effect, Sort[effect["Inputs"][[All, 2]]]], group]]]
        ];
        Do[
            With[{pairs = Lookup[traces, k, {}]},
                If[ pairs =!= {},
                    dropped = List /@ Sort[Catenate[pairs]];
                    frames[[k]] = Delete[frames[[k]], dropped];
                    dims[[k]] = Delete[dims[[k]], dropped];
                    AppendTo[steps, indexEmit["Contract", {regs[[k]]}, next, <|"Groups" -> pairs|>, frames[[k]], dims[[k]]]];
                    regs[[k]] = next++
                ]
            ],
            {k, n}
        ];

        (* 3.  Merge.  Each member is broadcast to the axes it lacks, permuted
               into the merge frame and multiplied elementwise; the product
               takes the position of the first member and the others leave the
               operand list.  A contracted axis shared by exactly these operands
               now occupies a single slot, which the next pass sums. *)
        If[ merge =!= {},
            Do[
                spread = Select[mergeFrame, Function[id, ! MemberQ[frames[[k]], id]]];
                If[ spread =!= {},
                    factors = Lookup[sizes, spread];
                    frames[[k]] = Join[frames[[k]], spread];
                    dims[[k]] = Join[dims[[k]], factors];
                    AppendTo[steps, indexEmit["Broadcast", {regs[[k]]}, next, <|"Sizes" -> factors, "Axes" -> spread|>, frames[[k]], dims[[k]]]];
                    regs[[k]] = next++
                ];
                If[ frames[[k]] =!= mergeFrame,
                    AppendTo[steps, indexEmit["Transpose", {regs[[k]]}, next, <|"Permutation" -> indexGatherPermutation[frames[[k]], mergeFrame]|>, mergeFrame, Lookup[sizes, mergeFrame]]];
                    regs[[k]] = next++;
                    frames[[k]] = mergeFrame;
                    dims[[k]] = Lookup[sizes, mergeFrame]
                ],
                {k, merge}
            ];
            AppendTo[steps, indexEmit["Multiply", regs[[merge]], next, <||>, mergeFrame, Lookup[sizes, mergeFrame]]];
            regs[[First[merge]]] = next++;
            live = Delete[Range[n], List /@ Rest[merge]],
            live = Range[n]
        ];

        (* 4.  Contract.  The surviving tensors are numbered by concatenating
               their frames, and every axis the output does not carry becomes
               one ascending group of the slots that carry it: one slot is a
               sum, two an ordinary contraction, three or more the hyperedge a
               pairwise contractor cannot express.  A rank-0 operand is kept out
               of the product - a scalar contributes no slot to it - and
               multiplied back in afterwards. *)
        scalars = Select[live, Function[k, frames[[k]] === {}]];
        tensors = Select[live, Function[k, frames[[k]] =!= {}]];
        slotFrame = Catenate[frames[[tensors]]];
        slotDims = Catenate[dims[[tensors]]];
        groups = Map[
            Function[id, Flatten[Position[slotFrame, id]]],
            DeleteDuplicates[Select[slotFrame, Function[id, ! MemberQ[outFrame, id]]]]
        ];
        dropped = List /@ Sort[Catenate[groups]];
        resultFrame = Delete[slotFrame, dropped];
        resultDims = Delete[slotDims, dropped];
        Which[
            tensors === {},
                result = None,
            Length[tensors] === 1 && groups === {},
                result = regs[[First[tensors]]],
            True,
                AppendTo[steps, indexEmit["Contract", regs[[tensors]], next, <|"Groups" -> groups|>, resultFrame, resultDims]];
                result = next++
        ];
        If[ scalars =!= {},
            combine = If[result === None, regs[[scalars]], Prepend[regs[[scalars]], result]];
            If[ Length[combine] > 1,
                AppendTo[steps, indexEmit["Multiply", combine, next, <||>, resultFrame, resultDims]];
                result = next++,
                result = First[combine]
            ]
        ];

        (* 5.  Repeat the axes the output carries and no operand supplies.  This
               is genuine work: Wolfram arithmetic does not broadcast a size-1
               dimension, so the step cannot be elided. *)
        spread = Select[outFrame, Function[id, ! MemberQ[resultFrame, id]]];
        If[ spread =!= {},
            factors = Lookup[sizes, spread];
            resultFrame = Join[resultFrame, spread];
            resultDims = Join[resultDims, factors];
            AppendTo[steps, indexEmit["Broadcast", {result}, next, <|"Sizes" -> factors, "Axes" -> spread|>, resultFrame, resultDims]];
            result = next++
        ];

        (* 6.  Permute into the output order. *)
        If[ resultFrame =!= outFrame,
            AppendTo[steps, indexEmit["Transpose", {result}, next, <|"Permutation" -> indexGatherPermutation[resultFrame, outFrame]|>, outFrame, Lookup[sizes, outFrame]]];
            result = next++;
            resultFrame = outFrame;
            resultDims = Lookup[sizes, outFrame]
        ];

        (* 7.  Merge the output composites and insert the output unit axes.  The
               dimensions come from the solver, which multiplied each composite
               out while it was checking the operands. *)
        If[ resultDims =!= outDims,
            AppendTo[steps, indexEmit["Reshape", {result}, next, <||>, outFrame, outDims]];
            result = next++
        ];

        <|
            "Analysis" -> analysis,
            "Solved" -> solved,
            "Steps" -> steps,
            "Registers" -> next - 1,
            "Result" -> result,
            "InputDimensions" -> inputShapes,
            "OutputDimensions" -> outDims,
            "AxisSizes" -> sizes
        |>
    ]


(* === validity === *)

(* Total predicates, in the paclet's own idiom: a first clause that answers for
   a well-formed value and a catch-all that answers False, so the caller never
   has to guard the call. *)

indexDimensionsQ[dims_] := MatchQ[dims, {___Integer}] && AllTrue[dims, Positive]

indexPermutationQ[perm_] := MatchQ[perm, {___Integer}] && Sort[perm] === Range[Length[perm]]

(* A contraction group is ascending and duplicate-free, and no slot is in two
   groups: the slots of a group are levels of one tensor product, and a level
   contracted twice is not a level at all. *)
indexGroupsQ[groups_List] :=
    AllTrue[groups, Function[group, MatchQ[group, {__Integer}] && AllTrue[group, Positive] && OrderedQ[group] && DuplicateFreeQ[group]]] &&
        DuplicateFreeQ[Catenate[groups]]

indexGroupsQ[_] := False

indexStepQ[step_Association] :=
    And[
        MemberQ[{"Reshape", "Transpose", "Broadcast", "Multiply", "Contract"}, Lookup[step, "Step"]],
        MatchQ[Lookup[step, "Inputs"], {___Integer}],
        IntegerQ[Lookup[step, "Output"]],
        MatchQ[Lookup[step, "Frame"], {___Integer}],
        indexDimensionsQ[Lookup[step, "Dimensions"]],
        Switch[step["Step"],
            "Transpose", indexPermutationQ[Lookup[step, "Permutation"]],
            "Contract", indexGroupsQ[Lookup[step, "Groups"]],
            "Broadcast", indexDimensionsQ[Lookup[step, "Sizes"]] && MatchQ[Lookup[step, "Axes"], {__Integer}],
            _, True
        ]
    ]

indexStepQ[_] := False

(* The steps and the stage they were built from are both checked, because a plan
   object is a value a caller can hold and hand back: the steps say what runs and
   the solved descriptor says what they run on, and a plan carrying one without
   the other is declined here rather than half-executed. *)

indexPlanQ[plan_Association] :=
    With[{steps = Lookup[plan, "Steps"]},
        And[
            ContainsAll[Keys[plan],
                {"Analysis", "Solved", "Steps", "Registers", "Result", "InputDimensions", "OutputDimensions", "AxisSizes"}],
            indexSolvedQ[Lookup[plan, "Solved"]],
            ListQ[steps],
            AllTrue[steps, indexStepQ],
            DuplicateFreeQ[Map[Function[step, step["Output"]], steps]],
            AllTrue[steps, Function[step, AllTrue[step["Inputs"], Function[register, register < step["Output"]]]]],
            IntegerQ[Lookup[plan, "Registers"]],
            IntegerQ[Lookup[plan, "Result"]],
            ListQ[Lookup[plan, "InputDimensions"]],
            indexDimensionsQ[Lookup[plan, "OutputDimensions"]],
            AssociationQ[Lookup[plan, "AxisSizes"]]
        ]
    ]

indexPlanQ[_] := False
