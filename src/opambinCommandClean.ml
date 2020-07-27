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

let cmd_name = "clean"

let clean_log () =
  Sys.remove OpambinGlobals.opambin_log ;
  ()

let clean_all () =
  List.iter (fun dir ->
      Printf.eprintf "Cleaning %s\n%!" dir;
      OpambinMisc.call [| "rm"; "-rf" ; dir |];
      EzFile.make_dir dir ;
    )
    [ OpambinGlobals.opambin_cache_dir ;
      OpambinGlobals.opambin_store_repo_packages_dir ;
      OpambinGlobals.opambin_store_archives_dir ;
    ];
  clean_log ();
  (* flush the copy of the repo that opam keeps *)
  OpambinMisc.call [| "opam"; "update" |];
  ()

let action args =
  match args with
  | [] -> clean_all ()
  | _ ->
    List.iter (function
        | "all" -> clean_all ()
        | "log" -> clean_log ()
        | s ->
          Printf.eprintf "Unexpected argument %S.\n%!" s;
          exit 2) args

let cmd =
  let anon_args = ref [] in
  {
  cmd_name ;
  cmd_action = (fun () -> action !anon_args) ;
  cmd_args = [
    [], Arg.Anons (fun list -> anon_args := list),
    Ezcmd.info "What to clean (`all` or `log`)";
  ];
  cmd_man = [];
  cmd_doc = "clear all packages and archives from the cache and store";
}
