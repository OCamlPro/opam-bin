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
open EzFile.OP
open EzConfig.OP

let cmd_name = "install"

let add_repo ~repo ~url =
  if Sys.file_exists (OpambinGlobals.opam_repo_dir // repo ) then
    OpambinMisc.call
      [| "opam"; "remote" ; "set-url" ; repo;
         "--all"; "--set-default"; url |]
  else
    OpambinMisc.call
      [| "opam"; "remote" ; "add" ; repo ;
         "--all"; "--set-default"; url |]

let action () =
  Printf.eprintf "%s\n\n%!" OpambinGlobals.about ;

  EzFile.make_dir OpambinGlobals.opambin_dir ;
  OpambinConfig.save ();

  let s = FileString.read_file Sys.executable_name in
  FileString.write_file OpambinGlobals.opambin_bin s;
  Unix.chmod OpambinGlobals.opambin_bin 0o755;
  Printf.eprintf "Executable copied as %s\n%!"
    OpambinGlobals.opambin_bin;

  OpambinMisc.change_opam_config (fun file_contents ->
      let file_contents =
        match OpambinCommandUninstall.remove_opam_hooks file_contents with
        | None -> file_contents
        | Some file_contents -> file_contents
      in
      Printf.eprintf "Adding %s hooks\n%!" OpambinGlobals.command;
      Some (
        List.rev @@
        OpambinMisc.opam_variable "pre-build-commands"
          {| ["%s" "pre-build" name version depends] {?build-id} |}
          OpambinGlobals.opambin_bin ::
        OpambinMisc.opam_variable "wrap-build-commands"
          {| ["%s" "wrap-build" name version depends "--"] {?build-id} |}
          OpambinGlobals.opambin_bin ::
        OpambinMisc.opam_variable "pre-install-commands"
          {| ["%s" "pre-install" name version depends] {?build-id} |}
          OpambinGlobals.opambin_bin ::
        OpambinMisc.opam_variable "wrap-install-commands"
          {| ["%s" "wrap-install" name version depends "--"] {?build-id} |}
          OpambinGlobals.opambin_bin ::
        OpambinMisc.opam_variable "post-install-commands"
          {| ["%s" "post-install" name version depends installed-files] {?build-id & error-code = 0} |}
          OpambinGlobals.opambin_bin  ::
        OpambinMisc.opam_variable "pre-remove-commands"
          {| ["%s" "pre-remove" name version depends] {?build-id} |}
          OpambinGlobals.opambin_bin ::
        List.rev file_contents
      )
    );

  EzFile.make_dir ~p:true OpambinGlobals.opambin_cache_dir;
  EzFile.make_dir ~p:true OpambinGlobals.opambin_store_repo_packages_dir;
  EzFile.write_file ( OpambinGlobals.opambin_store_repo_dir // "repo" )
    {|
opam-version: "2.0"
archive-mirrors: "../../cache"
|};
  EzFile.write_file ( OpambinGlobals.opambin_store_repo_dir // "version" )
    "0.9.0";

  add_repo ~repo:"default" ~url:!!OpambinConfig.reloc_repo_url ;

  add_repo ~repo:"local-bin"
    ~url:( Printf.sprintf "file://%s"
             OpambinGlobals.opambin_store_repo_dir )

let cmd = {
  cmd_name ;
  cmd_action = action ;
  cmd_args = [];
  cmd_man = [];
  cmd_doc = "install in opam";
}
