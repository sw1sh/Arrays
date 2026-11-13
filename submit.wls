#!/usr/bin/env wolframscript
(* Submits Wolfram/Arrays to the Wolfram Paclet Repository with PacletPage's SubmitPacletResource:
   the definition notebook's own check, a fresh PacletBuild into Arrays/build checked to hold every
   documentation page and to load alone in a fresh kernel, then the submission under the version in
   Arrays/PacletInfo.wl, which has to be newer than every version the repository has. Build the
   documentation with build.wls first.

       wolframscript -f submit.wls              (or --dry-run: everything but the submission)

   The paclet is published under PublisherID "Wolfram", so the kernel has to be connected to the
   Wolfram Cloud as an account that owns that publisher; the repository refuses any other. A dry
   run in a kernel with no cloud connection runs offline: it builds the archive and loads it,
   without the notebook check and the scrape, which need a session. That is how the GitHub
   workflow builds the .paclet it releases. *)

$ProgressReporting = False

Get[FileNameJoin[{DirectoryName[$InputFileName], "pacletpage.wl"}]]

dryRun = MemberQ[$ScriptCommandLine, "--dry-run"]

Print[
    If[dryRun, "dry run", "submission"], ", ",
    If[TrueQ[$CloudConnected], "connected as " <> ToString[$WolframID], "offline"]
]

(* the version check, the definition notebook's check and the submission reach the network,
   which $AllowInternet, a machine-wide setting other kernels switch off, may have closed *)
result = Block[{$AllowInternet = True}, SubmitPacletResource[$pacletDirectory, "DryRun" -> dryRun]]

If[ ! AssociationQ[result],
    Print["FATAL: nothing was ", If[dryRun, "built", "submitted"], "."];
    Exit[1]
]

Print[result["Name"], " ", result["Version"], ": ", If[TrueQ[result["Submitted"]], "submitted", "not submitted (dry run)"]]
Print["archive: ", result["Archive"], ", ", result["Pages"], " documentation pages"]
If[ KeyExistsQ[result, "Result"], Print["result: ", result["Result"]]]
