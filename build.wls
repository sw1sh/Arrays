#!/usr/bin/env wolframscript
(* Builds the Wolfram/Arrays documentation with PacletPage's BuildPacletDocumentation: every page
   under docs/ into Arrays/Documentation/English, and docs/ResourceDefinition.md into
   Arrays/ResourceDefinition.nb, the definition notebook a submission scrapes. The markdown is the
   source of truth and the notebooks are generated and gitignored. A page whose markdown and the
   code its examples reach are unchanged comes from the cache in Arrays/build/cache.

       wolframscript -f build.wls *)

$ProgressReporting = False

Get[FileNameJoin[{DirectoryName[$InputFileName], "pacletpage.wl"}]]

(* an example that reaches the network needs $AllowInternet, a machine-wide setting other kernels
   switch off *)
result = Block[{$AllowInternet = True},
    BuildPacletDocumentation[$pacletDirectory, Sequence @@ $documentationOptions, "Monitor" -> True]
]

If[ ! AssociationQ[result],
    Print["FATAL: the documentation did not build."];
    Exit[1]
]

Print[
    "documentation: ", Length[result["Notebooks"]], " pages, ",
    Length[result["Converted"]], " converted, ", Length[result["Cached"]], " from the cache"
]

(* a section that uses a name an earlier section defines comes out unevaluated *)
If[ result["Unevaluated"] =!= <||>,
    Print["unevaluated sections: ", result["Unevaluated"]]
]

If[ result["Failed"] =!= {},
    Print["FATAL: pages that did not convert: ", result["Failed"]];
    Exit[1]
]
