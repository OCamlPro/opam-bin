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
open OpamParserTypes

let cmd_name = "pre-build"

let cache_file ~cache ~md5 =
  cache // "md5" // String.sub md5 0 2 // md5

let check_cache_file ~cache ~md5 =
  let file = cache_file ~cache ~md5 in
  if Sys.file_exists file then Some file else None

let find_archive_in_cache ~repo ~md5 =
  match check_cache_file ~cache:OpambinGlobals.opam_cache_dir ~md5 with
  | Some file -> Some file
  | None ->
    match check_cache_file ~cache:OpambinGlobals.opambin_cache_dir ~md5 with
    | Some file -> Some file
    | None ->
      ignore repo;
    (* TODO: lookup repo specific caches ?
(* We should read .opam/repos-config to get the URL of the repository:
```
repositories: [
  "default" {"file:///home/---/GIT/opam-repository-relocatable"}
  "local-bin" {"file:///home/---/.opam/opam-bin/store/repo"}
]
```
together with .opam/repo/XXX/repo:
```
opam-version: "2.0"
archive-mirrors: "../../cache"
```
 *)
    match check_cache_file ~cache:(repo // "cache") ~md5 with
    | Some file -> Some file
    | None ->
      match OpamParser.file (repo // "repo") with
      | exception _ -> None
      | Some opam ->
        let cache = ref None in
        List.iter (function
            | Variable ( _, "archive-mirrors" , String ( _, v ) ) ->
              cache := v
          ) opam.file_contents ;
        match !cache with
        | None -> None
        | Some cache ->
*)
      None

let wget ~url ~md5 =
  let output = OpambinGlobals.opambin_switch_temp_dir () // md5 in
  OpambinMisc.call [| "curl" ;
          "--write-out" ; "%{http_code}\\n" ;
          "--retry" ; "3" ;
          "--retry-delay" ; "2" ;
          "--user-agent" ; "opam-bin/2.0.5" ;
          "-L" ;
          "-o" ; output ;
          url
       |];
  Some output

let check_cached_binary_archive ~version ~repo ~package =
  OpambinMisc.global_log "found binary package in repo %s" repo;
  let package_dir = repo // "packages" // version // package in
  let src = ref None in
  let md5 = ref None in
  let opam = OpamParser.file ( package_dir // "opam" ) in
  List.iter (function
      | Section ( _ , { section_kind = "url" ; section_items ; _ } ) ->
        List.iter (function
              Variable ( _, "src", String ( _ , v )) -> src := Some v
            | Variable ( _, "checksum",
                         List ( _, [ String ( _, v ) ] )) ->
              assert ( EzString.starts_with v ~prefix:"md5=" );
              let len = String.length v in
              md5 := Some ( String.sub v 4 (len-4) )
            | _ -> ()
          ) section_items
      | _ -> ()
    ) opam.file_contents ;
  let binary_archive =
    match !md5 with
    | None ->
      OpambinMisc.global_log "url.checksum.md5 not found";
      None
    | Some md5 ->
      match find_archive_in_cache ~repo ~md5 with
      | Some binary_archive ->
        Some binary_archive
      | None ->
        match !src with
        | None ->
          Printf.eprintf "error: url.src not found\n%!";
          exit 2
        | Some url ->
          match wget ~url ~md5 with
          | None ->
            Printf.eprintf "Error: could not download archive at %S\n%!" url;
            exit 2
          | Some binary_archive ->
            let digest = Digest.file binary_archive in
            assert ( Digest.to_hex digest = md5 );
            let cache_dir =
              OpambinGlobals.opam_cache_dir //
              "md5" // String.sub md5 0 2 in
            let cached_file = cache_dir // md5 in
            Sys.rename binary_archive cached_file ;
            Some cached_file
  in
  EzFile.make_dir OpambinGlobals.marker_cached ;
  Unix.chdir OpambinGlobals.marker_cached ;
  let package_files = package_dir // "files" in
  let s = EzFile.read_file
      ( package_files // OpambinGlobals.package_version ) in
  EzFile.write_file OpambinGlobals.package_version s ;
  begin
    match EzFile.read_file
            ( package_files // OpambinGlobals.package_config ) with
    | exception _ -> ()
    | s ->
      EzFile.write_file OpambinGlobals.package_config s
  end;
  begin
    match binary_archive with
    | None -> ()
    | Some binary_archive ->
      OpambinMisc.call [| "tar" ; "zxf" ; binary_archive |] ;
  end;
  true

let cached_binary_archive ~name ~version ~package_uid ~depends =
  let ( source_md5, _depends, _dependset, missing_versions ) =
    OpambinCommandPostInstall.compute_hash
      ~name ~version ~package_uid ~depends in
  if missing_versions <> [] then
    false
  else
    let version_prefix = Printf.sprintf "%s.%s+bin+%s+"
        name version source_md5 in
    if OpambinMisc.iter_repos (fun ~repo ~package ~version ->
        if EzString.starts_with version ~prefix:version_prefix then begin
          check_cached_binary_archive ~package ~repo ~version
        end else
          false
      ) then
      true
    else begin
      OpambinMisc.global_log "Could not find cached binary package %s"
        version_prefix ;
      false
      end

let action args =
  OpambinMisc.global_log "CMD: %s"
    ( String.concat "\n    " ( cmd_name :: args) ) ;
  match args with
  | name :: version :: package_uid :: depends :: [] ->
    if not !!OpambinConfig.enabled
    || not !!OpambinConfig.cache_enabled
    || OpambinMisc.not_this_switch () then begin
      OpambinMisc.global_log "cache is disabled";
      EzFile.write_file OpambinGlobals.marker_source
        "cache is disabled";
    end else
    if Sys.file_exists OpambinGlobals.marker_source then begin
      OpambinMisc.global_log "%s should not already exist!"
        OpambinGlobals.marker_source;
      exit 2
    end else
    if Sys.file_exists OpambinGlobals.marker_cached then begin
      OpambinMisc.global_log "%s should not already exist!"
        OpambinGlobals.marker_cached;
      exit 2
    end else
    if Sys.file_exists OpambinGlobals.package_version then begin
      OpambinMisc.global_log "already a binary package";
      EzFile.write_file OpambinGlobals.marker_source
        "already a binary package";
    end else
    if cached_binary_archive ~name ~version ~package_uid ~depends then begin
      OpambinMisc.global_log "found a binary archive in cache";
      (* this should have created a marker_cached/ directory *)
    end
    else begin
      OpambinMisc.global_log "no binary archive found.";
      EzFile.write_file OpambinGlobals.marker_source "no binary archive found";
    end
  | _ ->
    Printf.eprintf
      "Unexpected args: usage is '%s %s name version package_uid depends cmd...'\n%!" OpambinGlobals.command cmd_name ;
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
    cmd_doc = "(opam hook) Backup the sources before building the package";
  }
