(* Tests for the execution half of the index-notation subsystem: ArrayIndexContract
   and ArrayIndexTransform on the explicit tier, the ArrayIndexPlan they accept in
   place of a descriptor, and the container the operands come back in.
   The value of every parity test is the value Wolfram/TensorNetworks'
   EinsteinSummation gives for the same call after ActivateTensors, taken from the
   acceptance corpus; the cases the design document's section 9 decides against
   reproducing carry "diverges" in their TestID and are checked against the design
   instead.  A corpus case written with Rule is spelled here with RuleDelayed,
   which is the canonical spelling of the same descriptor; the Rule spelling has
   its own section, since the message it carries is the point there.
   Run via Tests/RunTests.wls or TestReport. *)

Needs["Wolfram`Arrays`"]

(* === fixtures === *)

(* The corpus operands.  Small exact integers throughout, so a contraction is
   checked against an arithmetic truth rather than against a tolerance. *)
$a = {{1, 2, 3}, {4, 5, 6}}
$b = {{1, 0}, {0, 1}, {1, 1}}
$m = {{1, 2}, {3, 4}}
$id = {{1, 0}, {0, 1}}
$u = {{1, 0}, {1, 1}}
$w = {{2, 0}, {0, 3}}
$swap = {{0, 1}, {1, 0}}
$ones = {{1, 1}, {2, 2}}

$r3 = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}
$r4 = {{{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}, {{{9, 10}, {11, 12}}, {{13, 14}, {15, 16}}}}

$batchA = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}
$batchB = {{{1, 0}, {0, 1}}, {{2, 0}, {0, 2}}}

(* A 6x4 matrix whose entries are their own position, so a split, a merge and a
   permutation are each read off the answer rather than believed. *)
$grid = ArrayReshape[Range[24], {6, 4}]
$blocks = ArrayReshape[Range[24], {2, 3, 4}]

$sparseA = SparseArray[$a]
$sparseB = SparseArray[$b]
$packedA = Developer`ToPackedArray[N[$a]]
$packedB = Developer`ToPackedArray[N[$b]]
$numericA = NumericArray[$a, "Integer64"]
$numericB = NumericArray[$b, "Integer64"]
$quantity = QuantityArray[$m, "Meters"]
$quantityV = QuantityArray[{10, 20}, "Meters"]
$quantityBatch = QuantityArray[$batchA, "Meters"]

(* A QuantityArray may carry a unit per column rather than one unit, and then
   there is no single unit to lift off it. *)
$quantityMixed = QuantityArray[$m, {"Meters", "Seconds"}]

$symA = ArraySymbol["A", {2, 3}]
$symB = ArraySymbol["B", {3, 2}]

(* A genuinely lazy operand: an InterpolatingFunction applied to a free symbol,
   which is the lazy tier the paclet classifies rather than a stand-in for it. *)
$if = NDSolveValue[{iv'[iT] == {{0, 1}, {-1, 0}} . iv[iT], iv[0] == {1., 0.}}, iv, {iT, 0, 1}]
$lazy = $if[iTau]
$lazy2 = Piecewise[{{{{1., 2.}, {3., 4.}}, iZ < 0}}, {{5., 6.}, {7., 8.}}]


BeginTestSection["indexcontract - einsum parity, contraction"]

VerificationTest[
    ArrayIndexContract["ij,jk->ik", {$a, $b}],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-01-matrix-multiply-string"
]

VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}} :> {{i, k}}, {$a, $b}],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-02-matrix-multiply-shapes"
]

(* No output shape given: ArrayIndexContract defaults to the axes occurring
   exactly once, which is EinsteinSummation's Automatic output. *)
VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}}, {$a, $b}],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-03-matrix-multiply-default-output"
]

VerificationTest[
    ArrayIndexContract["ij,jk", {$a, $b}],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-05-matrix-multiply-string-no-arrow"
]

VerificationTest[
    ArrayIndexContract["ii", {$m}],
    5,
    TestID -> "indexcontract-07-trace-string"
]

VerificationTest[
    ArrayIndexContract[{{i, i}}, {$m}],
    5,
    TestID -> "indexcontract-08-trace-default-output"
]

VerificationTest[
    ArrayIndexContract[{{i, i}} :> {{}}, {$m}],
    5,
    TestID -> "indexcontract-09-trace-empty-output"
]

(* Sum over j of $r4[[i, j, k, j]]: 1 + 6 = 7 and 3 + 8 = 11 in the first row. *)
VerificationTest[
    ArrayIndexContract[{{i, j, k, j}}, {$r4}],
    {{7, 11}, {23, 27}},
    TestID -> "indexcontract-10-partial-trace"
]

VerificationTest[
    ArrayIndexContract[{{i, j, i, j}}, {$r4}],
    34,
    TestID -> "indexcontract-11-double-trace"
]

VerificationTest[
    ArrayIndexContract["iij", {$r3}],
    {8, 10},
    TestID -> "indexcontract-12-self-contraction-with-free-axis"
]

VerificationTest[
    ArrayIndexContract["ij->ji", {$a}],
    {{1, 4}, {2, 5}, {3, 6}},
    TestID -> "indexcontract-14-transpose-string"
]

VerificationTest[
    ArrayIndexContract[{{i, j, k}} :> {{k, i, j}}, {$r3}],
    {{{1, 3}, {5, 7}}, {{2, 4}, {6, 8}}},
    TestID -> "indexcontract-16-rank3-permutation"
]

VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}} :> {{k, i}}, {$a, $b}],
    {{4, 10}, {5, 11}},
    TestID -> "indexcontract-17-product-then-permute"
]

VerificationTest[
    ArrayIndexContract["ij", {$a}],
    {{1, 2, 3}, {4, 5, 6}},
    TestID -> "indexcontract-18-identity-single-operand"
]

VerificationTest[
    ArrayIndexContract["i,j->ij", {{1, 2, 3}, {4, 5}}],
    {{4, 5}, {8, 10}, {12, 15}},
    TestID -> "indexcontract-19-outer-product"
]

VerificationTest[
    ArrayIndexContract["i,j", {{1, 2, 3}, {4, 5}}],
    {{4, 5}, {8, 10}, {12, 15}},
    TestID -> "indexcontract-20-outer-product-default-output"
]

VerificationTest[
    ArrayIndexContract["i,i", {{1, 2, 3}, {4, 5, 6}}],
    32,
    TestID -> "indexcontract-21-inner-product"
]

VerificationTest[
    ArrayIndexContract[{{i}, {i}} :> {{}}, {{1, 2, 3}, {4, 5, 6}}],
    32,
    TestID -> "indexcontract-22-inner-product-empty-output"
]

(* An axis dropped from an explicit output is summed, with no target bracket
   anywhere: this is the reading "Targeting" -> False recovers exactly. *)
VerificationTest[
    ArrayIndexContract[{{i}} :> {{}}, {{1, 2, 3}}],
    6,
    TestID -> "indexcontract-23-vector-sum"
]

VerificationTest[
    ArrayIndexContract[{{i, j}} :> {{}}, {$a}],
    21,
    TestID -> "indexcontract-24-matrix-full-sum"
]

VerificationTest[
    ArrayIndexContract["bij,bjk->bik", {$batchA, $batchB}],
    {{{1, 2}, {3, 4}}, {{10, 12}, {14, 16}}},
    TestID -> "indexcontract-26-batch-matrix-multiply-string"
]

VerificationTest[
    ArrayIndexContract[{{b, i, j}, {b, j, k}} :> {{b, i, k}}, {$batchA, $batchB}],
    {{{1, 2}, {3, 4}}, {{10, 12}, {14, 16}}},
    TestID -> "indexcontract-27-batch-matrix-multiply-shapes"
]

(* The default output is the axes occurring exactly once, so the batch axis b is
   summed rather than carried: batching needs the explicit output above. *)
VerificationTest[
    ArrayIndexContract["bij,bjk", {$batchA, $batchB}],
    {{11, 14}, {17, 20}},
    TestID -> "indexcontract-28-batch-axis-is-contracted-by-default"
]

VerificationTest[
    ArrayIndexContract["ij,jk,kl->il", {$m, $u, $w}],
    {{6, 6}, {14, 12}},
    TestID -> "indexcontract-30-three-operand-chain"
]

VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}, {k, l}}, {$m, $u, $w}],
    {{6, 6}, {14, 12}},
    TestID -> "indexcontract-31-three-operand-chain-default-output"
]

VerificationTest[
    ArrayIndexContract["i,ij,j", {{1, 2}, $m, {1, 2}}],
    27,
    TestID -> "indexcontract-32-quadratic-form"
]

VerificationTest[
    ArrayIndexContract["ij,jk,kl,li", {$m, $u, $w, $swap}],
    20,
    TestID -> "indexcontract-33-ring-of-four-matrices"
]

VerificationTest[
    ArrayIndexContract[{{}, {i, j}}, {3, $m}],
    {{3, 6}, {9, 12}},
    TestID -> "indexcontract-34-scalar-operand"
]

VerificationTest[
    ArrayIndexContract[{{}, {i, j}, {j, k}} :> {{i, k}}, {2, $a, $b}],
    {{8, 10}, {20, 22}},
    TestID -> "indexcontract-35-scalar-operand-with-contraction"
]

VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}} :> {{i}}, {$a, $b}],
    {9, 21},
    TestID -> "indexcontract-38-free-axis-dropped-from-output"
]

VerificationTest[
    ArrayIndexContract[{{i}, {j}, {j, k}} :> {{i}}, {{1, 2}, {1, 1}, $m}],
    {10, 20},
    TestID -> "indexcontract-39-outer-then-contract-one-axis-dropped"
]

(* An axis on three operands: one three-slot contraction group, which is the
   generalized trace TensorContract already takes. *)
VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}, {j, l}} :> {{i, k, l}}, {$m, $id, $ones}],
    {{{1, 1}, {4, 4}}, {{3, 3}, {8, 8}}},
    TestID -> "indexcontract-40-hyperedge-contracted"
]

VerificationTest[
    ArrayIndexContract[{{i, j}, {j}, {j}} :> {{i, j}}, {$m, {10, 20}, {1, 2}}],
    {{10, 80}, {30, 160}},
    TestID -> "indexcontract-41-hyperedge-kept-on-output"
]

VerificationTest[
    ArrayIndexContract["ij,jk,jl->ikl", {$m, $id, $ones}],
    {{{1, 1}, {4, 4}}, {{3, 3}, {8, 8}}},
    TestID -> "indexcontract-42-hyperedge-contracted-string"
]

