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
open EzFile.OP

let cmd_name = "wrap-install"

(* We first perform the same thing as `wrap-build`, to be sure it was
   done at least once. At this point, it returns true if it is a
   source archive and we must perform the actions.
   If it returns false, we check:
   * if `bin-package.cached/` exists, we have found a binary archive in the
     cache. We go in that directory where we should find:
     * `bin-package.version`: we should move this file to
       "%{prefix}%/etc/opam-bin/packages/%{name}%". Once the file has been
       moved, we use its absence as a marker that we shouldn't redo the
       installation
     * `bin-package.config`: optional. to be copied into
      "%{prefix}%/.opam-switch/config/%{name}%.config"
     * a directory: it is the content of the binary archive, to be copied
      into "%{prefix}%"
 *)

let action args =
  OpambinMisc.global_log "CMD: %s\n%!"
    ( String.concat "\n    " ( cmd_name :: args) ) ;
  OpambinMisc.make_cache_dir ();
  match args with
  | name :: _version :: _package_uid :: _depends :: cmd ->
    if Sys.file_exists OpambinGlobals.marker_source then
      OpambinMisc.call (Array.of_list cmd)
    else
    if Sys.file_exists OpambinGlobals.marker_cached then begin
      Unix.chdir OpambinGlobals.marker_cached;
      if Sys.file_exists OpambinGlobals.package_version then
        let files = Sys.readdir "." in
        Array.iter (fun file ->
            if file = OpambinGlobals.package_version then begin
              let packages_dir =
                OpambinGlobals.opambin_switch_packages_dir () in
              EzFile.make_dir ~p:true packages_dir;
              Sys.rename file ( packages_dir // name )
            end
            else
            if file =  OpambinGlobals.package_config then begin
              let config_dir = OpambinGlobals.opam_switch_internal_config_dir
                  () in
              EzFile.make_dir ~p:true config_dir ;
              Sys.rename file ( config_dir // Printf.sprintf "%s.config" name )
            end else
              let pwd = Unix.getcwd () in
              Unix.chdir file ;
              OpambinMisc.call [| "cp" ; "-aT" ; "." ;
                                  OpambinGlobals.opam_switch_dir () |];
              Unix.chdir pwd
          ) files
    end
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
