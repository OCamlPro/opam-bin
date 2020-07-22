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
open SimpleConfig.OP
open OpamParserTypes

let cmd_name = "post-install"

(* TODO
   * Add a 'conflicts: [ depend ]' for every depend that is listed in
`   'depopts' but not in the actual depends.
   * Add a 'depends: [ depend ]' for every depend that is not listed
   in actual depends (probably a post).

*)

let parse_opam_file file_name =
  if Sys.file_exists file_name then begin
    let opam = OpamParser.file file_name in
    OpambinMisc.global_log "%s read" opam.file_name;
    opam.file_contents
  end else begin
    OpambinMisc.global_log "%s does not exist" file_name;
    []
  end

let add_conflict depends conflicts_ref name _option =
  if EzCompat.StringSet.mem name depends then
    ()
  else
    conflicts_ref := name :: !conflicts_ref

let rec is_post_option = function
  | Ident (_, "post" ) -> true
  | Logop  (_, `And, v1, v2 ) -> is_post_option v1 || is_post_option v2
  | _ -> false

let add_post_depend depends post_depends name option =
  if EzCompat.StringSet.mem name depends ||
     not (List.exists is_post_option option) then
    ()
  else
    post_depends := name :: !post_depends

let iter_value_list v f =
  let iter_value v =
    match v with
    | String (_, name) -> f name [ String ( ("",0,0), "") ]
    | Option (_, String (_, name), option) -> f name option
    | _
      ->
      OpambinMisc.global_log "warning: unexpected depend value %s"
        ( OpamPrinter.value v)
  in
  match v with
  | List (_, values) ->
    List.iter iter_value values
  | v -> iter_value v

let digest s = Digest.to_hex ( Digest.string s)

let compute_hash ~name ~version ~package_uid ~depends =
  let missing_versions = ref [] in
  let opam_switch_prefix = OpambinMisc.opam_switch_prefix () in
  let packages_dir =
    OpambinGlobals.opambin_switch_packages_dir ~opam_switch_prefix in
  OpambinMisc.global_log "depends: %S" depends;
  let depends = EzString.split depends ' ' in
  let dependset = ref EzCompat.StringSet.empty in
  let depends = List.map (fun nv ->
      let name, _ = EzString.cut_at nv '.' in
      let file_name = packages_dir // name in
      let version = match
          open_in file_name
        with
        | exception _ ->
          missing_versions := file_name :: !missing_versions;
          "UNKNOWN"
        | ic ->
          let version = input_line ic in
          close_in ic;
          version
      in
      dependset := EzCompat.StringSet.add name !dependset;
      ( name, version )
    ) depends in
  let depends_nv = List.map (fun ( name, version ) ->
      Printf.sprintf "%s.%s" name version
    ) depends in

  let source_md5 =
    digest (
      Printf.sprintf "%s.%s|%s|%s"
        name version package_uid (String.concat "," depends_nv)) in
  ( source_md5, depends, !dependset, !missing_versions )