VerificationTest[
    ArrayIndexContract["ij,j->ij", {$a, {10, 20, 30}}],
    {{10, 40, 90}, {40, 100, 180}},
    TestID -> "indexcontract-43-column-scaling"
]

VerificationTest[
    ArrayIndexContract[{{i, j}, {i}} :> {{i, j}}, {$a, {10, 20}}],
    {{10, 20, 30}, {80, 100, 120}},
    TestID -> "indexcontract-44-row-scaling"
]

VerificationTest[
    ArrayIndexContract["ij,ij->ij", {$m, {{10, 20}, {30, 40}}}],
    {{10, 40}, {90, 160}},
    TestID -> "indexcontract-45-hadamard-product"
]

(* The default output takes the once-only axes in first-occurrence order rather
   than sorted, so the surviving order here is {k, i} and the answer is $m. *)
VerificationTest[
    ArrayIndexContract[{{k, j}, {j, i}}, {$m, $id}],
    {{1, 2}, {3, 4}},
    TestID -> "indexcontract-72-default-output-is-first-occurrence-order"
]

(* The result is a value, not a tree waiting for activation. *)
VerificationTest[
    Activate[ArrayIndexContract["ij,jk->ik", {$a, $b}]],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-76-result-needs-no-activation"
]

EndTestSection[]


BeginTestSection["indexcontract - batch indices"]

(* An axis two or more operands share and the output KEEPS is a batch index, a
   diagonal no contraction group spells, since a group only sums.  It is a delta
   among the operands of the contraction: one slot tied to each occurrence and
   one left free to carry the axis to the output.  These are the IndexedMultiply
   cases of the corpus. *)

VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}} :> {{i, j, k}}, {{{1, 1}, {3, 2}}, {{1, 0, 1}, {0, 2, 2}}}],
    {{{1, 0, 1}, {0, 2, 2}}, {{3, 0, 3}, {0, 4, 4}}},
    TestID -> "indexcontract-55-merge-shared-axis-kept"
]

VerificationTest[
    ArrayIndexContract[{{i, j}, {j}} :> {{i, j}}, {{{10, 20, 30}, {40, 50, 60}}, {1, 10, 100}}],
    {{10, 200, 3000}, {40, 500, 6000}},
    TestID -> "indexcontract-56-merge-column-scaling"
]

VerificationTest[
    ArrayIndexContract[{{i}, {j}} :> {{i, j}}, {{10, 20}, {1, 2, 3}}],
    {{10, 20, 30}, {20, 40, 60}},
    TestID -> "indexcontract-57-merge-disjoint-axes"
]

VerificationTest[
    ArrayIndexContract[{{i, j}, {i}, {j}} :> {{i, j}}, {$m, {10, 20}, {100, 200}}],
    {{1000, 4000}, {6000, 16000}},
    TestID -> "indexcontract-58-merge-three-operands-partial-overlap"
]

VerificationTest[
    ArrayIndexContract[{{i, j}, {j}, {k}} :> {{i, j, k}}, {$m, {10, 20}, {100, 200, 300}}],
    {{{1000, 2000, 3000}, {4000, 8000, 12000}}, {{3000, 6000, 9000}, {8000, 16000, 24000}}},
    TestID -> "indexcontract-64-every-operand-carrying-an-output-axis-merges"
]

(* The third operand carries no output axis, so it stays out of the merge and
   contracts against the merged tensor afterwards: trace($m) = 5 scales it. *)
VerificationTest[
    ArrayIndexContract[{{i, j}, {j}, {k, k}} :> {{i, j}}, {$m, {10, 20}, $m}],
    {{50, 200}, {150, 400}},
    TestID -> "indexcontract-65-operand-outside-the-merge-contracts-after"
]

VerificationTest[
    ArrayIndexContract[{{k}, {i, j}, {j}} :> {{i, j}}, {{1, 1, 1}, $m, {10, 20}}],
    {{30, 120}, {90, 240}},
    TestID -> "indexcontract-66-merge-order-is-independent-of-operand-order"
]

(* The plan writes the batch index as an INACTIVE delta before the operands:
   the evaluator unpacks a packed array beside an active one, and ArrayContract
   takes the inactive delta as the one it activates to.  The delta's free slot
   leads the result, so a batch product comes out in its own layout with no
   transpose, and no broadcast and no elementwise multiply is emitted. *)
VerificationTest[
    With[{plan = ArrayIndexPlan["bij,bjk->bik", {{2, 2, 3}, {2, 3, 4}}]},
        {
            plan["Expression"],
            Map[#["Step"] &, plan["Steps"]]
        }
    ],
    {
        Function[ArrayContract[
            Inactive[TensorProduct][Inactive[SymbolicDeltaProductArray][{2, 2, 2}, {{1, 2, 3}}], #1, #2],
            {{1, 4}, {2, 7}, {6, 8}}
        ]],
        {"Contract"}
    },
    TestID -> "indexcontract-batch-index-is-an-inactive-delta"
]

(* A batch index costs what the result costs.  The batch product of 4 slices of
   256 x 64 against 64 x 256 has a result of 262144 reals, 2MB; aligning the
   operands into one frame and multiplying them elementwise builds their outer
   product per slice, 16777216 reals, 134MB, before anything is summed. *)
VerificationTest[
    BlockRandom[
        SeedRandom[3];
        With[{x = RandomReal[1, {4, 256, 64}], y = RandomReal[1, {4, 64, 256}]},
            {
                MaxMemoryUsed[ArrayIndexContract["bij,bjk->bik", {x, y}]] < 3*^7,
                Max[Abs[ArrayIndexContract["bij,bjk->bik", {x, y}] - MapThread[Dot, {x, y}]]] < 10^-10
            }
        ]
    ],
    {True, True},
    TestID -> "indexcontract-batch-index-costs-the-result"
]

EndTestSection[]


BeginTestSection["indexcontract - Rule spelling"]

(* RuleDelayed is canonical because it holds the output shapes.  Rule evaluates
   both sides before the descriptor is read, so it is accepted with a message
   saying so - which is what keeps the classic einsum call sites working. *)

VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}} -> {{i, k}}, {$a, $b}],
    {{4, 5}, {10, 11}},
    {ArrayIndexPattern::rule},
    TestID -> "indexcontract-02-rule-spelling-warns"
]

(* A one-sided output shape stands for a list of one shape, which is how the
   classic einsum index-list form spells its output. *)
VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}} -> {i, k}, {$a, $b}],
    {{4, 5}, {10, 11}},
    {ArrayIndexPattern::rule},
    TestID -> "indexcontract-02-bare-output-shape-sugar"
]

VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}} -> Automatic, {$a, $b}],
    {{4, 5}, {10, 11}},
    {ArrayIndexPattern::rule},
    TestID -> "indexcontract-04-automatic-output-on-the-right-of-a-rule"
]

VerificationTest[
    ArrayIndexContract[{{i}} -> {}, {{1, 2, 3}}],
    6,
    {ArrayIndexPattern::rule},
    TestID -> "indexcontract-23-rule-spelling-empty-output"
]

VerificationTest[
    ArrayIndexContract[{{b, i, j}, {b, j, k}} -> {b, i, k}, {$batchA, $batchB}],
    {{{1, 2}, {3, 4}}, {{10, 12}, {14, 16}}},
    {ArrayIndexPattern::rule},
    TestID -> "indexcontract-27-rule-spelling-batch-matrix-multiply"
]

EndTestSection[]


BeginTestSection["indexcontract - refusals shared with einsum"]

(* Both surfaces refuse these; only the message differs. *)

VerificationTest[
    Head[ArrayIndexContract["ij,jk->ik", {$a, $id}]],
    ArrayIndexContract,
    {ArrayIndexPlan::conflict},
    TestID -> "indexcontract-46-mismatched-contracted-extents"
]

VerificationTest[
    Head[ArrayIndexContract[{{i, j}, {j, k}}, {$m}]],
    ArrayIndexContract,
    {ArrayIndexPlan::operands},
    TestID -> "indexcontract-52-operand-count-mismatch"
]

VerificationTest[
    Head[ArrayIndexContract[{{i, j}}, {{1, 2, 3}}]],
    ArrayIndexContract,
    {ArrayIndexPlan::rank},
    TestID -> "indexcontract-53-shape-does-not-match-operand-rank"
]

VerificationTest[
    Head[ArrayIndexContract[{{i, j}, {j, k}} :> {{i, l}}, {$m, $id}]],
    ArrayIndexContract,
    {ArrayIndexPlan::unresolved},
    TestID -> "indexcontract-54-output-axis-no-operand-carries"
]

VerificationTest[
    Head[ArrayIndexContract[{{i, j}} :> {{i, j}}, {{1, 2, 3}}]],
    ArrayIndexContract,
    {ArrayIndexPlan::rank},
    TestID -> "indexcontract-62-merge-shape-does-not-match-operand-rank"
]

EndTestSection[]


BeginTestSection["indexcontract - deliberate divergences from einsum"]

(* Design section 9 row 4.  EinsteinSummation reads "ii->i" as "delete one i from
   the multiset and contract what is left" and answers with the row sums {3, 7};
   a repeated axis here is a trace, and the diagonal has no lowering. *)
VerificationTest[
    Head[ArrayIndexContract["ii->i", {$m}]],
    ArrayIndexContract,
    {ArrayIndexPlan::diagonal},
    TestID -> "indexcontract-13-diverges-diagonal-keep-declined"
]

(* Design section 4.  EinsteinSummation's StringSplit drops the empty trailing
   segment, so "ij->" silently becomes the identity; the grammar here reads the
   empty segment as an empty output shape, which is the full sum. *)
VerificationTest[
    ArrayIndexContract["ij->", {$a}],
    21,
    TestID -> "indexcontract-25-diverges-empty-string-output-is-a-scalar"
]

(* Design section 9 row 7.  An all-scalar call leaves EinsteinSummation a stray
   inactive TensorProduct factor; a scalar is the {} shape and the alignment core
   multiplies it back in. *)
VerificationTest[
    ArrayIndexContract[{{}, {}}, {5, 7}],
    35,
    TestID -> "indexcontract-36-diverges-all-scalar-operands"
]

(* Design section 4.  A leading empty segment is a scalar operand, where
   EinsteinSummation fails on operand count because StringSplit drops it. *)
VerificationTest[
    ArrayIndexContract[",ij", {3, $m}],
    {{3, 6}, {9, 12}},
    TestID -> "indexcontract-37-diverges-scalar-operand-in-the-string-dialect"
]

