#!/usr/bin/env wolframscript
(* Publishes the Wolfram/Arrays documentation site with PacletPage's PublishPacletPage, in one
   kernel and so one cloud account: builds the documentation as build.wls does, deploys the paclet
   resource to the connected account, publishes the documentation site around it with the
   authoring notebooks as its sources, and checks every page of the site. The submission to the
   Paclet Repository is submit.wls's.

       wolframscript -f release.wls             (or --dry-run: the build and the resource, not deployed)

   The kernel has to be connected to the Wolfram Cloud as the account the site is published in.
   PACLETPAGE_ACCOUNT, where it is set, names the only account accepted. *)

$ProgressReporting = False

Get[FileNameJoin[{DirectoryName[$InputFileName], "pacletpage.wl"}]]

account = Replace[Environment["PACLETPAGE_ACCOUNT"], Except[_String?(StringLength[#] > 0 &)] -> Automatic]

(* the deploy, the site and the check reach the cloud, which $AllowInternet, a machine-wide
   setting other kernels switch off, may have closed *)
result = Block[{$AllowInternet = True},
    PublishPacletPage[$pacletDirectory, "WolframArrays",
        "Account" -> account,
        "DryRun" -> MemberQ[$ScriptCommandLine, "--dry-run"],
        "Monitor" -> True,
        "BuildOptions" -> $documentationOptions,
        "SiteOptions" -> {
            "FeedbackOptions" -> {"Domains" -> {"wolframinstitute.org", "wolfram.com"}},
            "VersionLabel" -> True,
            "Footer" -> True
        }
    ]
]

If[ ! AssociationQ[result],
    Print["FATAL: nothing was published."];
    Exit[1]
]

Print["documentation: ", Length[result["Build"]["Notebooks"]], " pages, failed ", result["Build"]["Failed"]]
Print["resource: ", result["Resource"]["Resource"], If[TrueQ[result["Resource"]["Deployed"]], "", " (dry run)"]]
If[ AssociationQ[result["Site"]], Print["site: ", result["Site"]["Site"]]]

If[ AssociationQ[result["Check"]],
    Scan[Print["check failed: ", #["Check"], ": ", #["Detail"]] &, Select[Normal[result["Check"]["Checks"]], ! TrueQ[#["OK"]] &]];
    Print["check: ", If[TrueQ[result["Check"]["OK"]], "everything is reachable", "problems found"]];
    Exit[If[TrueQ[result["Check"]["OK"]], 0, 1]]
]
