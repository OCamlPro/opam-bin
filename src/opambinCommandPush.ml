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
open EzConfig.OP
open EzFile.OP

let action ~delete =

  match !!OpambinConfig.rsync_url with
  | None ->
    Printf.eprintf
      "Error: you must define the remote url with `%s config --rsync-url`\n%!"
      OpambinGlobals.command ;
    exit 2
  | Some rsync_url ->
    let args = [ "rsync"; "-auv" ; "--progress" ] in
    let args = if !delete then
        args @ [ "--delete" ]
      else
        args
    in
    let args = args @ [
        OpambinGlobals.opambin_store_dir // "." ;
        rsync_url
      ] in
    Printf.eprintf "Calling '%s'\n%!"
      (String.concat " " args);
    OpambinMisc.call (Array.of_list args);
    Printf.eprintf "Done.\n%!";
    ()

let cmd =
  let delete = ref false in
  {
    cmd_name = "push" ;
    cmd_action = (fun () -> action ~delete) ;
    cmd_args = [

      [ "delete" ], Arg.Set delete,
      Ezcmd.info "Delete non-existent files on the remote side";
    ];
    cmd_man = [];
    cmd_doc = "push binary packages to the remote server";
  }
