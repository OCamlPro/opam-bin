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

let install_exe () =
  let s = FileString.read_file Sys.executable_name in
  EzFile.write_file OpambinGlobals.opambin_bin s;
  Unix.chmod  OpambinGlobals.opambin_bin 0o755;
  Printf.eprintf "Executable copied as %s\n%!" OpambinGlobals.opambin_bin;
  EzFile.make_dir ~p:true OpambinGlobals.opam_plugins_bin_dir ;
  OpambinMisc.call [|
    "ln"; "-sf" ;
    ".." // OpambinGlobals.command // OpambinGlobals.command_exe ;
    OpambinGlobals.opam_plugins_bin_dir // OpambinGlobals.command
  |]

let install_hooks () =

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
    )

let install_repos () =

  add_repo ~repo:"local-bin"
    ~url:( Printf.sprintf "file://%s"
             OpambinGlobals.opambin_store_repo_dir )

let install_patches () =
  let patches_url = !!OpambinConfig.patches_url in
  if EzString.starts_with patches_url ~prefix:"file://" then
    (* nothing to do *)
    ()
  else
  if EzString.starts_with patches_url ~prefix:"git@"
  || EzString.starts_with patches_url ~prefix:"https://"
  || EzString.starts_with patches_url ~prefix:"http://"
  then
    let opambin_patches_dir = OpambinGlobals.opambin_patches_dir in
    OpambinMisc.call [| "rm"; "-rf"; opambin_patches_dir ^ ".tmp" |];
    OpambinMisc.call
      [| "git"; "clone" ; patches_url ; opambin_patches_dir ^ ".tmp" |];
    OpambinMisc.call [| "rm"; "-rf"; opambin_patches_dir |];
    OpambinMisc.call
      [| "mv"; opambin_patches_dir ^ ".tmp"; opambin_patches_dir |]
  else
    begin
      Printf.eprintf
        "Error: patches_url '%s' should either be local (file://) or git (git@, http[s]://)\n%!" patches_url;
      exit 2
    end


let action args =
  Printf.eprintf "%s\n\n%!" OpambinGlobals.about ;

  EzFile.make_dir ~p:true OpambinGlobals.opambin_dir ;
  OpambinConfig.save ();

  EzFile.make_dir ~p:true OpambinGlobals.opambin_cache_dir;
  EzFile.make_dir ~p:true OpambinGlobals.opambin_store_repo_packages_dir;
  EzFile.write_file ( OpambinGlobals.opambin_store_repo_dir // "repo" )
    {|
opam-version: "2.0"
archive-mirrors: "../../cache"
|};
  EzFile.write_file ( OpambinGlobals.opambin_store_repo_dir // "version" )
    "0.9.0";

  match args with
  | [] ->
    install_exe ();
    install_hooks ();
    install_repos ();
    install_patches ()
  | _ ->
    List.iter (function
        | "exe" -> install_exe ()
        | "hooks" -> install_hooks ()
        | "repos" -> install_repos ()
        | "patches" -> install_patches ()
        | s ->
          Printf.eprintf "Error: unexpected argument %S" s;
          exit 2)
      args

let cmd =
  let anon_args = ref [] in
  {
    cmd_name ;
    cmd_action = (fun () -> action !anon_args) ;
    cmd_args = [

      [], Anons (fun list -> anon_args := list),
      Ezcmd.info "No args = all, otherwise 'exe', 'hooks' and/or 'repos'";

    ];
    cmd_man = [];
    cmd_doc = "install in opam";
  }
