Package["Wolfram`Arrays`"]

PackageScope[indexPlanExpression]
PackageScope[indexExecutePlan]


(* === the lowered expression ===

   An execution plan is a single-assignment register file whose registers are
   each read at most once, so the plan is a tree and renders to ONE nested
   expression: every step's expression is substituted straight into the step
   that reads it, and operand k is left standing as Slot[k].  This is the only
   place a step becomes an expression - indexExecutePlan releases the very value
   the "Expression" property shows, so the trace a caller inspects is what runs.

   The expression is assembled HELD, part by part, and that is not a formatting
   nicety.  ArrayTranspose has a generic clause that matches any first argument,
   so an unheld ArrayTranspose[Slot[1], perm] would evaluate to a Transpose of a
   Slot at the moment it was built, and the plan would render - and execute -
   something other than the step it stands for.  Building from held parts is also
   what lets a plan render with no operands at all, which is what makes
   "Expression" a property of ArrayIndexPlan rather than of a call.

   A pattern name is substituted into a held right-hand side, which is what lets
   these helpers place an already computed value inside a Hold without
   evaluating what is held beside it. *)

indexHeldValue[x_] := Hold[x]

indexHoldApply[h_, parts : {__Hold}] := Replace[Join @@ parts, Hold[args___] :> Hold[h[args]]]

indexSlotExpression[k_Integer] := Hold[Slot[k]]

indexOnesExpression[n_Integer] := Hold[ConstantArray[1, n]]


(* === one step, one primitive ===

   Every step lowers to a primitive this paclet already has and already
   dispatches on the tier of its operands; there is no array algorithm here.

   A contraction is built as an inactive TensorContract over an inactive
   TensorProduct and handed to ArrayMaterialize, NOT to ArrayContract, and the
   two reasons are independent.  ArrayContract's list form is guarded by
   ! AllTrue[arrays, ListQ], so an operand set of plain nested Lists falls
   through to the single-array clause and is reported as a ragged tensor; and
   the node form goes through SimplifyArray, whose singleton tensor-product rule
   maps INTO the product, so a contraction over SparseArray operands gives a
   list of sparse rows where a rank-2 SparseArray was asked for.  ArrayMaterialize
   runs the contractions-first Activate of Accessors.wl instead, which contracts
   the operands against each other without ever building the outer product and
   which keeps SparseArray structure, packed arrays and structured atoms.

   A group of one slot sums that slot, a group of two is an ordinary
   contraction, and a group of three or more is the generalized trace a
   hyperedge lowers to.  TensorContract takes all three, so a hyperedge needs no
   pairwise decomposition and the plan carries groups rather than pairs. *)

indexStepExpression[step : KeyValuePattern["Step" -> "Reshape"], {in_Hold}] :=
    indexHoldApply[ReshapeArray, {in, indexHeldValue[step["Dimensions"]]}]

indexStepExpression[step : KeyValuePattern["Step" -> "Transpose"], {in_Hold}] :=
    indexHoldApply[ArrayTranspose, {in, indexHeldValue[step["Permutation"]]}]

(* Broadcasting is a tensor product against a vector of ones, and it is genuine
   work rather than bookkeeping that could be elided: Wolfram arithmetic does
   not broadcast a length-1 dimension, so an operand missing an axis of the
   frame it is about to be multiplied into is expanded to the full extent.  The
   ones vector is left unevaluated inside the held expression, so the rendered
   plan names the extent it broadcasts to.

   The ones are integers, and the kernel's product of a packed Real or Complex
   operand with an integer vector comes back unpacked, so the product is passed
   through the plain form of Developer`ToPackedArray - the one form that never
   coerces a value, and that returns a SparseArray, an exact result and every
   other unpackable container exactly as the product made it.

   A RANK-0 register takes ConstantArray instead, and the step's own shape says
   when: the frame it writes is the frame it read plus the axes it spreads, so a
   frame as long as the size list is a frame that was empty.  The two spellings
   agree - a tensor product of a scalar with vectors of ones is that constant
   array - but the node form has no array leaf to classify, so it is neither a
   deferred tree nor an explicit container and ArrayMaterialize has nothing to
   materialize it as. *)
indexStepExpression[step : KeyValuePattern["Step" -> "Broadcast"], {in_Hold}] :=
    If[ Length[step["Frame"]] === Length[step["Sizes"]],
        indexHoldApply[ConstantArray, {in, indexHeldValue[step["Sizes"]]}],
        indexHoldApply[
            Developer`ToPackedArray,
            {
                indexHoldApply[
                    ArrayMaterialize,
                    {indexHoldApply[Inactive[TensorProduct], Join[{in}, Map[indexOnesExpression, step["Sizes"]]]]}
                ]
            }
        ]
    ]

