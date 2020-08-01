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
  OpambinCommandPull.cmd ;
  OpambinCommandClean.cmd ;
  OpambinCommandList.cmd ;
  OpambinCommandSearch.cmd ;

  OpambinCommandPreBuild.cmd ;
  OpambinCommandWrapBuild.cmd ;
  OpambinCommandPreInstall.cmd ;
  OpambinCommandWrapInstall.cmd ;
  OpambinCommandPostInstall.cmd ;
  OpambinCommandPreRemove.cmd ;
]


let () =
  Printexc.record_backtrace true;
  match Sys.argv with
  | [| _ ; "--version" |] ->
    Printf.printf "%s\n%!" OpambinGlobals.version
  | [| _ ; "--about" |] ->
    Printf.printf "%s\n%!" OpambinGlobals.about
  | _ ->
(*    OpambinMisc.global_log "args: %s"
      (String.concat " " (Array.to_list Sys.argv)); *)
    try
      Ezcmd.main_with_subcommands
        ~name:OpambinGlobals.command
        ~version:OpambinGlobals.version
        ~doc:"Create binary archives of OPAM source packages"
        ~man:[]
        commands
    with
      exn ->
      let bt = Printexc.get_backtrace () in
      let error = Printexc.to_string exn in
      Printf.eprintf "fatal exception %s\n%s\n%!" error bt ;
      OpambinMisc.global_log "fatal exception %s\n%s" error bt;
      exit 2
