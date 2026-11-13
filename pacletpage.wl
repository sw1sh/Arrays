(* ::Package:: *)

(* What build.wls and submit.wls share: the repository and paclet directories, PacletPage and
   MarkdownToNotebook, and how the documentation is built.

   Both tools come from their GitHub repositories and from nowhere else: PacletPage as the archive
   of the ref PACLETPAGE_REF names, by default the release tag below, and MarkdownToNotebook as the
   plain .wl of the ref MTN_REF names, by default main. Nothing is read from another checkout on
   this machine or from the Wolfram Cloud, so a build runs the same on a development machine and on
   a runner, and does not depend on the cloud being up. A failed fetch is fatal.

   PacletPage is read from the Kernel file of the copy fetched, not through the paclet manager:
   a paclet directory loaded beside installed copies of the same paclet loses to an installed
   version newer than its own, and PacletPage finds its other files relative to the file it was
   read from. *)

$repositoryDirectory = DirectoryName[$InputFileName];
$pacletDirectory = FileNameJoin[{$repositoryDirectory, "Arrays"}];
$toolsDirectory = FileNameJoin[{$repositoryDirectory, "build", "tools"}];

$pacletPageRef = Replace[Environment["PACLETPAGE_REF"], Except[_String?(StringLength[#] > 0 &)] -> "v0.3.69"];
$markdownToNotebookRef = Replace[Environment["MTN_REF"], Except[_String?(StringLength[#] > 0 &)] -> "main"];

(* a URL's body written to a file, or the script stops; the network is enabled for this kernel
   alone, since $AllowInternet is a machine-wide setting that other kernels switch off *)
fetchToFile[url_String, file_String] := With[{response = Block[{$AllowInternet = True}, URLRead[url]]},
    If[ ! MatchQ[response, _HTTPResponse] || response["StatusCode"] =!= 200,
        Print["FATAL: could not fetch ", url, ": ", Replace[response, r_HTTPResponse :> r["StatusCode"]]];
        Exit[1]
    ];
    Quiet @ CreateDirectory[DirectoryName[file], CreateIntermediateDirectories -> True];
    If[FileExistsQ[file], DeleteFile[file]];
    BinaryWrite[file, response["BodyByteArray"]];
    Close[file];
    file
];

refFileName[ref_String] := StringReplace[ref, Except[WordCharacter | "." | "-"] -> "_"];

(* PacletPage's archive extracted afresh into build/tools, and its one top directory *)
fetchPacletPage[ref_String] := Module[{zip, target, tops},
    zip = fetchToFile[
        "https://github.com/WolframInstitute/PacletPage/archive/" <> ref <> ".zip",
        FileNameJoin[{$toolsDirectory, "PacletPage-" <> refFileName[ref] <> ".zip"}]
    ];
    target = FileNameJoin[{$toolsDirectory, "PacletPage-" <> refFileName[ref]}];
    If[DirectoryQ[target], DeleteDirectory[target, DeleteContents -> True]];
    ExtractArchive[zip, target];
    tops = Select[FileNames["*", target], DirectoryQ];
    If[ Length[tops] =!= 1 || ! FileExistsQ[FileNameJoin[{First[tops], "Kernel", "PacletPage.wl"}]],
        Print["FATAL: the PacletPage archive of ", ref, " holds no PacletPage paclet."];
        Exit[1]
    ];
    First[tops]
];

fetchMarkdownToNotebook[ref_String] := With[{file = fetchToFile[
        "https://raw.githubusercontent.com/WolframInstitute/MarkdownToNotebook/" <> ref <> "/MarkdownToNotebook.wl",
        FileNameJoin[{$toolsDirectory, "MarkdownToNotebook-" <> refFileName[ref] <> ".wl"}]
    ]},
    If[ ! StringContainsQ[ReadString[file], "MarkdownToNotebook"],
        Print["FATAL: the MarkdownToNotebook file of ", ref, " is not the converter."];
        Exit[1]
    ];
    file
];

$pacletPageDirectory = fetchPacletPage[$pacletPageRef];
$markdownToNotebook = fetchMarkdownToNotebook[$markdownToNotebookRef];

Get[FileNameJoin[{$pacletPageDirectory, "Kernel", "PacletPage.wl"}]];

If[ ! MemberQ[$Packages, "WolframInstitute`PacletPage`"],
    Print["FATAL: PacletPage did not load from ", $pacletPageDirectory];
    Exit[1]
];

Print["PacletPage ", $pacletPageRef, ", MarkdownToNotebook ", $markdownToNotebookRef];

(* The pages are the markdown under docs/, and the definition is docs/ResourceDefinition.md,
   converted by the MarkdownToNotebook just fetched. Each page's examples run in one context, the
   later sections seeing what the earlier ones define, which is how the pages are written: a Scope
   example uses the container a Basic Example built. The pages convert in this kernel alone, the
   default for a machine others share and for a runner whose entitlement counts kernel launches;
   PACLETPAGE_PARALLEL gives a number of parallel kernels instead. *)
$documentationOptions = {
    "Source" -> FileNameJoin[{$repositoryDirectory, "docs"}],
    "Converter" -> $markdownToNotebook,
    "EvaluateSeparator" -> None,
    "Parallel" -> Replace[Environment["PACLETPAGE_PARALLEL"], {
        n_String /; StringMatchQ[n, DigitCharacter ..] && FromDigits[n] > 0 :> FromDigits[n],
        _ -> False
    }]
};