let commit ~name ~version ~package_uid ~depends files =
  if not !!OpambinConfig.create_enabled then
    OpambinMisc.global_log "package %s: create disabled" name
  else
    let opam_switch_prefix = OpambinMisc.opam_switch_prefix () in
    let packages_dir =
      OpambinGlobals.opambin_switch_packages_dir ~opam_switch_prefix in
    if Sys.file_exists ( packages_dir // name ) then
      OpambinMisc.global_log "package %s: already a binary archive..." name
    else
      let nv = Printf.sprintf "%s.%s" name version in

      OpambinMisc.global_log "creating binary archive...";
      let temp_dir = OpambinGlobals.opambin_switch_temp_dir ~opam_switch_prefix in
      EzFile.make_dir ~p:true temp_dir ;
      let binary_archive = temp_dir // name ^ "-bin.tar.gz" in
      Unix.chdir opam_switch_prefix;
      OpambinMisc.tar_zcf
        ~prefix:OpambinGlobals.package_cached binary_archive files;
      Unix.chdir OpambinGlobals.curdir;
      OpambinMisc.global_log "create binary archive DONE";

      let short s = String.sub s 0 8 in
      let bin_md5 =
        digest ( EzFile.read_file binary_archive )
      in
      OpambinMisc.global_log "bin md5 = %s" bin_md5;

      let ( source_md5, depends, dependset, missing_versions ) =
        compute_hash ~name ~version ~package_uid ~depends in
      if missing_versions <> [] then begin
        Printf.eprintf "Error in %s: cannot load binary versions from %s\n%!"
          OpambinGlobals.command
          (String.concat " " missing_versions);
        exit 2
      end;
      let final_md5 = Printf.sprintf "%s+%s"
          ( short source_md5 ) ( short bin_md5 ) in
      let new_version = Printf.sprintf "%s+bin+%s" version final_md5 in
      EzFile.make_dir ~p:true packages_dir ;
      let oc = open_out ( packages_dir // name ) in
      output_string oc new_version ;
      close_out oc;

      let switch =
        let switch = Filename.basename opam_switch_prefix in
        if String.lowercase switch = "_opam" then
          opam_switch_prefix
        else switch
      in
      let opam_file = temp_dir // name ^ "-src.opam" in
      let oc = Unix.openfile opam_file
          [ Unix.O_CREAT; Unix.O_WRONLY ; Unix.O_TRUNC ] 0o644 in
      OpambinMisc.call ~stdout:oc
        [| "opam" ; "show" ; nv ; "--raw" ; "--safe" ; "--switch" ; switch |];
      Unix.close oc;
      OpambinMisc.global_log "File:\n%s" (EzFile.read_file opam_file);
      let file_contents = parse_opam_file opam_file in

      EzFile.make_dir ~p:true OpambinGlobals.opambin_store_archives_dir;
      let final_binary_archive_basename =
        Printf.sprintf "%s.%s-bin.tar.gz" name new_version
      in
      let final_binary_archive =
        OpambinGlobals.opambin_store_archives_dir // final_binary_archive_basename
      in
      Sys.rename binary_archive final_binary_archive;

      let cache_dir =
        OpambinGlobals.opambin_cache_dir //
        "md5" // String.sub bin_md5 0 2 in
      let cached_archive = cache_dir // bin_md5 in
      if not ( Sys.file_exists cached_archive ) then begin
        EzFile.make_dir ~p:true cache_dir;
        OpambinMisc.call [| "cp";  final_binary_archive ; cached_archive |];
      end;

      let nv = Printf.sprintf "%s.%s" name new_version in
      let package_dir =
        OpambinGlobals.opambin_store_repo_packages_dir // name // nv in
      EzFile.make_dir ~p:true package_dir;
      let package_files_dir = package_dir // "files" in
      EzFile.make_dir ~p:true package_files_dir;
      let oc = open_out ( package_files_dir //
                          OpambinGlobals.package_version ) in
      output_string oc new_version;
      close_out oc;

      let config_file =
        opam_switch_prefix // ".opam-switch" // "config" // ( name ^ ".config" )
      in
      let has_config_file =
        if Sys.file_exists config_file then begin
          let s = EzFile.read_file config_file in
          EzFile.write_file ( package_files_dir //
                              OpambinGlobals.package_config ) s;
          true
        end
        else
          false
      in

      let opam =
        let post_depends = ref [] in
        let conflicts = ref [] in
        let file_contents =
          List.fold_left (fun acc v ->
              match v with
              | Variable (_, name, value) -> begin
                  match name with

                  (* keep *)
                  | "name"
                  | "maintainer"
                  | "authors"
                  | "opam-version"
                  | "synopsis"
                  | "description"
                  | "homepage"
                  | "bug-reports"
                  | "license"
                  | "tags" (* ?? *)
                  | "dev-repo"
                  | "post-messages"
                  | "doc"
                  | "setenv"
                  | "conflict-class"
                  | "flags"
                  | "depexts"
                    -> v :: acc

                  (* discard *)
                  | "version"
                  | "build"
                  | "install"
                  | "remove"
                  | "extra-files"
                    ->
                    acc
                  | "depends" ->
                    iter_value_list value
                      ( add_post_depend dependset post_depends);
                    acc
                  | "depopts" ->
                    iter_value_list value
                      ( add_conflict dependset conflicts);
                    acc
                  | _ ->
                    OpambinMisc.global_log
                      "discarding unknown field %S" name;
                    acc
                end
              | _ -> acc
            ) [] file_contents in

        (* We need to keep `package.version` here because it is used by
           wrap-build to check if it is a binary archive. It should
           always be the last step because wrap-install checks for
           etc/opam-bin/packages/NAME to stop installation commands. *)
        let file_contents =
          OpambinMisc.opam_variable "install"
            {|
[
  [  "mkdir" "-p" "%%{prefix}%%/etc/%s/packages" ]
  [  "cp" "-aT" "." "%%{prefix}%%" ]%s
  [  "mv" "%%{prefix}%%/%s" "%%{prefix}%%/etc/%s/packages/%s" ]
]
|}
            OpambinGlobals.command
            (if has_config_file then
               Printf.sprintf {|
  [  "mkdir" "-p" "%%{prefix}%%/.opam-switch/config" ]
  [  "mv" "%%{prefix}%%/%s" "%%{prefix}%%/.opam-switch/config/%s.config" ]
|}
                 OpambinGlobals.package_config name
             else "")
            OpambinGlobals.package_version OpambinGlobals.command name
          :: file_contents
        in
        let file_contents =
          OpambinMisc.opam_variable "depends"
            "[ %s %s ]"
            (String.concat " "
               (List.map (fun (name, version) ->
                    Printf.sprintf "%S {= %S }" name version
                  ) depends))
            (String.concat " "
               (List.map (fun name ->
                    Printf.sprintf "%S { post }" name
                  ) !post_depends))
          :: file_contents
        in

        let file_contents =
          if files = [] then
            file_contents
          else
            OpambinMisc.opam_section "url" [
              OpambinMisc.opam_variable
                "src"
                "%S"
                (!!OpambinConfig.base_url
                 // "archives" // final_binary_archive_basename);
              OpambinMisc.opam_variable
                "checksum"
                {| [ "md5=%s" ] |} bin_md5
            ] :: file_contents
        in

        let file_contents =
          if !conflicts = [] then
            file_contents
          else
            OpambinMisc.opam_variable "conflicts"
              "[ %s ]"
              ( String.concat " "
                  ( List.map (fun s ->
                        Printf.sprintf "%S" s) !conflicts ))
            :: file_contents
        in

        let file_contents = List.rev file_contents in
        { file_contents ; file_name = "" }
      in
      let s = OpamPrinter.opamfile opam in

      EzFile.write_file ( package_dir // "opam" ) s;

      begin
        let bin_name = name ^ "+bin" in
        let nv = Printf.sprintf "%s.%s" bin_name version in
        let package_dir =
          OpambinGlobals.opambin_store_repo_packages_dir // bin_name // nv in
        EzFile.make_dir ~p:true package_dir;
        let s = Printf.sprintf {|
opam-version: "2.0"
name: %S
maintainer: "%s"
description: "This package is an alias for %s binary package"
depends: [
   %S {= %S }
]
|}
            bin_name
            OpambinGlobals.command
            name
            name new_version in
        EzFile.write_file ( package_dir // "opam" ) s;
      end

let action args =
  OpambinMisc.global_log "CMD: %s\n%!"
    ( String.concat "\n    " ( cmd_name :: args) ) ;
  OpambinMisc.make_cache_dir ();
  match args with
  | name :: version :: package_uid :: depends :: files ->
    commit ~name ~version ~package_uid ~depends files
  | _ ->
    Printf.eprintf
      "Unexpected args: usage is '%s %s name version package_uid depends files...'\n%!" OpambinGlobals.command cmd_name;
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
  cmd_doc = "(opam hook) Create binary archive after install";
}