(* The operands a merge multiplies have already been broadcast and transposed
   into one common frame, so the merge itself is ordinary elementwise
   arithmetic, which threads through SparseArray and packed operands natively.
   It is also the step no contraction node can express: a shared axis the output
   KEEPS is a diagonal, and TensorContract only sums. *)
indexStepExpression[KeyValuePattern["Step" -> "Multiply"], ins : {__Hold}] :=
    indexHoldApply[Times, ins]

indexStepExpression[step : KeyValuePattern["Step" -> "Contract"], ins : {__Hold}] :=
    indexHoldApply[
        ArrayMaterialize,
        {indexContractionNode[step["Groups"], indexHoldApply[Inactive[TensorProduct], ins]]}
    ]

(* With no group to sum, the step is the tensor product alone - the outer
   product of operands sharing no contracted axis.  Wrapping it in an empty
   TensorContract would be the same array, but it would put a node on the tree
   that SimplifyArray exists to take off again. *)

indexContractionNode[{}, product_Hold] := product

indexContractionNode[groups_List, product_Hold] :=
    indexHoldApply[Inactive[TensorContract], {product, indexHeldValue[groups]}]


(* Registers 1 .. n hold the operands as given and each step writes one fresh
   register, so the walk is a single forward pass: a step's expression is looked
   up by register and never rebuilt.  A plan with no steps leaves Hold[Slot[1]],
   which executes to the operand itself - the descriptor that asks for nothing
   copies nothing. *)

indexPlanExpression[plan_Association] := Module[{registers = <||>},
    Do[registers[k] = indexSlotExpression[k], {k, Length[plan["InputDimensions"]]}];
    Do[
        registers[step["Output"]] = indexStepExpression[step, Lookup[registers, step["Inputs"]]],
        {step, plan["Steps"]}
    ];
    registers[plan["Result"]]
]


(* === execution ===

   TensorProduct has no evaluation on the heads that are not ArrayQ, so a
   NumericArray, a Dataset or a Tabular handed straight to the node is not
   contracted at all: Activate turns the inactive product into a Times of the
   wrappers and the answer is lost with no message.  The operands that need
   materializing are exactly the explicit ones that are not ArrayQ, which is the
   nativelyContractibleQ rule ArrayContract applies to its own list form,
   restated here because the index layer builds its own inactive nodes rather
   than reaching that rule through ArrayContract.  A SparseArray and a packed
   List are ArrayQ and reach the steps with their container intact, which is the
   whole reason execution goes through these primitives.

   A TabularColumn is ArrayQ and passes that rule, and it is materialized all
   the same.  It is rank 1 by construction, so a broadcast, a split or any other
   step that raises the rank has no TabularColumn to hand back, while a merge
   that keeps the rank does - and the container a caller got would then depend
   on which steps the descriptor happened to emit.  opaqueWrapperQ is this
   paclet's own name for a wrapper with no native structural support, and it
   holds for every admitted wrapper except QuantityArray, whose unit the
   executor lifts below and whose container is therefore rebuildable at any
   rank. *)

indexNativeOperand[a_ ? opaqueWrapperQ] := ArrayMaterialize[a]

indexNativeOperand[a_] := If[! ArrayExplicitQ[a] || ArrayQ[a], a, ArrayMaterialize[a]]

(* A non-container operand is exempt from the join because it has no tier to
   contribute: a bare number is the rank-0 operand of a {} shape, and joining it
   in would report Missing["NotAContainer"] for an operand set that is otherwise
   explicit.  An operand set of nothing but scalars imposes no tier at all and
   is arithmetic, so it answers with the tier that admits it. *)

indexOperandTier[arrays_List] := With[{containers = Select[arrays, ArrayContainerQ]},
    If[containers === {}, "Explicit", arrayTierJoin[containers]]
]

