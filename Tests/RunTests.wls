#!/usr/bin/env wolframscript

(* Test runner for Wolfram/Arrays *)
(* Usage: wolframscript -f Tests/RunTests.wls [pattern] *)
(* Examples: *)
(*   wolframscript -f Tests/RunTests.wls            - run all .wlt files *)
(*   wolframscript -f Tests/RunTests.wls Array      - run only files matching "Array" *)

$rootDir = DirectoryName[$InputFileName];
(* repo layout nests the paclet one level deep (submodule convention):
   <repo>/Arrays/PacletInfo.wl, tests stay at <repo>/Tests *)
$pacletDir = FileNameJoin[{$rootDir, "..", "Arrays"}];

(* Uninstall any repo-installed version to ensure local source takes priority *)
Quiet[PacletUninstall /@ PacletFind["Wolfram/Arrays"]];
PacletDirectoryLoad[$pacletDir];
Needs["Wolfram`Arrays`"];

(* Find test files *)
pattern = If[Length[$ScriptCommandLine] > 1, $ScriptCommandLine[[2]], ""];
testFiles = FileNames["*.wlt", $rootDir, Infinity];
If[pattern =!= "",
    testFiles = Select[testFiles, StringContainsQ[FileNameTake[#], pattern, IgnoreCase -> True] &]
];

If[Length[testFiles] == 0,
    Print["No test files found" <> If[pattern =!= "", " matching \"" <> pattern <> "\"", ""] <> "."];
    Exit[1]
];

Print["======================================================="];
Print["  Arrays Test Report"];
Print["======================================================="];
Print["  Date: ", DateString[]];
Print["  Paclet: ", $pacletDir];
Print["  Test files: ", Length[testFiles]];
Print[""];

runTestFile[file_] := Block[{report, results, passed, failed, errors, total},
    Print["-------------------------------------------------------"];
    Print["  ", FileNameTake[file]];
    Print["-------------------------------------------------------"];
    report = TestReport[file];
    results = report["TestResults"];

    passed = Length[Select[results, #["Outcome"] === "Success" &]];
    failed = Length[Select[results, #["Outcome"] === "Failure" &]];
    errors = Length[Select[results, #["Outcome"] === "MessagesFailure" || #["Outcome"] === "Error" &]];
    total = Length[results];

    (* Print individual results *)
    Scan[
        Function[result,
            Print[
                Switch[result["Outcome"],
                    "Success", "  PASS ",
                    "Failure", "  FAIL ",
                    _, "  WARN "
                ],
                result["TestID"]
            ];
            If[ result["Outcome"] =!= "Success",
                Print["      Expected: ", InputForm[result["ExpectedOutput"]]];
                Print["      Actual:   ", InputForm[result["ActualOutput"]]];
                If[ result["ExpectedMessages"] =!= {} || result["ActualMessages"] =!= {},
                    Print["      Messages: ", result["ActualMessages"]]
                ]
            ]
        ],
        Values[results]
    ];

    Print[""];
    Print["  Results: ", passed, "/", total, " passed"];
    If[failed > 0, Print["  Failed:  ", failed]];
    If[errors > 0, Print["  Errors:  ", errors]];

    <|"File" -> FileNameTake[file], "Passed" -> passed, "Failed" -> failed, "Errors" -> errors, "Total" -> total|>
];

allResults = runTestFile /@ testFiles;

(* Summary *)
Print[""];
Print["======================================================="];
Print["  Summary"];
Print["======================================================="];

totalPassed = Total[#["Passed"] & /@ allResults];
totalFailed = Total[#["Failed"] & /@ allResults];
totalErrors = Total[#["Errors"] & /@ allResults];
totalTests = Total[#["Total"] & /@ allResults];

Scan[
    Function[result,
        Print[
            "  ", If[result["Failed"] + result["Errors"] == 0, "PASS", "FAIL"],
            " ", result["File"], ": ", result["Passed"], "/", result["Total"]
        ]
    ],
    allResults
];

Print[""];
Print["  Total:  ", totalPassed, "/", totalTests, " passed (",
    ToString[Round[100. totalPassed / totalTests, 0.1]], "%)"];
If[totalFailed > 0, Print["  Failed: ", totalFailed]];
If[totalErrors > 0, Print["  Errors: ", totalErrors]];
Print["======================================================="];

(* Exit with code *)
Exit[If[totalFailed + totalErrors > 0, 1, 0]]
