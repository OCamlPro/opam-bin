(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat
open Ezcmd.TYPES
       (*
open EzFile.OP
open SimpleConfig.OP
open OpamParserTypes
*)

let cmd_name = "wrap-install"

(*
TODO:
* Check if the archive already exists
  * if 'bin-package.version' exists, we are in a binary archive,
      execute all commands.
  * if etc/opam-bin/packages/NAME exists, don't do anything
  * otherwise, check if a binary archive exists.
     If no, create an empty
       `bin-package.version` file to force execution of all commands.
     If yes, in wrap-install, perform the installation of the archive.
*)

let action args =
  OpambinMisc.global_log "CMD: %s\n%!"
    ( String.concat "\n    " ( cmd_name :: args) ) ;
  OpambinMisc.make_cache_dir ();
  match args with
  | name :: version :: package_uid :: depends :: cmd ->
    ignore (name, version, package_uid, depends);
    OpambinMisc.call (Array.of_list cmd)
  | _ ->
    Printf.eprintf
      "Unexpected args: usage is '%s %s name version package_uid depends cmd...'\n%!" OpambinGlobals.command cmd_name;
    exit 2

let cmd =
  let args = ref [] in
  Arg.{
  cmd_name ;
  cmd_action = (fun () -> action !args) ;
  cmd_args = [
    [], Anons (fun list -> args := list),
    Ezcmd.info "args"
  ];
  cmd_man = [];
  cmd_doc = "(opam hook) Exec or not build commands";
}
