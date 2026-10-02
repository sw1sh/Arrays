#!/usr/bin/env wolframscript
(* Submit the Wolfram/Arrays paclet to the Wolfram Paclet Repository.

   The submission artifact is Arrays/ResourceDefinition.nb, generated from
   docs/ResourceDefinition.md by build_docs.wls - edit the markdown and
   rebuild before submitting, never the notebook.

   Run with:

       wolframscript -f submit.wls
*)

repoDir = DirectoryName[$InputFileName]

nbFile = FileNameJoin[{repoDir, "Arrays", "ResourceDefinition.nb"}]

If[ ! FileExistsQ[nbFile],
    Print["FATAL: ", nbFile, " does not exist; run build_docs.wls first."];
    Exit[1]
]

Needs["DefinitionNotebookClient`"]

(* The paclet is published under PublisherID "Wolfram", so it has to be
   submitted from an account that is a member of that publisher; any other
   login passes every client-side check and is refused by the repository with
   ResourceObject::apierr. WOLFRAM_CLOUD_USER and WOLFRAM_CLOUD_PASSWORD, where
   both are set, name the account to submit from; otherwise the stored login is
   used. The password is read from the environment and never printed. *)

$submitUser = Environment["WOLFRAM_CLOUD_USER"]

If[ StringQ[$submitUser] && StringQ[Environment["WOLFRAM_CLOUD_PASSWORD"]],
    Quiet @ CloudConnect[$submitUser, Environment["WOLFRAM_CLOUD_PASSWORD"]];
    If[ $WolframID =!= $submitUser,
        Print["FATAL: could not connect as ", $submitUser, " from WOLFRAM_CLOUD_USER."];
        Exit[1]
    ],
    If[! TrueQ[$CloudConnected], CloudConnect[]]
]

If[ ! TrueQ[$CloudConnected],
    Print["FATAL: not cloud connected."];
    Exit[1]
]

Print["submitting as ", $WolframID]

(* The pre-submission check first: a submission with outstanding errors is
   rejected by the repository anyway, so failing here is strictly cheaper.
   Suggestions (such as PacletFilesChanged after a rebuild) do not block. *)

check = UsingFrontEnd @ Block[{nb, r},
    nb = NotebookOpen[nbFile, Visible -> False];
    r = DefinitionNotebookClient`CheckDefinitionNotebook[nb];
    NotebookClose[nb];
    r
]

issues = Normal[check]

Scan[Print["  [", #Level, "] ", #Tag] &, issues]

If[ MemberQ[issues[[All, "Level"]], "Error"],
    Print["FATAL: the definition notebook has errors; fix them before submitting."];
    Exit[1]
]

result = UsingFrontEnd @ Block[{nb, r, DefinitionNotebookClient`ConfirmIssuesDialog = (True &)},
    nb = NotebookOpen[nbFile, Visible -> False];
    r = DefinitionNotebookClient`SubmitRepository[nb];
    NotebookClose[nb];
    r
]

submission = FirstCase[result, _Success, Missing["NotFound"], Infinity]

If[ MatchQ[submission, _Success],
    Print["submitted:"];
    KeyValueMap[Print["  ", #1, ": ", #2] &, KeyDrop[Last[submission], "Message"]],
    Print["SUBMISSION DID NOT SUCCEED:"];
    Print[result];
    Exit[1]
]
