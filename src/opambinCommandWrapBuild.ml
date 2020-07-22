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
open EzConfig.OP
open OpamParserTypes

(*
TODO:
* Check if the archive already exists
  * if 'bin-package.version' exists, we are in a binary archive,
      execute all commands.
  * otherwise, check if a binary archive exists.
     If no, create an empty
       `bin-package.version` file to force execution of all commands.
     If yes, create a directory package.cached/ containing that archive,
       bin-package.version and bin-package.config.
     In wrap-install, perform the installation of the archive.
*)

let cmd_name = "wrap-build"

let cache_file ~cache ~md5 =
  cache // "md5" // String.sub md5 0 2 // md5

let check_cache_file ~cache ~md5 =
  let file = cache_file ~cache ~md5 in
  if Sys.file_exists file then Some file else None

let find_archive_in_cache ~repo ~md5 =
  match check_cache_file ~cache:OpambinGlobals.opam_cache_dir ~md5 with
  | Some file -> Some file
  | None ->
    ignore repo;
    (*
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

let wget _src =
  assert false
(*
+ /usr/bin/curl "--write-out" "%{http_code}\\n" "--retry" "3" "--retry-delay" "2" "--user-agent" "opam/2.0.5" "-L" "-o" "/home/lefessan/.opam/test_bin/.opam-switch/sources/irmin.2.1.0/irmin-2.1.0.tbz.part" "https://github.com/mirage/irmin/releases/download/2.1.0/irmin-2.1.0.tbz"
*)

let check_cached_binary_archive ~name:_ ~repo ~package =
  let package_dir = repo // package in
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
  match !md5 with
  | None ->
    Printf.eprintf "error: url.checksum.md5 not found\n%!";
    exit 2
  | Some md5 ->
    let _binary_archive =
      match find_archive_in_cache ~repo ~md5 with
      | Some binary_archive -> binary_archive
      | None ->
        match !src with
        | None ->
          Printf.eprintf "error: url.src not found\n%!";
          exit 2
        | Some src ->
          match wget src with
          | None ->
            Printf.eprintf "Error: could not download archive at %S\n%!" src;
            exit 2
          | Some binary_archive ->
            let digest = Digest.file binary_archive in
            assert ( Digest.to_hex digest = md5 );
            binary_archive
    in
    assert false

let cached_binary_archive ~name ~version ~package_uid ~depends =
  let ( source_md5, _depends, _dependset, missing_versions ) =
    OpambinCommandPostInstall.compute_hash
      ~name ~version ~package_uid ~depends in
  if missing_versions <> [] then
    None
  else
    let repos = try
        Sys.readdir OpambinGlobals.opam_repo_dir
      with _ -> [||]
    in
    (* TODO: use "repositories" in .opam/config *)
    let repos = Array.to_list @@
      Array.map (fun file ->
          OpambinGlobals.opam_repo_dir // file) repos
    in
    let repos = OpambinGlobals.opambin_store_repo_dir :: repos in
    OpambinMisc.global_log "Seaching cached binary package in:\n  %s"
      ( String.concat "\n  " repos);
    let package_prefix = Printf.sprintf "%s.%s+bin+%s+"
        name version source_md5 in
    let rec iter_repos repos =
      match repos with
      | [] ->
        OpambinMisc.global_log "Could not find cached binary package %s"
          package_prefix;
        None
      | repo :: repos ->
        let package_dir = repo // "packages" // name in
        match Sys.readdir package_dir with
        | exception _ -> iter_repos repos
        | files ->
          let files = Array.to_list files in
          iter_files repo files repos
    and iter_files repo files repos =
      match files with
      | [] -> iter_repos repos
      | package :: files ->
        if EzString.starts_with package ~prefix:package_prefix then
          check_cached_binary_archive ~name ~repo ~package
        else
          iter_files repo files repos
    in
    iter_repos repos

let action args =
  OpambinMisc.global_log "CMD: %s\n%!"
    ( String.concat "\n    " ( cmd_name :: args) ) ;
  OpambinMisc.make_cache_dir ();
  match args with
  | name :: version :: package_uid :: depends :: cmd ->
    let call_command =
      if not !!OpambinConfig.cache_enabled then true else
      if Sys.file_exists OpambinGlobals.package_version then true else
      if Sys.file_exists OpambinGlobals.package_cached then false else
        match cached_binary_archive ~name ~version ~package_uid ~depends with
        | None ->
          EzFile.write_file OpambinGlobals.package_version "force build";
          true
        | Some file_name ->
          EzFile.write_file OpambinGlobals.package_cached file_name;
          assert false
    in
    if call_command then
      OpambinMisc.call (Array.of_list cmd)
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
  cmd_doc = "(opam hook) Exec or not build commands";
}