(* Design section 9 row 2.  IndexedMultiply pads the short operand with the
   multiplicative identity and passes the surplus entry through unchanged; one
   axis takes one size, so the conflict is named. *)
VerificationTest[
    Head[ArrayIndexContract[{{i, j}, {j}} :> {{i, j}}, {$a, {10, 20, 30, 40}}]],
    ArrayIndexContract,
    {ArrayIndexPlan::conflict},
    TestID -> "indexcontract-47-diverges-padding-on-a-kept-axis"
]

VerificationTest[
    Head[ArrayIndexContract[{{i, j}, {i, j}} :> {{i, j}},
        {$m, {{10, 20, 30}, {40, 50, 60}, {70, 80, 90}}}]],
    ArrayIndexContract,
    {ArrayIndexPlan::conflict},
    TestID -> "indexcontract-48-diverges-padding-on-both-operands"
]

(* Design section 9 row 3.  A repeated output axis is EinsteinSummation's
   GeneralizedPower tensor power; it names no layout and is declined. *)
VerificationTest[
    Head[ArrayIndexContract[{{i}} :> {{i, i}}, {{1, 2, 3}}]],
    ArrayIndexContract,
    {ArrayIndexPattern::duplicate},
    TestID -> "indexcontract-49-diverges-repeated-output-axis-on-a-vector"
]

VerificationTest[
    Head[ArrayIndexContract[{{i, j}} :> {{i, j, i, j}}, {$m}]],
    ArrayIndexContract,
    {ArrayIndexPattern::duplicate},
    TestID -> "indexcontract-50-diverges-repeated-output-axes-on-a-matrix"
]

VerificationTest[
    Head[ArrayIndexContract[{{i, j}, {j}} :> {{i, i}}, {$m, {1, 1}}]],
    ArrayIndexContract,
    {ArrayIndexPattern::duplicate},
    TestID -> "indexcontract-51-diverges-multiplicity-over-a-contraction"
]

(* Design section 9 row 3.  IndexedMultiply keeps a within-operand repeat as two
   axes; written as a descriptor that is a repeated output axis. *)
VerificationTest[
    Head[ArrayIndexContract[{{i, i}} :> {{i, i}}, {$m}]],
    ArrayIndexContract,
    {ArrayIndexPattern::duplicate},
    TestID -> "indexcontract-59-diverges-within-operand-repeat-kept-as-two-axes"
]

VerificationTest[
    Head[ArrayIndexContract[{{i}} :> {{i, i, i}}, {{1, 2}}]],
    ArrayIndexContract,
    {ArrayIndexPattern::duplicate},
    TestID -> "indexcontract-74-diverges-multiplicity-three"
]

VerificationTest[
    Head[ArrayIndexContract[{{i, j}} :> {{i, i, i, j}}, {$m}]],
    ArrayIndexContract,
    {ArrayIndexPattern::duplicate},
    TestID -> "indexcontract-75-diverges-multiplicity-raises-every-axis"
]

VerificationTest[
    Head[ArrayIndexContract[{{i, j}} :> {{i, i, j, j}}, {$m}]],
    ArrayIndexContract,
    {ArrayIndexPattern::duplicate},
    TestID -> "indexcontract-69-diverges-interleaved-repeated-output-axes"
]

(* The corpus reaches GeneralizedPower through plain Activate as well; the
   descriptor is declined before any tree is built, so there is nothing to
   activate. *)
VerificationTest[
    Head[Activate[ArrayIndexContract[{{i}} :> {{i, i}}, {{1, 2, 3}}]]],
    ArrayIndexContract,
    {ArrayIndexPattern::duplicate},
    TestID -> "indexcontract-77-diverges-repeated-output-axis-under-activate"
]

(* Design section 9 row 2.  IndexedMultiply pads the shorter operand with 1s. *)
VerificationTest[
    Head[ArrayIndexContract[{{j}, {j}} :> {{j}}, {{1, 2}, {10, 20, 30}}]],
    ArrayIndexContract,
    {ArrayIndexPlan::conflict},
    TestID -> "indexcontract-60-diverges-shared-axis-with-different-extents"
]

VerificationTest[
    Head[ArrayIndexContract[{{i, j}, {i}} :> {{i, j}}, {$a, {10, 20, 30, 40}}]],
    ArrayIndexContract,
    {ArrayIndexPlan::conflict},
    TestID -> "indexcontract-61-diverges-absent-axis-broadcast-and-padded"
]

(* Design section 9 row 4.  EinsteinSummation fuses a within-operand repeat with
   a cross-operand occurrence into one three-slot group; a trace takes exactly
   two occurrences and none elsewhere. *)
VerificationTest[
    Head[ArrayIndexContract[{{i, i}, {i, k}}, {$m, $id}]],
    ArrayIndexContract,
    {ArrayIndexPlan::occurrences},
    TestID -> "indexcontract-67-diverges-three-occurrences-of-one-axis"
]

(* Design section 9 row 10.  EinsteinSummation falls through to FindPermutation on
   unrelated lists and returns an unevaluated Transpose after three system
   messages; an output-only axis is a broadcast, and with no size for k the axis
   is named. *)
VerificationTest[
    Head[ArrayIndexContract[{{i, j}} :> {{j, i, k}}, {$m}]],
    ArrayIndexContract,
    {ArrayIndexPlan::unresolved},
    TestID -> "indexcontract-68-diverges-output-only-axis-with-no-size"
]

(* An operand argument that is not a List stands for one operand, where
   EinsteinSummation leaks a file-private symbol into its result. *)
VerificationTest[
    ArrayIndexContract[{{i, j}}, $symA],
    $symA,
    TestID -> "indexcontract-71-diverges-non-list-operand-argument"
]

(* Design section 4.1.  A string containing a space is tokenized by identifier, so
   "ij" here is one axis against a rank-2 operand rather than the two characters
   EinsteinSummation splits it into. *)
VerificationTest[
    Head[ArrayIndexContract["ij, jk->ik", {$a, $b}]],
    ArrayIndexContract,
    {ArrayIndexPlan::rank},
    TestID -> "indexcontract-73-diverges-space-selects-the-identifier-dialect"
]

(* The identifier spelling of the same contraction: one axis per identifier. *)
VerificationTest[
    ArrayIndexContract["i j, j k -> i k", {$a, $b}],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-73-identifier-dialect-matrix-multiply"
]

EndTestSection[]


BeginTestSection["indexcontract - einsum compatibility options"]

(* The divergences above are the defaults, and two options turn the first two
   into EinsteinSummation's own readings, which is what lets EinsteinSummation
   be a thin wrapper.  Every expected value is the one EinsteinSummation with
   ActivateTensors gives for the same call, its GeneralizedPower written out as
   the tensor product of its copies. *)

(* "DimensionMismatch" -> "Pad" is IndexedMultiply's rule: an axis takes the
   largest size an operand gives it, an extent of 1 is repeated, and any other
   shorter extent is padded at the end with 1s, the surplus passing through. *)
VerificationTest[
    {
        ArrayIndexContract[{{i, j}, {j}} :> {{i, j}}, {$a, {10, 20, 30, 40}}, "DimensionMismatch" -> "Pad"],
        ArrayIndexContract[{{i, j}, {i, j}} :> {{i, j}}, {$m, {{10, 20, 30}, {40, 50, 60}, {70, 80, 90}}}, "DimensionMismatch" -> "Pad"],
        ArrayIndexContract[{{j}, {j}} :> {{j}}, {{1, 2}, {10, 20, 30}}, "DimensionMismatch" -> "Pad"],
        ArrayIndexContract["i,i->i", {{5}, {3, 4, 5}}, "DimensionMismatch" -> "Pad"],
        ArrayIndexContract["ij,ij->i", {$m, {{1, 2, 3}, {4, 5, 6}}}, "DimensionMismatch" -> "Pad"]
    },
    {
        {{10, 40, 90, 40}, {40, 100, 180, 40}},
        {{10, 40, 30}, {120, 200, 60}, {70, 80, 90}},
        {10, 40, 30},
        {15, 20, 25},
        {8, 38}
    },
    TestID -> "indexcontract-padding-is-indexedmultiplys-rule"
]

(* The padding is a step of its own in the plan, a PadArray, which keeps a
   symbolic operand inert. *)