(* === units are carried, not computed ===

   A QuantityArray is the one wrapper container that reaches a step, and the
   primitives disagree about it.  TensorContract keeps it and Times keeps it
   against another QuantityArray, but TensorProduct has no evaluation on the
   head at all and Times has none against a plain array, so a broadcast or a
   merge dropped the unit into the elements: a matrix product came back a
   QuantityArray and the batch form of the same descriptor came back a list of
   Quantity, and the container a caller got depended on which steps were
   emitted rather than on what was handed in.

   Repairing that per step would be one wrapper rule per primitive.  The
   descriptor-wide fact is stronger and needs one: with the sum-of-products
   combiner the plan is MULTILINEAR in its operands - a reshape, a transpose and
   a broadcast against ones are linear, a merge multiplies registers holding
   disjoint operands, and a contraction sums products - and registers 1..n are
   read once each, so the result scales by each operand's unit exactly once and
   no step depends on the units at all.  The unit is therefore lifted off the
   operands, the steps run on the magnitudes, which are the packed data the
   wrapper stores and cheaper to compute with than the Quantity elements the
   dropped wrapper produced, and the product of the units goes back on the
   result.  The held plan expression is unchanged and still what runs; what it
   runs on is the magnitudes.

   The product is formed by multiplying unit QUANTITIES rather than by rewriting
   unit expressions, so the kernel decides what Meters times Meters is, and a
   product of units that cancels is a plain number that scales the result and
   leaves it unwrapped.  A rank-0 result takes the same scaling and becomes an
   ordinary Quantity, there being no rank-0 QuantityArray.

   A QuantityArray may also carry a unit PER COLUMN, and then there is no single
   unit to lift: one such operand disables the lift for the whole set, the
   operands go to the steps as they stand, and the elements carry their own
   units. *)

indexOperandUnit[a_QuantityArray] := a["UnitBlock"]

indexOperandUnit[_] := None

indexUnitsOff[operands_List] := With[{units = Map[indexOperandUnit, operands]},
    If[ MemberQ[units, _List],
        {operands, {}},
        {MapThread[If[#2 === None, #1, QuantityMagnitude[#1]] &, {operands, units}], DeleteCases[units, None]}
    ]
]

indexUnitsOn[result_, {}] := result

indexUnitsOn[result_, units_List] := With[{scale = Times @@ Map[Quantity[1, #] &, units]},
    If[ MatchQ[scale, _Quantity] && ArrayDimensions[result] =!= {},
        QuantityArray[result, QuantityUnit[scale]],
        scale * result
    ]
]


(* The tier gate is a REFUSAL and not a materialization.  Each step in isolation
   would dispatch on its own operands - ArrayContract, ArrayTranspose and
   ReshapeArray all do - but a plan is a sequence, and the merge and broadcast
   steps have no form that keeps a lazy or symbolic operand lazy or symbolic
   across it.  Declining with a message leaves the caller the choice
   ArrayMaterialize gives them; materializing here would take it away, and
   silently.

   The arity refusal names ArrayIndexPlan rather than the executing symbol,
   because the mismatch is between the operands and the descriptor's input
   shapes and that is where the fix belongs; the tier refusal names the
   executing symbol, which is the one that promised the explicit tier.

   The dimensions are checked as well as the count, and that check is what makes
   a PREPARED plan safe to hand around.  A plan's steps carry the extents they
   were solved for - a reshape names its dimensions, a broadcast names its sizes
   - so executing one against operands of other dimensions does not fail, it
   quietly lowers to a different array.  A plan built by an executor is solved
   against the very operands it is about to run on and passes this trivially;
   one built by ArrayIndexPlan and reused is exactly where the check earns
   itself. *)

indexExecutePlan[plan_Association, arrays_List, sym_Symbol] := Module[{operands, tier, units},
    If[ Length[arrays] =!= Length[plan["InputDimensions"]],
        indexFail[
            ArrayIndexPlan,
            "operands",
            {Length[arrays], Length[plan["InputDimensions"]]},
            <|"Operands" -> Length[arrays], "InputShapes" -> Length[plan["InputDimensions"]]|>
        ]
    ];
    operands = Map[indexNativeOperand, unwrapArrayObjects[arrays]];
    Do[
        With[{dims = indexOperandDimensions[operands[[k]]], planned = plan["InputDimensions"][[k]]},
            If[ dims =!= planned,
                indexFail[
                    ArrayIndexPlan,
                    "dimensions",
                    {k, dims, planned},
                    <|"Operand" -> k, "Dimensions" -> dims, "PlanDimensions" -> planned|>
                ]
            ]
        ],
        {k, Length[operands]}
    ];
    tier = indexOperandTier[operands];
    If[tier =!= "Explicit", indexFail[sym, "tier", {tier}, <|"Tier" -> tier|>]];
    (* The tier is read off the operands as they were handed in, so the unit
       lift comes after the gate: it rewrites a QuantityArray into the array of
       its magnitudes, which is an explicit container whichever way the gate
       would have answered. *)
    {operands, units} = indexUnitsOff[operands];
    (* The operands are substituted into the held expression and the whole tree
       is released once.  ReplaceAll does not rescan what it inserts, so an
       operand that itself carries a Slot is left alone. *)
    indexUnitsOn[ReleaseHold[indexPlanExpression[plan] /. Slot[k_Integer] :> operands[[k]]], units]
]
