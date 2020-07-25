(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let append_text_file file s =
  let oc = open_out_gen [
      Open_creat;
      Open_append ;
      Open_text ;
    ] 0o644 file in
  output_string oc s;
  close_out oc

let date () =
  let tm = Unix.localtime (Unix.gettimeofday ()) in
  Printf.sprintf "%4d/%02d/%02d:%02d:%02d:%02d"
    (1900 + tm.tm_year)
    (1+tm.tm_mon)
    tm.tm_mday
    tm.tm_hour
    tm.tm_min
    tm.tm_sec

let log file fmt =
  Printf.kprintf (fun s ->
      append_text_file file
        (Printf.sprintf "%s: %s\n" (date()) s)) fmt

let global_log fmt =
  log OpambinGlobals.opambin_log fmt

let make_cache_dir () =
  EzFile.make_dir ~p:true OpambinGlobals.opambin_cache_dir

let call ?(stdout = Unix.stdout) args =
  global_log "calling '%s'"
    (String.concat "' '" (Array.to_list args));
  let pid = Unix.create_process args.(0) args
      Unix.stdin stdout Unix.stderr in
  let rec iter () =
    match Unix.waitpid [ ] pid with
    | exception (Unix.Unix_error (EINTR, _, _)) -> iter ()
    | _pid, status ->
      match status with
      | WEXITED 0 -> ()
      | _ ->
        Printf.kprintf failwith "Command '%s' exited with error code %s"
          (String.concat " " (Array.to_list args))
          (match status with
           | WEXITED n -> string_of_int n
           | WSIGNALED n -> Printf.sprintf "SIGNAL %d" n
           | WSTOPPED n -> Printf.sprintf "STOPPED %d" n
          )
  in
  iter ()

let tar_zcf ?prefix archive files =
  let temp_archive = archive ^ ".tmp" in
  begin
    match files with
    | [] ->
      (* an empty tar achive is this... *)
      EzFile.write_file temp_archive (String.make 10240 '\000');
    | _ ->
      let args = files in
      let args =
        match prefix with
        | None -> args
        | Some prefix ->
          "--transform"  ::
          Printf.sprintf "s|^|%s/|S" prefix ::
          args
      in
      let args =
        "--mtime=2020/07/13" ::
        "--group=user:1000" ::
        "--owner=user:1000" ::
        args
      in
      let args =  "-cf" :: temp_archive :: args in
      call @@ Array.of_list ( "tar" :: args )
  end;
  call [| "gzip" ; "-n"; temp_archive |];
  Sys.rename ( temp_archive ^ ".gz" ) archive


let backup_rotation =
  [ ".8", ".9";
    ".7", ".8";
    ".6", ".7";
    ".5", ".6";
    ".4", ".5";
    ".3", ".4";
    ".2", ".3";
    ".1", ".2";
    "", ".1";
  ]

let restore_rotation =
  List.rev (List.map (fun (x,y) -> (y,x)) backup_rotation)

let rotate file rotation =
  List.iter (fun (ext1, ext2) ->
      let file1 = file ^ ext1 in
      let file2 = file ^ ext2 in
      if FileString.exists file1 then
        let s = FileString.read_file file1 in
        FileString.write_file file2 s;
    ) rotation

let backup_opam_config_done = ref false
let backup_opam_config () =
  if not !backup_opam_config_done then begin
    rotate OpambinGlobals.opam_config_file backup_rotation;
    Printf.eprintf "%s backuped under %s\n%!"
      OpambinGlobals.opam_config_file
      OpambinGlobals.opam_config_file_backup;
    backup_opam_config_done := true;
  end

let restore_opam_config () =
  rotate OpambinGlobals.opam_config_file restore_rotation;
  Printf.eprintf "%s restored from %s\n%!"
    OpambinGlobals.opam_config_file
    OpambinGlobals.opam_config_file_backup

let change_opam_config f =
  let { OpamParserTypes.file_contents ; _ } =
    OpamParser.file OpambinGlobals.opam_config_file in
  match f file_contents with
  | None -> ()
  | Some file_contents ->
    backup_opam_config ();
    let s = OpamPrinter.opamfile
        { file_name = ""; file_contents } in
    EzFile.write_file OpambinGlobals.opam_config_file s;
    Printf.eprintf "%s backuped and modified\n%!"
      OpambinGlobals.opam_config_file

let opam_variable name fmt =
  Printf.kprintf (fun s ->
      OpamParserTypes.Variable ( ("",0,0), name,
                                 OpamParser.value_from_string s ""))
    fmt

let opam_section ?name kind list =
  OpamParserTypes.Section ( ("",0,0),
                            {
                              section_kind = kind ;
                              section_name = name ;
                              section_items = list })