VerificationTest[
    With[{plan = ArrayIndexPlan["i,i->i", {{2}, {3}}, "DimensionMismatch" -> "Pad"]},
        {
            Map[#["Step"] &, plan["Steps"]],
            ArrayDimensions[ArrayIndexContract["i,i->i", {VectorSymbol["v", 2], {3, 4, 5}}, "DimensionMismatch" -> "Pad"]]
        }
    ],
    {{"Pad", "Contract"}, {3}},
    TestID -> "indexcontract-padding-is-a-step-and-keeps-the-tier"
]

(* "IndexMultiplicity" -> True reads a repeated output axis as a tensor power of
   the contraction with each output axis once: the r-th occurrence of an axis
   from the r-th copy, and an axis's slots in the copies past its own count
   summed together. *)
VerificationTest[
    {
        ArrayIndexContract[{{i}} :> {{i, i}}, {{1, 2, 3}}, "IndexMultiplicity" -> True],
        ArrayIndexContract[{{i, j}} :> {{i, j, i, j}}, {$m}, "IndexMultiplicity" -> True],
        ArrayIndexContract[{{i, j}, {j}} :> {{i, i}}, {$m, {1, 1}}, "IndexMultiplicity" -> True],
        ArrayIndexContract[{{i}} :> {{i, i, i}}, {{1, 2}}, "IndexMultiplicity" -> True],
        ArrayIndexContract[{{i, j}} :> {{i, i, i, j}}, {$m}, "IndexMultiplicity" -> True],
        ArrayIndexContract[{{i, j}} :> {{i, i, j, j}}, {$m}, "IndexMultiplicity" -> True],
        ArrayIndexContract["i,i->ii", {{1, 2}, {3, 4}}, "IndexMultiplicity" -> True]
    },
    {
        {{1, 2, 3}, {2, 4, 6}, {3, 6, 9}},
        {{{{1, 2}, {3, 4}}, {{2, 4}, {6, 8}}}, {{{3, 6}, {9, 12}}, {{4, 8}, {12, 16}}}},
        {{9, 21}, {21, 49}},
        {{{1, 2}, {2, 4}}, {{2, 4}, {4, 8}}},
        {{{{5, 10}, {11, 22}}, {{11, 22}, {25, 50}}}, {{{15, 20}, {33, 44}}, {{33, 44}, {75, 100}}}},
        {{{{1, 2}, {2, 4}}, {{3, 4}, {6, 8}}}, {{{3, 6}, {4, 8}}, {{9, 12}, {12, 16}}}},
        {{9, 24}, {24, 64}}
    },
    TestID -> "indexcontract-multiplicity-is-einsteinsummations-tensor-power"
]

(* The power keeps the tier: over a symbolic vector it is the inert product of
   two copies, of the squared dimensions. *)
VerificationTest[
    With[{power = ArrayIndexContract["i->ii", {VectorSymbol["v", 3]}, "IndexMultiplicity" -> True]},
        {ArraySymbolicQ[power], ArrayDimensions[power]}
    ],
    {True, {3, 3}},
    TestID -> "indexcontract-multiplicity-keeps-the-tier"
]

(* What the option does not reach: an axis repeated inside an output composite
   has no copy to read, and an axis repeated within one operand and kept is the
   diagonal still, where EinsteinSummation keeps the two occurrences as two
   axes. *)
VerificationTest[
    {
        Head[ArrayIndexContract["i -> (i i)", {{1, 2}}, "IndexMultiplicity" -> True]],
        Head[ArrayIndexContract[{{i, i}} :> {{i, i}}, {$m}, "IndexMultiplicity" -> True]]
    },
    {ArrayIndexContract, ArrayIndexContract},
    {ArrayIndexPattern::duplicate, ArrayIndexPlan::diagonal},
    TestID -> "indexcontract-multiplicity-leaves-composites-and-diagonals-declined"
]

(* Both settings are compiled into the descriptor, so a prepared object carries
   them and is declined them, as it is "Targeting". *)
VerificationTest[
    With[{pattern = ArrayIndexPattern["i->ii", "IndexMultiplicity" -> True]},
        {
            ArrayIndexContract[pattern, {{1, 2}}],
            Head[ArrayIndexContract[pattern, {{1, 2}}, "DimensionMismatch" -> "Pad"]]
        }
    ],
    {{{1, 2}, {2, 4}}, ArrayIndexContract},
    {ArrayIndexPattern::prepared},
    TestID -> "indexcontract-compatibility-options-travel-with-a-prepared-object"
]

(* "Inactive" -> True gives the plan's tree unevaluated, in the heads the
   paclet's structural vocabulary shapes: every node has the result's
   dimensions, a rank-0 result included, and ArrayMaterialize computes the eager
   result, activating the contractions before the products they contract.  A
   plain Activate does as well where the tree holds no delta; over a batch index
   it builds the product first and reads the delta in it as a scalar. *)
VerificationTest[
    Module[{check},
        check[desc_, ops_, opts___] := With[{tree = ArrayIndexContract[desc, ops, "Inactive" -> True, opts], eager = ArrayIndexContract[desc, ops, opts]},
            {
                ArrayDimensions[tree] === Dimensions[eager],
                ArrayMaterialize[tree] === eager,
                ! FreeQ[tree, SymbolicDeltaProductArray] || Activate[tree] === eager
            }
        ];
        Union @ Flatten @ {
            check["ij,jk->ik", {$a, $b}],
            check["bij,bjk->bik", {$batchA, $batchB}],
            check["ij,ij->", {$m, $m}],
            check["ii->", {$m}],
            check["ij,->ij", {$m, 3}],
            check["ib,jb,kb->ijkb", {$m, $m, $m}],
            check["i->ii", {{1, 2}}, "IndexMultiplicity" -> True],
            check["i,i->i", {{1, 2}, {3, 4, 5}}, "DimensionMismatch" -> "Pad"]
        }
    ],
    {True},
    TestID -> "indexcontract-inactive-tree-has-the-shape-and-the-value"
]

VerificationTest[
    ArrayIndexContract["bij,bjk->bik", {$batchA, $batchB}, "Inactive" -> True],
    Inactive[ArrayContract][
        Inactive[TensorProduct][SymbolicDeltaProductArray[{2, 2, 2}, {{1, 2, 3}}], $batchA, $batchB],
        {{1, 4}, {2, 7}, {6, 8}}
    ],
    TestID -> "indexcontract-inactive-tree-heads"
]

(* An inactive tree over a symbolic operand is a symbolic container, and over a
   deferred tree it nests that tree as a leaf rather than computing it. *)
VerificationTest[
    With[{deferred = Inactive[TensorContract][Inactive[TensorProduct][$m, $m], {{2, 3}}]},
        {
            ArraySymbolicQ[ArrayIndexContract["ij,jk->ik", {$symA, $symB}, "Inactive" -> True]],
            FreeQ[ArrayIndexContract["ij,jk->ik", {deferred, $m}, "Inactive" -> True], deferred],
            ArrayMaterialize[ArrayIndexContract["ij,jk->ik", {deferred, $m}, "Inactive" -> True]]
        }
    ],
    {True, False, $m . $m . $m},
    TestID -> "indexcontract-inactive-tree-keeps-symbols-and-deferred-trees"
]

EndTestSection[]


(* A contraction that consumes every slot of some operands leaves those operands
   as a rank-0 factor of the residual tensor product, and TensorProduct[x, 0] is
   0 whatever the rank of x.  A scalar factor scales, so the free operands keep
   their dimensions and a zero result is a zero ARRAY of the output shape. *)

VerificationTest[
    {
        ArrayIndexContract["a, d -> a", {{-1, -1, 0}, {0}}],
        ArrayIndexContract["i j, k -> k", {{{1, -1}}, {5, 6}}],
        ArrayIndexContract["i, i, j, k -> j k", {{1, -1}, {1, 1}, {1, 2}, {3, 4}}],
        ArrayIndexContract["i, i, j -> j", {SparseArray[{}, {2}], {1, 1}, {5, 6}}]
    },
    {
        {0, 0, 0},
        {0, 0},
        {{0, 0}, {0, 0}},
        {0, 0}
    },
    TestID -> "indexcontract-a-fully-contracted-zero-scales-rather-than-annihilates"
]

(* The same descriptors with a nonzero contracted part take the same route, so
   the scale is checked against arithmetic and not only against zero. *)

VerificationTest[
    {
        ArrayIndexContract["a, d -> a", {{1, 2, 3}, {5}}],
        ArrayIndexContract["i, i, j -> j", {{1, 2}, {3, 4}, {5, 6}}]
    },
    {
        {5, 10, 15},
        {55, 66}
    },
    TestID -> "indexcontract-a-fully-contracted-operand-scales-the-rest"
]

(* An output-only axis over a rank-0 result is a repeat of a scalar: the plan
   says so, and the lowering has to produce the array the plan's own output
   dimensions name rather than an unevaluated node. *)

VerificationTest[
    {
        ArrayIndexTransform[" -> k", 7, {"k" -> 2}],
        ArrayIndexTransform["1 -> k", {7}, {"k" -> 2}],
        ArrayIndexContract["i j -> k", {$a}, {"k" -> 2}],
        ArrayIndexContract["i, i -> j", {{1, 2}, {3, 4}}, {"j" -> 2}],
        ArrayIndexTransform[" -> j k", 7, {"j" -> 2, "k" -> 3}]
    },
    {
        {7, 7},
        {7, 7},
        {21, 21},
        {11, 11},
        {{7, 7, 7}, {7, 7, 7}}
    },
    TestID -> "indexcontract-broadcast-over-a-rank-0-result"
]

(* A plan carries both the steps that run and the solved stage they were built
   from: the steps say what runs and the solved descriptor says what they run
   on, so an object holding one without the other is not a plan.  A well-formed
   plan answers its properties; the same plan with its stage emptied is refused
   by name, and the executors, which reach a plan through the same predicate,
   decline it as a descriptor they cannot parse. *)

VerificationTest[
    With[{plan = First[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 2}}]]},
        {
            ArrayIndexPlan[plan]["OutputDimensions"],
            (* The refused call stays unevaluated, so its head is the plan
               object itself and the head of THAT is the symbol. *)
            Head[Head[ArrayIndexPlan[Append[plan, "Solved" -> <||>]]["OutputDimensions"]]]
        }
    ],
    {{2, 2}, ArrayIndexPlan},
    {ArrayIndexPlan::malformed},
    TestID -> "indexcontract-plan-with-a-malformed-solved-stage-is-declined"
]


BeginTestSection["indexcontract - container preservation"]

(* Execution goes through primitives that already dispatch on the container, so a
   SparseArray and a packed array keep their wrapper; the heads TensorProduct has
   no evaluation on are materialized first, which is why a NumericArray comes
   back as a plain array.  A QuantityArray keeps its wrapper by a route of its
   own, pinned below: the unit comes off the operands and the product of the
   units goes back on the result. *)

VerificationTest[
    With[{result = ArrayIndexContract["ij,jk->ik", {$sparseA, $sparseB}]},
        {Head[result], Normal[result]}
    ],
    {SparseArray, {{4, 5}, {10, 11}}},
    TestID -> "indexcontract-70-sparse-operands-stay-sparse"
]

