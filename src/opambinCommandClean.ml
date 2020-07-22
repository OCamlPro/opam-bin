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

let action () =
  List.iter (fun dir ->
      Printf.eprintf "Cleaning %s\n%!" dir;
      OpambinMisc.call [| "rm"; "-rf" ; dir |];
      EzFile.make_dir dir ;
    )
    [ OpambinGlobals.opambin_cache_dir ;
      OpambinGlobals.opambin_store_repo_packages_dir ;
      OpambinGlobals.opambin_store_archives_dir ;
    ];

  ()

let cmd = {
  cmd_name = "clean" ;
  cmd_action = action ;
  cmd_args = [];
  cmd_man = [];
  cmd_doc = "clear all packages and archives from the cache and store";
}
