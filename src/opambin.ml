(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let commands = [
  OpambinCommandConfig.cmd ;
  OpambinCommandInstall.cmd ;
  OpambinCommandUninstall.cmd ;
  OpambinCommandPush.cmd ;
  OpambinCommandClean.cmd ;

  OpambinCommandPreBuild.cmd ;
  OpambinCommandWrapBuild.cmd ;
  OpambinCommandWrapInstall.cmd ;
  OpambinCommandPostInstall.cmd ;
  OpambinCommandPreRemove.cmd ;
]


let () =
  match Sys.argv with
  | [| _ ; "--version" |] ->
    Printf.printf "%s\n%!" OpambinGlobals.version
  | [| _ ; "--about" |] ->
    Printf.printf "%s\n%!" OpambinGlobals.about
  | _ ->
    try
      Ezcmd.main_with_subcommands
        ~name:OpambinGlobals.command
        ~version:OpambinGlobals.version
        ~doc:"Create binary archives of OPAM source packages"
        ~man:[]
        commands
    with
      exn ->
      OpambinMisc.global_log "fatal exception %s"
        (Printexc.to_string exn)