VerificationTest[
    With[{result = ArrayIndexContract["ij,jk->ik", {$packedA, $packedB}]},
        {Developer`PackedArrayQ[result], result}
    ],
    {True, {{4., 5.}, {10., 11.}}},
    TestID -> "indexcontract-packed-operands-stay-packed"
]

(* A batch product contracts through a delta, written inactive so the evaluator
   leaves the operands beside it packed, and the broadcast step multiplies by an
   integer ones vector, whose product with packed Real or Complex data comes back
   unpacked and is repacked through the plain, value-preserving form of
   Developer`ToPackedArray; so the batch product here and the axis repeat below
   both keep packed operands packed. *)
VerificationTest[
    With[{result = ArrayIndexContract["bij,bjk->bik",
            {Developer`ToPackedArray[N[$batchA]], Developer`ToPackedArray[N[$batchB]]}]},
        {Developer`PackedArrayQ[result], result}
    ],
    {True, N[{{{1, 2}, {3, 4}}, {{10, 12}, {14, 16}}}]},
    TestID -> "indexcontract-broadcast-keeps-packed-operands-packed"
]

VerificationTest[
    With[{result = ArrayIndexTransform["i -> i j", Developer`ToPackedArray[N[Range[4]]], {"j" -> 3}]},
        {Developer`PackedArrayQ[result], result}
    ],
    {True, N[{{1, 1, 1}, {2, 2, 2}, {3, 3, 3}, {4, 4, 4}}]},
    TestID -> "indexcontract-broadcast-keeps-a-packed-repeat-packed"
]

(* The plain form never coerces: exact values ride the same broadcast step
   unchanged, and a SparseArray merged against a broadcast operand keeps its
   container. *)
VerificationTest[
    ArrayIndexTransform["i -> i j", {1/2, 3/4}, {"j" -> 2}],
    {{1/2, 1/2}, {3/4, 3/4}},
    TestID -> "indexcontract-broadcast-keeps-exact-values-exact"
]

VerificationTest[
    With[{result = ArrayIndexContract["bi,b->bi", {SparseArray[{{1., 0.}, {0., 2.}}], {3., 4.}}]},
        {Head[result], Normal[result]}
    ],
    {SparseArray, {{3., 0.}, {0., 8.}}},
    TestID -> "indexcontract-broadcast-keeps-a-sparse-merge-sparse"
]

VerificationTest[
    With[{result = ArrayIndexContract["ij,jk->ik", {$numericA, $numericB}]},
        {Head[result], result}
    ],
    {List, {{4, 5}, {10, 11}}},
    TestID -> "indexcontract-numericarray-operands-materialize"
]

VerificationTest[
    With[{result = ArrayIndexContract["ij->ji", {$quantity}]},
        {Head[result], Normal[result]}
    ],
    {QuantityArray, {{Quantity[1, "Meters"], Quantity[3, "Meters"]}, {Quantity[2, "Meters"], Quantity[4, "Meters"]}}},
    TestID -> "indexcontract-quantityarray-keeps-its-wrapper"
]

(* An ArrayObject handle is unwrapped to the container it holds. *)
VerificationTest[
    ArrayIndexContract["ij,jk->ik", {ArrayObject[$sparseA], $b}],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-arrayobject-operand-is-unwrapped"
]

(* A QuantityArray keeps its container whatever steps the descriptor emits, and
   that is the point of these: TensorContract keeps the wrapper and Times keeps
   it against another QuantityArray, but TensorProduct has no evaluation on the
   head and Times has none against a plain array, so the matrix product came back
   a QuantityArray while the batch form of the same descriptor and the column
   scaling came back lists of Quantity - the container depended on which steps
   were emitted rather than on what was handed in.  Every step is linear in its
   operands, so the unit is lifted off them, the steps run on the magnitudes and
   the product of the units goes back on the result.

   The expected value of each is the ordinary Wolfram computation of the same
   quantity: Dot for the matrix product, Dot per batch slice for the batch, and
   the elementwise products below, each in the unit the arithmetic gives. *)

VerificationTest[
    ArrayIndexContract["ij,jk->ik", {$quantity, $quantity}],
    QuantityArray[{{7, 10}, {15, 22}}, "Meters"^2],
    TestID -> "indexcontract-quantityarray-matrix-product-keeps-its-wrapper"
]

VerificationTest[
    ArrayIndexContract["bij,bjk->bik", {$quantityBatch, $quantityBatch}],
    QuantityArray[{{{7, 10}, {15, 22}}, {{67, 78}, {91, 106}}}, "Meters"^2],
    TestID -> "indexcontract-quantityarray-batch-product-keeps-its-wrapper"
]

VerificationTest[
    ArrayIndexContract["ij,j->ij", {$quantity, $quantityV}],
    QuantityArray[{{10, 40}, {30, 80}}, "Meters"^2],
    TestID -> "indexcontract-quantityarray-column-scaling-keeps-its-wrapper"
]

VerificationTest[
    ArrayIndexTransform["i -> i j", $quantityV, {"j" -> 3}],
    QuantityArray[{{10, 10, 10}, {20, 20, 20}}, "Meters"],
    TestID -> "indexcontract-quantityarray-repeat-keeps-its-wrapper"
]

(* A contraction that sums an axis of one operand scales by that operand's unit
   once, and a merge against a plain array scales by the one unit there is. *)

VerificationTest[
    ArrayIndexContract["ij->i", {$quantity}],
    QuantityArray[{3, 7}, "Meters"],
    TestID -> "indexcontract-quantityarray-row-sum-keeps-its-wrapper"
]

VerificationTest[
    ArrayIndexContract["ij,ij->ij", {$quantity, $m}],
    QuantityArray[{{1, 4}, {9, 16}}, "Meters"],
    TestID -> "indexcontract-quantityarray-merged-with-a-plain-array-keeps-its-wrapper"
]

(* There is no rank-0 QuantityArray, so a result the descriptor makes rank 0
   takes the same scaling as an ordinary Quantity; and units that cancel leave
   nothing to wrap, so the result is the plain array it computes to. *)

VerificationTest[
    ArrayIndexContract["ij->", {$quantity}],
    Quantity[10, "Meters"],
    TestID -> "indexcontract-quantityarray-summed-to-rank-0-is-a-quantity"
]

VerificationTest[
    ArrayIndexContract["ij,ij->ij", {$quantity, QuantityArray[{{1, 1}, {1, 1}}, 1/"Meters"]}],
    {{1, 2}, {3, 4}},
    TestID -> "indexcontract-quantityarray-whose-units-cancel-is-unwrapped"
]

(* A unit per column is not one unit, so there is nothing to lift and the
   elements carry their own units, which the merge here shows exactly. *)
VerificationTest[
    With[{result = ArrayIndexContract["ij,ij->ij", {$quantityMixed, $m}]},
        {Head[result], Normal[result]}
    ],
    {
        List,
        {
            {Quantity[1, "Meters"], Quantity[4, "Seconds"]},
            {Quantity[9, "Meters"], Quantity[16, "Seconds"]}
        }
    },
    TestID -> "indexcontract-quantityarray-with-a-unit-per-column-is-not-lifted"
]

(* Every wrapper container that is not a QuantityArray is materialized at the
   door, so what comes back does not depend on which steps ran.  A TabularColumn
   is the one that used to: it is ArrayQ, so it reached the steps, and Times kept
   it while a broadcast could not - a TabularColumn is rank 1 by construction and
   a repeat is rank 2. *)

VerificationTest[
    {
        ArrayIndexContract["i,i->i", {TabularColumn[{1, 2, 3}], TabularColumn[{1, 2, 3}]}],
        ArrayIndexTransform["i -> i j", TabularColumn[{1, 2, 3}], {"j" -> 2}]
    },
    {{1, 4, 9}, {{1, 1}, {2, 2}, {3, 3}}},
    TestID -> "indexcontract-tabularcolumn-operands-materialize"
]

VerificationTest[
    {
        ArrayIndexContract["i,i->i", {ByteArray[{1, 2, 3}], ByteArray[{1, 2, 3}]}],
        ArrayIndexContract["i,i->i",
            {EventSeries[{{1, 1}, {2, 2}, {3, 3}}], EventSeries[{{1, 1}, {2, 2}, {3, 3}}]}],
        ArrayIndexContract["ij,jk->ik", {Dataset[$m], Dataset[$m]}],
        ArrayIndexContract["ij,jk->ik",
            {Tabular[{<|"a" -> 1, "b" -> 2|>, <|"a" -> 3, "b" -> 4|>}],
             Tabular[{<|"a" -> 1, "b" -> 2|>, <|"a" -> 3, "b" -> 4|>}]}]
    },
    {{1, 4, 9}, {1, 4, 9}, {{7, 10}, {15, 22}}, {{7, 10}, {15, 22}}},
    TestID -> "indexcontract-the-remaining-wrappers-materialize"
]

(* What a caller contracting a network of arrays relies on, over every kind of
   step a descriptor emits - a summed index, an elementwise product, a scaling,
   a batch index, an outer product, a transpose and a sum over one axis.

   An all-SparseArray set contracts to a SparseArray, exact entries stay exact
   and the background stays an exact 0. *)
VerificationTest[
    With[{s = SparseArray[{{1, 0, 2}, {0, 3, 0}}], t = SparseArray[{{0, 1}, {4, 0}, {0, 5}}],
          s2 = SparseArray[{{0, 2, 1}, {5, 0, 0}}], v = SparseArray[{1, 0, 3}],
          s3 = SparseArray[{{{1, 0}, {0, 2}}, {{0, 3}, {4, 0}}}], t3 = SparseArray[{{{0, 1}, {1, 0}}, {{2, 0}, {0, 0}}}]},
        Map[
            Function[result, {Head[result], result["Background"], Normal[result]}],
            {
                ArrayIndexContract["ij,jk->ik", {s, t}],
                ArrayIndexContract["ij,ij->ij", {s, s2}],
                ArrayIndexContract["ij,j->ij", {s, v}],
                ArrayIndexContract["bij,bjk->bik", {s3, t3}],
                ArrayIndexContract["i,j->ij", {v, SparseArray[{0, 3}]}],
                ArrayIndexContract["ij->ji", {s}],
                ArrayIndexContract["ij->i", {s}]
            }
        ]
    ],
    {
        {SparseArray, 0, {{0, 11}, {12, 0}}},
        {SparseArray, 0, {{0, 0, 2}, {0, 0, 0}}},
        {SparseArray, 0, {{1, 0, 6}, {0, 0, 0}}},
        {SparseArray, 0, {{{0, 1}, {2, 0}}, {{0, 0}, {8, 0}}}},
        {SparseArray, 0, {{0, 3}, {0, 0}, {0, 9}}},
        {SparseArray, 0, {{1, 0}, {0, 3}, {2, 0}}},
        {SparseArray, 0, {3, 3}}
    },
    TestID -> "indexcontract-exact-sparse-operands-stay-sparse-and-exact"
]

(* A set of packed arrays contracts to a packed array, Real and Integer alike; a
   batch product comes back packed where MapThread[Dot] gives an unpacked list
   of packed blocks. *)
VerificationTest[
    With[{a = Developer`ToPackedArray[N[$a]], b = Developer`ToPackedArray[N[$b]], v = Developer`ToPackedArray[N[{1, 2, 3}]],
          a3 = Developer`ToPackedArray[N[$batchA]], b3 = Developer`ToPackedArray[N[$batchB]],
          ai = Developer`ToPackedArray[$a], bi = Developer`ToPackedArray[$b],
          a3i = Developer`ToPackedArray[$batchA], b3i = Developer`ToPackedArray[$batchB]},
        Map[
            Apply[Function[{result, reference}, {Developer`PackedArrayQ[result], result == reference}]],
            {
                {ArrayIndexContract["ij,jk->ik", {a, b}], a . b},
                {ArrayIndexContract["ij,ij->ij", {a, a}], a a},
                {ArrayIndexContract["ij,j->ij", {a, v}], a {v, v}},
                {ArrayIndexContract["ij,j->i", {a, v}], a . v},
                {ArrayIndexContract["bij,bjk->bik", {a3, b3}], MapThread[Dot, {a3, b3}]},
                {ArrayIndexContract["i,j->ij", {v, v}], Outer[Times, v, v]},
                {ArrayIndexContract["ij->ji", {a}], Transpose[a]},
                {ArrayIndexContract["ij->i", {a}], Total[a, {2}]},
                {ArrayIndexContract[{{}, {i, j}}, {2, a}], 2 a},
                {ArrayIndexContract["ij,jk->ik", {ai, bi}], ai . bi},
                {ArrayIndexContract["bij,bjk->bik", {a3i, b3i}], MapThread[Dot, {a3i, b3i}]},
                {ArrayIndexContract["ij,ij->ij", {ai, ai}], ai ai}
            }
        ]
    ],
    ConstantArray[{True, True}, 12],
    TestID -> "indexcontract-packed-operands-stay-packed-over-every-step"
]

(* Integers past machine size and rationals stay exact. *)
VerificationTest[
    With[{a = {{10^30, 1}, {2, 10^25}}, b = {{3, 10^20}, {10^18, 5}}, r = {{1/3, 2/7}, {5/11, 1/13}}},
        {
            ArrayIndexContract["ij,jk->ik", {a, b}] === a . b,
            ArrayIndexContract["bij,bjk->bik", {{a, b}, {b, a}}] === {a . b, b . a},
            ArrayIndexContract["ij,ij->ij", {a, b}] === a b,
            ArrayIndexContract["ij,j->ij", {a, {10^40, 7}}] === a {{10^40, 7}, {10^40, 7}},
            ArrayIndexContract["ii->", {a}] === Tr[a],
            ArrayIndexContract["ij,jk->ik", {r, a}] === r . a,
            ArrayIndexContract["bij,bjk->bik", {{r, r}, {a, b}}] === {r . a, r . b},
            ArrayIndexContract[{{}, {i, j}}, {10^30, r}] === 10^30 r
        }
    ],
    ConstantArray[True, 8],
    TestID -> "indexcontract-big-integers-and-rationals-stay-exact"
]

(* Symbolic entries are arithmetic like any other: an explicit array of
   expressions contracts to the expressions the kernel's own products give,
   a sparse one staying sparse. *)
VerificationTest[
    With[{x = Array[xe, {2, 2}], y = Array[ye, {2, 2}], x3 = Array[xe, {2, 2, 2}], y3 = Array[ye, {2, 2, 2}],
          v = {ve[1], ve[2]}, sx = SparseArray[{{xe[1], 0}, {0, xe[2]}}]},
        {
            Union[Flatten[Expand[{
                ArrayIndexContract["ij,jk->ik", {x, y}] - x . y,
                ArrayIndexContract["bij,bjk->bik", {x3, y3}] - MapThread[Dot, {x3, y3}],
                ArrayIndexContract["ij,ij->ij", {x, y}] - x y,
                ArrayIndexContract["ij,j->ij", {x, v}] - x {v, v},
                ArrayIndexContract["ii->", {x}] - Tr[x],
                ArrayIndexContract[{{}, {i, j}}, {se, x}] - se x,
                ArrayIndexContract[{{}, {i}, {i}} :> {{}}, {se, {1, 2}, v}] - se (ve[1] + 2 ve[2])
            }]]],
            With[{result = ArrayIndexContract["ij,jk->ik", {sx, sx}]}, {Head[result], Normal[result]}]
        }
    ],
    {{0}, {SparseArray, {{xe[1]^2, 0}, {0, xe[2]^2}}}},
    TestID -> "indexcontract-symbolic-entries-contract-as-expressions"
]

(* A rank-0 operand is a factor of the contraction, exact, sparse and packed
   companions keeping their containers, and a rank-0 result is a number rather
   than an array of rank 0. *)
VerificationTest[
    {
        ArrayIndexContract[{{}, {i}, {i}} :> {{}}, {2, {1, 2}, {3, 4}}],
        ArrayIndexContract[{{}, {}}, {1/2, 6}],
        With[{result = ArrayIndexContract[{{}, {i, j}}, {1/2, SparseArray[{{2, 0}, {0, 4}}]}]}, {Head[result], Normal[result]}],
        With[{result = ArrayIndexContract[{{}, {i, j}, {j, k}} :> {{i, k}}, {3, SparseArray[{{1, 0}, {0, 2}}], SparseArray[{{0, 1}, {1, 0}}]}]},
            {Head[result], Normal[result]}
        ],
        ArrayIndexContract[{{}, {b, i}, {b, i}} :> {{b, i}}, {2, {{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}}],
        With[{result = ArrayIndexContract["ij,ij->", {Developer`ToPackedArray[N[$m]], Developer`ToPackedArray[N[$m]]}]}, {Head[result], result}]
    },
    {
        22,
        3,
        {SparseArray, {{1, 0}, {0, 2}}},
        {SparseArray, {{0, 3}, {6, 0}}},
        {{10, 24}, {42, 64}},
        {Real, 30.}
    },
    TestID -> "indexcontract-rank-0-operands-are-factors"
]

(* A set that mixes SparseArray and dense operands comes back in the container
   the kernel's own arithmetic gives the same operands, neither densified nor
   sparsified beyond it: a summed index follows Dot, an elementwise product or a
   scaling follows Times, and an outer product follows TensorProduct, which
   keeps the container of its first factor. *)
VerificationTest[
    With[{s = SparseArray[{{1, 0, 2}, {0, 3, 0}}], d = {{1, 2}, {3, 4}, {5, 6}}, dv = {7, 8, 9}, sv = SparseArray[{1, 0, 3}],
          s3 = SparseArray[{{{1, 0}, {0, 2}}, {{0, 3}, {4, 0}}}], d3 = {{{1, 1}, {2, 2}}, {{3, 3}, {4, 4}}}},
        Map[
            Apply[Function[{result, reference}, {Head[result] === Head[reference], Normal[result] === Normal[reference]}]],
            {
                {ArrayIndexContract["ij,jk->ik", {s, d}], s . d},
                {ArrayIndexContract["ij,jk->ik", {Transpose[d], Transpose[s]}], Transpose[d] . Transpose[s]},
                {ArrayIndexContract["ij,j->i", {s, dv}], s . dv},
                {ArrayIndexContract["bij,bjk->bik", {s3, d3}], MapThread[Dot, {Normal[s3], d3}]},
                {ArrayIndexContract["ij,ij->ij", {s, Transpose[d]}], s Transpose[d]},
                {ArrayIndexContract["ij,ij->ij", {Transpose[d], s}], Transpose[d] s},
                {ArrayIndexContract["ij,j->ij", {s, dv}], s {dv, dv}},
                {ArrayIndexContract["bij,bij->bij", {s3, d3}], s3 d3},
                {ArrayIndexContract["i,j->ij", {sv, {1, 2}}], TensorProduct[sv, {1, 2}]},
                {ArrayIndexContract["i,j->ij", {{1, 2}, sv}], TensorProduct[{1, 2}, sv]}
            }
        ]
    ],
    ConstantArray[{True, True}, 10],
    TestID -> "indexcontract-mixed-containers-follow-the-kernels-arithmetic"
]

EndTestSection[]


BeginTestSection["indexcontract - tiers"]

(* Every step a plan lowers to - ReshapeArray, ArrayTranspose and ArrayContract,
   the broadcast and the batch index included - keeps a symbolic operand inert
   and a lazy one lazy where its head can rebuild, so an index contraction and
   an index rearrangement run on every tier, and the result has the tier the
   operands join to.  A symbolic operand gives an inert tree whose dimensions
   are the output shape, which ArrayMaterialize computes once the symbols are
   given values; the corpus reaches an inert tree for these calls too. *)

VerificationTest[
    With[{tree = ArrayIndexContract["ij,jk->ik", {$symA, $symB}]},
        {ArraySymbolicQ[tree], ArrayDimensions[tree], ArrayMaterialize[tree /. {$symA -> $a, $symB -> $b}]}
    ],
    {True, {2, 2}, {{4, 5}, {10, 11}}},
    TestID -> "indexcontract-06-symbolic-operands-give-an-inert-tree"
]

VerificationTest[
    With[{tree = ArrayIndexTransform["ij->ji", $symA]},
        {tree, ArrayDimensions[tree]}
    ],
    {Transpose[$symA, {2, 1}], {3, 2}},
    TestID -> "indexcontract-15-symbolic-operand-transposes-inertly"
]

(* A batch index is a delta among the operands of the contraction, written
   inactive in the plan and kept in the inert tree, where ArrayMaterialize
   contracts it once the symbols have values. *)
VerificationTest[
    With[{tree = ArrayIndexContract["bij,bjk->bik", {ArraySymbol["A", {2, 2, 2}], ArraySymbol["B", {2, 2, 2}]}]},
        {
            ArraySymbolicQ[tree],
            ArrayDimensions[tree],
            ArrayMaterialize[tree /. {ArraySymbol["A", {2, 2, 2}] -> $batchA, ArraySymbol["B", {2, 2, 2}] -> $batchB}]
        }
    ],
    {True, {2, 2, 2}, {{{1, 2}, {3, 4}}, {{10, 12}, {14, 16}}}},
    TestID -> "indexcontract-29-symbolic-batch-operands-give-an-inert-tree"
]

VerificationTest[
    With[{tree = ArrayIndexContract[{{i, j}, {j, k}} :> {{i, j, k}}, {ArraySymbol["A", {3, 2}], ArraySymbol["B", {2, 4}]}]},
        {ArraySymbolicQ[tree], ArrayDimensions[tree]}
    ],
    {True, {3, 2, 4}},
    TestID -> "indexcontract-63-symbolic-merge-operands-give-an-inert-tree"
]

(* A lazy operand: an InterpolatingFunction applied to a free symbol.  A
   contraction that leaves no array has no lazy form, and gives a scalar
   expression that substitutes to the contracted value.  A rebuild contracts the
   value grid and reinterpolates it, so the comparison is at a grid point, where
   the rebuilt interpolant and the contraction of the original agree exactly;
   between grid points they agree to interpolation accuracy. *)
VerificationTest[
    With[{result = ArrayIndexContract[{{i}, {i}} :> {{}}, {$lazy, {1., 2.}}], t = $if["Grid"][[3, 1]]},
        Abs[(result /. iTau -> t) - $if[t] . {1., 2.}] < 10^-12
    ],
    True,
    TestID -> "indexcontract-lazy-operand-full-contraction-substitutes"
]

VerificationTest[
    With[{result = ArrayIndexContract[{{i, j}, {j}} :> {{i}}, {$lazy2, {1., 1.}}]},
        {ArrayLazyQ[result], ArrayReplaceAll[result, iZ -> -1], ArrayReplaceAll[result, iZ -> 1]}
    ],
    {True, {3., 7.}, {11., 15.}},
    TestID -> "indexcontract-lazy-operand-stays-lazy"
]

(* The BARE array-valued InterpolatingFunction classifies lazy too, and an
   outer product keeps it lazy: it is rebuilt through its value grid. *)
VerificationTest[
    With[{result = ArrayIndexContract["i,j->ij", {$if, {1., 2.}}], t = $if["Grid"][[3, 1]]},
        {ArrayLazyQ[result], Max[Abs[result[t] - Outer[Times, $if[t], {1., 2.}]]] < 10^-12}
    ],
    {True, True},
    TestID -> "indexcontract-bare-interpolatingfunction-operand-stays-lazy"
]

VerificationTest[
    With[{result = ArrayIndexTransform["ij->ji", $lazy2]},
        {ArrayLazyQ[result], ArrayReplaceAll[result, iZ -> -1], ArrayReplaceAll[result, iZ -> 1]}
    ],
    {True, {{1., 3.}, {2., 4.}}, {{5., 7.}, {6., 8.}}},
    TestID -> "indexcontract-lazy-operand-transposes-lazily"
]

(* The phase acceptance, over every shape of plan: each descriptor is run with
   its first operand replaced by an ArraySymbol of the same dimensions, which
   gives an inert tree of the output's dimensions that materializes to the
   explicit result once the symbol is given the operand, and by a lazy Piecewise
   of it, which stays lazy - or, where nothing is left of the array, is a scalar
   expression in the parameter - and substitutes to the result of the operand it
   stands for. *)
VerificationTest[
    Module[{corpus, value, check},
        corpus = {
            {ArrayIndexContract, "ij,jk->ik", {$a, $b}, {}},
            {ArrayIndexContract, "bij,bjk->bik", {$batchA, $batchB}, {}},
            {ArrayIndexContract, "b i j, b j k -> b k i", {$batchA, $batchB}, {}},
            {ArrayIndexContract, "ij,ij->ij", {$m, $m}, {}},
            {ArrayIndexContract, "bi,b->bi", {$m, {3, 4}}, {}},
            {ArrayIndexContract, "ii->", {$m}, {}},
            {ArrayIndexContract, "ij->", {$a}, {}},
            {ArrayIndexContract, "i,j->ij", {{1, 2}, {3, 4, 5}}, {}},
            {ArrayIndexContract, "i,i->", {{1, 2}, {3, 4}}, {}},
            {ArrayIndexContract, "ij,jk,kl->il", {$a, $b, $m}, {}},
            {ArrayIndexContract, "ib,jb,kb->ijk", {$m, $m, $m}, {}},
            {ArrayIndexContract, "ib,jb,kb->ijkb", {$m, $m, $m}, {}},
            {ArrayIndexContract, "iij->j", {$r3}, {}},
            {ArrayIndexContract, "ij,->ij", {$m, 3}, {}},
            {ArrayIndexTransform, "(a b) c -> a b c", {$grid}, {"a" -> 2}},
            {ArrayIndexTransform, "a b c -> (b a) c", {$blocks}, {}},
            {ArrayIndexTransform, "i j -> j k i", {$m}, {"k" -> 2}}
        };
        value[x_] := If[ArrayContainerQ[x], Normal[ArrayMaterialize[x]], Activate[x]];
        check[{sym_, desc_, ops_, bind_}] := Module[{explicit, symbol, symbolic, lazy},
            explicit = If[sym === ArrayIndexTransform, sym[desc, First[ops], bind], sym[desc, ops, bind]];
            symbol = ArraySymbol["Z", Dimensions[First[ops]]];
            symbolic = If[sym === ArrayIndexTransform, sym[desc, symbol, bind], sym[desc, ReplacePart[ops, 1 -> symbol], bind]];
            lazy = With[{piece = Piecewise[{{First[ops], zLazy < 0}}, 2 First[ops]]},
                If[sym === ArrayIndexTransform, sym[desc, piece, bind], sym[desc, ReplacePart[ops, 1 -> piece], bind]]
            ];
            And[
                ArraySymbolicQ[symbolic] || ArrayRank[explicit] === 0,
                ArrayDimensions[symbolic] === Dimensions[explicit],
                value[symbolic /. symbol -> First[ops]] == explicit,
                ArrayLazyQ[lazy] || ArrayRank[explicit] === 0,
                value[lazy /. zLazy -> 1] == 2 explicit
            ]
        ];
        Select[corpus, ! check[#] &][[All, 2]]
    ],
    {},
    TestID -> "indexcontract-symbolic-and-lazy-operands-agree-with-explicit"
]

(* Solving needs no data, so a symbolic operand plans without materializing
   anything. *)
VerificationTest[
    With[{plan = ArrayIndexPlan["ij,jk->ik", {$symA, $symB}]},
        {plan["OutputDimensions"], plan["AxisSizes"]}
    ],
    {{2, 2}, <|"i" -> 2, "j" -> 3, "k" -> 2|>},
    TestID -> "indexcontract-symbolic-operands-still-plan"
]

(* The plan's expression is a Function of the operands whose body is the
   ArrayContract over an inactive TensorProduct that the contraction step lowers
   to, so applying it to symbolic operands gives the node that symbol leaves
   standing for them, and ArrayDimensions reads its shape. *)
VerificationTest[
    With[{plan = ArrayIndexPlan["ij,jk->ik", {$symA, $symB}]},
        With[{tree = plan["Expression"][$symA, $symB]},
            {
                MatchQ[plan["Expression"],
                    Function[ArrayContract[Inactive[TensorProduct][Slot[1], Slot[2]], {{2, 3}}]]],
                MatchQ[tree, TensorContract[Inactive[TensorProduct][$symA, $symB], {{2, 3}}]],
                ArrayDimensions[tree]
            }
        ]
    ],
    {True, True, {2, 2}},
    TestID -> "indexcontract-plan-expression-is-the-contraction-node"
]

EndTestSection[]


BeginTestSection["indexcontract - rearrangement"]

(* ArrayIndexTransform keeps every axis it is given: the steps are one reshape
   that splits composites, one broadcast, one transpose and one reshape that
   merges, each emitted only where it is not the identity. *)

VerificationTest[
    ArrayIndexTransform["ij->ji", $a],
    {{1, 4}, {2, 5}, {3, 6}},
    TestID -> "indexcontract-transform-transpose"
]

VerificationTest[
    ArrayIndexTransform[{{i, j, k}} :> {{k, i, j}}, $r3],
    {{{1, 3}, {5, 7}}, {{2, 4}, {6, 8}}},
    TestID -> "indexcontract-transform-rank3-permutation"
]

(* Splitting a composite puts the leftmost factor outermost, so h selects a block
   of three consecutive rows of the 6x4 grid. *)
VerificationTest[
    ArrayIndexTransform["(h c) w -> h c w", $grid, {"h" -> 2}],
    {{{1, 2, 3, 4}, {5, 6, 7, 8}, {9, 10, 11, 12}},
     {{13, 14, 15, 16}, {17, 18, 19, 20}, {21, 22, 23, 24}}},
    TestID -> "indexcontract-transform-split"
]

(* Split and permute in one descriptor: the entry at {w, c, h} is the grid entry
   at row 3 (h - 1) + c and column w. *)
VerificationTest[
    ArrayIndexTransform["(h c) w -> w c h", $grid, {"h" -> 2}],
    {{{1, 13}, {5, 17}, {9, 21}},
     {{2, 14}, {6, 18}, {10, 22}},
     {{3, 15}, {7, 19}, {11, 23}},
     {{4, 16}, {8, 20}, {12, 24}}},
    TestID -> "indexcontract-transform-split-and-permute"
]

VerificationTest[
    ArrayIndexTransform["h c w -> (h c) w", $blocks],
    $grid,
    TestID -> "indexcontract-transform-merge"
]

(* An axis present only on the output is a uniform broadcast; a literal on the
   output side gives it its size directly. *)
VerificationTest[
    ArrayIndexTransform[{{a_}} :> {{a, 3}}, {1, 2}],
    {{1, 1, 1}, {2, 2, 2}},
    TestID -> "indexcontract-transform-broadcast-to-a-literal"
]

VerificationTest[
    ArrayIndexTransform["i -> i j", {1, 2}, {"j" -> 3}],
    {{1, 1, 1}, {2, 2, 2}},
    TestID -> "indexcontract-transform-broadcast-to-a-bound-axis"
]

VerificationTest[
    ArrayIndexTransform[{{a_}} :> {{a, Annotation[j, 3]}}, {1, 2}],
    {{1, 1, 1}, {2, 2, 2}},
    TestID -> "indexcontract-transform-broadcast-to-an-inline-size"
]

(* With no output shape given a rearrangement is shape-preserving, and a scalar
   has the {} shape. *)
VerificationTest[
    ArrayIndexTransform[{{}} :> {{}}, 7],
    7,
    TestID -> "indexcontract-transform-scalar-operand"
]

(* An axis dropped from the output would be summed rather than moved, which is
   the other executor's job. *)
VerificationTest[
    Head[ArrayIndexTransform[{{i, j}} :> {{i}}, $m]],
    ArrayIndexTransform,
    {ArrayIndexTransform::effect},
    TestID -> "indexcontract-transform-declines-a-summed-axis"
]

(* The admission is decided from the descriptor alone, before any size is
   solved, so an anonymous input axis absent from the output is declined at
   extent one exactly as at any other extent; the squeezed spelling of a unit
   axis is the literal 1. *)
VerificationTest[
    {
        Head[ArrayIndexTransform["a _ -> a", {{1.}, {2.}}]],
        ArrayIndexTransform[{{a_, 1}} :> {{a}}, {{1.}, {2.}}]
    },
    {ArrayIndexTransform, {1., 2.}},
    {ArrayIndexTransform::effect},
    TestID -> "indexcontract-transform-declines-an-anonymous-unit-axis"
]

VerificationTest[
    Head[ArrayIndexTransform[{{i, j}, {j, k}} :> {{i, k}}, $m]],
    ArrayIndexTransform,
    {ArrayIndexTransform::arity},
    TestID -> "indexcontract-transform-declines-two-input-shapes"
]

(* A target marks a contracted axis where an input shape carries it, so a
   bracket on the output side marks nothing and is refused by the axis it sits
   on, rather than through an empty marked-versus-contracted comparison. *)
VerificationTest[
    Head[ArrayIndexTransform["a -> a [b]", {1., 2.}, {"b" -> 3}]],
    ArrayIndexTransform,
    {ArrayIndexPlan::targetplace},
    TestID -> "indexcontract-transform-declines-a-target-on-the-output-side"
]

EndTestSection[]


BeginTestSection["indexcontract - prepared plans"]

(* Compile once, apply many: both executors take an ArrayIndexPlan where a
   descriptor goes, and a plan solved from dimensions alone needs no data. *)

VerificationTest[
    ArrayIndexContract[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 2}}], {$a, $b}],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-plan-from-dimensions-executes"
]

VerificationTest[
    ArrayIndexTransform[ArrayIndexPlan["ij->ji", {{2, 3}}], $a],
    {{1, 4}, {2, 5}, {3, 6}},
    TestID -> "indexcontract-plan-executes-through-transform"
]

VerificationTest[
    ArrayIndexTransform[ArrayIndexPlan["(h c) w -> h c w", {{6, 4}}, {"h" -> 2}], $grid],
    {{{1, 2, 3, 4}, {5, 6, 7, 8}, {9, 10, 11, 12}},
     {{13, 14, 15, 16}, {17, 18, 19, 20}, {21, 22, 23, 24}}},
    TestID -> "indexcontract-plan-carries-its-bindings"
]

(* A parsed pattern is equally accepted, which is the other half of the
   compile-once path. *)
VerificationTest[
    ArrayIndexContract[ArrayIndexPattern["ij,jk->ik"], {$a, $b}],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-pattern-executes"
]

(* A plan's steps carry the extents they were solved for, so reusing one on other
   shapes would quietly lower to a different array; the dimensions are checked
   against the plan, not just the operand count. *)
VerificationTest[
    Head[ArrayIndexContract[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 2}}], {$m, $m}]],
    ArrayIndexContract,
    {ArrayIndexPlan::dimensions},
    TestID -> "indexcontract-plan-checks-operand-dimensions"
]

VerificationTest[
    Head[ArrayIndexContract[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 2}}], {$a}]],
    ArrayIndexContract,
    {ArrayIndexPlan::operands},
    TestID -> "indexcontract-plan-checks-operand-count"
]

VerificationTest[
    ArrayIndexPlan["ij,jk->ik", {$a, $b}]["OutputDimensions"],
    {2, 2},
    TestID -> "indexcontract-plan-from-arrays-reads-their-dimensions"
]

(* The expression the plan renders is the one the executor runs, and a Function
   is what makes that checkable: applied to the operands by hand it gives the
   executor's own answer, in the executor's own container. *)

VerificationTest[
    With[{plan = ArrayIndexPlan["ij,jk->ik", {$sparseA, $sparseB}]},
        With[{byHand = plan["Expression"][$sparseA, $sparseB]},
            {byHand === ArrayIndexContract[plan, {$sparseA, $sparseB}], Head[byHand], Normal[byHand]}
        ]
    ],
    {True, SparseArray, {{4, 5}, {10, 11}}},
    TestID -> "indexcontract-plan-expression-is-what-the-executor-runs"
]

(* The same holds where the plan is a whole chain rather than one step: a batch
   product broadcasts, transposes, multiplies and contracts, and every one of
   those steps is in the rendered expression. *)
VerificationTest[
    With[{plan = ArrayIndexPlan["bij,bjk->bik", {$batchA, $batchB}]},
        plan["Expression"][$batchA, $batchB] === ArrayIndexContract[plan, {$batchA, $batchB}]
    ],
    True,
    TestID -> "indexcontract-plan-expression-runs-a-whole-chain"
]

(* The one combiner a contraction over an inactive TensorProduct expresses is
   the sum of products. *)
VerificationTest[
    Head[ArrayIndexContract["ij,jk->ik", {$a, $b}, "Combiner" -> {Plus, Times}]],
    ArrayIndexContract,
    {ArrayIndexContract::combiner},
    TestID -> "indexcontract-declines-a-combiner-other-than-sum-of-products"
]

(* "Targeting" -> False is the mode in which classic einsum semantics are
   recovered exactly: no bracket anywhere, contract by repeated name. *)
VerificationTest[
    ArrayIndexContract[{{i, j}, {j, k}} :> {{i, k}}, {$a, $b}, "Targeting" -> False],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-targeting-false-recovers-einsum-semantics"
]

(* An option that a prepared object cannot honour is refused rather than
   dropped.  "Targeting" and "DefaultOutput" are read where a descriptor is
   COMPILED - the first selects which occurrences count as targeted, the second
   decides the output shape of a descriptor that writes none - and both objects
   carry the normalized descriptor those settings produced, so a later setting
   has nothing left to act on.  The refusal names the object whose construction
   takes the setting, which is where the fix belongs; the raw path refused only
   a bad VALUE, so the compile-once path used to accept what a descriptor
   refuses and compute in silence. *)

VerificationTest[
    Head[ArrayIndexContract[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 2}}], {$a, $b}, "Targeting" -> False]],
    ArrayIndexContract,
    {ArrayIndexPlan::prepared},
    TestID -> "indexcontract-prepared-plan-refuses-a-compile-time-option"
]

VerificationTest[
    Head[ArrayIndexContract[ArrayIndexPattern["ij,jk->ik"], {$a, $b}, "DefaultOutput" -> "Identity"]],
    ArrayIndexContract,
    {ArrayIndexPattern::prepared},
    TestID -> "indexcontract-prepared-pattern-refuses-a-compile-time-option"
]

VerificationTest[
    Head[ArrayIndexTransform[ArrayIndexPlan["ij->ji", {{2, 3}}], $a, "Targeting" -> True]],
    ArrayIndexTransform,
    {ArrayIndexPlan::prepared},
    TestID -> "indexcontract-prepared-plan-refuses-a-compile-time-option-through-transform"
]

(* The two objects refuse it in a descriptor position of their own as well: a
   plan solved from a prepared pattern reuses that pattern's settings. *)
VerificationTest[
    Head[ArrayIndexPlan[ArrayIndexPattern["ij,jk->ik"], {{2, 3}, {3, 2}}, "Targeting" -> True]],
    ArrayIndexPlan,
    {ArrayIndexPattern::prepared},
    TestID -> "indexcontract-plan-from-a-prepared-pattern-refuses-a-compile-time-option"
]

(* A binding list is refused on the same ground: a size given out of band
   becomes a known-size constraint of the normalized descriptor, so it is read
   where a descriptor is compiled and a prepared object already carries the
   constraints its own construction resolved.  Dropping it in silence made the
   compile-once path report the very axis the caller had sized as unsized. *)

VerificationTest[
    Head[ArrayIndexTransform[ArrayIndexPattern["i -> i j"], {1, 2}, {"j" -> 3}]],
    ArrayIndexTransform,
    {ArrayIndexPattern::bindings},
    TestID -> "indexcontract-prepared-pattern-refuses-a-binding-list"
]

VerificationTest[
    Head[ArrayIndexContract[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 2}}], {$a, $b}, {"j" -> 3}]],
    ArrayIndexContract,
    {ArrayIndexPlan::bindings},
    TestID -> "indexcontract-prepared-plan-refuses-a-binding-list"
]

(* The sizes a prepared object was BUILT with travel with it, which is the
   spelling the refusal points at. *)
VerificationTest[
    ArrayIndexTransform[ArrayIndexPattern["i -> i j", {"j" -> 3}], {1, 2}],
    {{1, 1, 1}, {2, 2, 2}},
    TestID -> "indexcontract-prepared-pattern-carries-the-bindings-its-construction-resolved"
]

(* "Combiner" is the opposite case and is taken: it is read at EXECUTION, for
   the refusal of any pairing other than the sum of products, and no stage of
   compilation looks at it, so a prepared plan honours it and refuses exactly
   the settings a descriptor refuses. *)

VerificationTest[
    ArrayIndexContract[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 2}}], {$a, $b}, "Combiner" -> {Times, Plus}],
    {{4, 5}, {10, 11}},
    TestID -> "indexcontract-prepared-plan-takes-the-execution-time-combiner"
]

VerificationTest[
    Head[ArrayIndexContract[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 2}}], {$a, $b}, "Combiner" -> {Plus, Times}]],
    ArrayIndexContract,
    {ArrayIndexContract::combiner},
    TestID -> "indexcontract-prepared-plan-refuses-a-combiner-other-than-sum-of-products"
]

(* An option name the symbol does not declare refuses identically on both paths.
   OptionValue reports one with the System message OptionValue::nodef, once for
   each setting the call goes on to read, and then hands back the default and
   computes; the names are checked before any setting is read, so the refusal is
   one message and the call is left as written. *)

VerificationTest[
    {
        Head[ArrayIndexContract["ij,jk->ik", {$a, $b}, "Nonsense" -> 1]],
        Head[ArrayIndexContract[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 2}}], {$a, $b}, "Nonsense" -> 1]]
    },
    {ArrayIndexContract, ArrayIndexContract},
    {ArrayIndexContract::optionname, ArrayIndexContract::optionname},
    TestID -> "indexcontract-an-unknown-option-refuses-on-both-paths"
]

(* "Combiner" is declared on the contraction alone, since nothing else pairs two
   operations, so it is an unknown NAME to the rearrangement rather than a
   setting it may ignore. *)
VerificationTest[
    Head[ArrayIndexTransform["ij->ji", $a, "Combiner" -> {Times, Plus}]],
    ArrayIndexTransform,
    {ArrayIndexTransform::optionname},
    TestID -> "indexcontract-transform-declines-the-contraction-only-combiner"
]

VerificationTest[
    {
        Head[ArrayIndexPattern["ij,jk->ik", "Nonsense" -> 1]],
        Head[ArrayIndexPlan["ij,jk->ik", {{2, 3}, {3, 2}}, "Nonsense" -> 1]]
    },
    {ArrayIndexPattern, ArrayIndexPlan},
    {ArrayIndexPattern::optionname, ArrayIndexPlan::optionname},
    TestID -> "indexcontract-an-unknown-option-refuses-on-both-objects"
]

EndTestSection[]
