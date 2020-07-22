(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.TYPES

let action args =
  OpambinMisc.global_log "CMD: %s"
    ( String.concat "\n    " ( "pre-build" :: args) ) ;
  (* TODO: create a source archive *)
  ()

let cmd =
  let args = ref [] in
  Arg.{
  cmd_name = "pre-build" ;
  cmd_action = (fun () -> action !args) ;
  cmd_args = [
    [], Anons (fun list -> args := list),
    Ezcmd.info "args"
  ];
  cmd_man = [];
  cmd_doc = "(opam hook) Backup the sources before building the package";
}
