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

let need_saving = ref false
let need_refactoring = ref false

let refactor () =
  Printf.eprintf "Refactoring...\n%!";
  let open OpamParserTypes in
  let refactor = function
    | Section (pos, s) ->
      let s =
        if s.section_kind = "url" then
          { s with section_items = List.map (function
                  Variable (_, "src", String (_, url)) ->
                  let archive = Filename.basename url in
                  let url = !!OpambinConfig.base_url //
                            "archives" // archive in
                  Variable (pos, "src", String (pos, url))
                | v -> v) s.section_items }
        else s
      in
      Section (pos, s)
    | v -> v
  in
  let f ~basename:_ ~localpath:_ ~file =
    let opam = OpamParser.file file in
    let opam = { opam with
                 file_contents = List.map refactor opam.file_contents }
    in
    EzFile.write_file file (OpamPrinter.opamfile opam)
  in
  let select = EzFile.select ~deep:true ~glob:"opam" () in
  EzFile.iter_dir ~select f OpambinGlobals.opambin_store_repo_packages_dir

let action () =
  Printf.eprintf "%s\n%!" OpambinGlobals.about ;

  if !need_saving then begin
    EzFile.make_dir OpambinGlobals.opambin_dir ;
    OpambinConfig.save ();
    if !need_refactoring then refactor ();
  end else begin
    let open EzConfig.LowLevel in
    Printf.printf "Current options (from %s):\n"
      OpambinConfig.config_filename;
    let options = simple_options "" OpambinConfig.config in
    List.iter (fun o ->
        Printf.printf "  %s : %s\n"
          ( String.concat "." o.option_name )
          o.option_value ;
      ) options ;
    Printf.printf "  switches : %s\n"
      (String.concat "  " !!OpambinConfig.switches );
    Printf.printf "  protected_switches : %s\n"
      (String.concat "  " !!OpambinConfig.protected_switches );
  end;
  ()

let modify_list_of_switches option s =
  let add s =
    option =:= !! OpambinConfig.switches @ [ s ]
  in
  let remove s =
    OpambinConfig.switches =:=
    List.filter ( (<>) s ) !!OpambinConfig.switches
  in
  List.iter (function
      | "" -> ()
      | "-" -> OpambinConfig.switches =:= []
      | s ->
        let c = s.[0] in
        let len = String.length s in
        match c with
        | '+' -> add ( String.sub s 1 ( len - 1 ))
        | '-' -> remove ( String.sub s 1 ( len - 1 ))
        | _ -> add s
    ) (EzString.split s ',')

let cmd = {
  cmd_name = "config" ;
  cmd_action = action ;
  cmd_args = [

    [ "base-url" ], Arg.String (fun s ->
        OpambinConfig.base_url =:= s;
        need_refactoring := true;
        need_saving := true;
      ),
    Ezcmd.info "URL where the archives folder is available";

    [ "rsync-url" ], Arg.String (fun s ->
        OpambinConfig.rsync_url =:= ( match s with
            | "" | "-" -> None
            | _ -> Some s );
        need_saving := true;
      ),
    Ezcmd.info @@
    Printf.sprintf
      "target for rsync to push new binary packages with `%s push`"
      OpambinGlobals.command;

    [ "reloc-repo-url" ], Arg.String (fun s ->
        OpambinConfig.reloc_repo_url =:= s;
        need_saving := true;
      ),
    Ezcmd.info @@
    "target for the default repo containing relocatable packages" ;

    [ "enable-cache" ], Arg.Unit (fun () ->
        OpambinConfig.cache_enabled =:= true ;
        need_saving := true;
      ),
    Ezcmd.info
      "use binary packages when available instead of building source packages";

    [ "disable-cache" ], Arg.Unit (fun () ->
        OpambinConfig.cache_enabled =:= false ;
        need_saving := true ;
      ),
    Ezcmd.info
      "opposite of --enable-cache";

    [ "enable-create" ], Arg.Unit (fun () ->
        OpambinConfig.create_enabled =:= true ;
        need_saving := true;
      ),
    Ezcmd.info
      "create a binary package after building a source package";

    [ "disable-create" ], Arg.Unit (fun () ->
        OpambinConfig.cache_enabled =:= false ;
        need_saving := true;
      ),
    Ezcmd.info
      "opposite of --enable-create";

    [ "enable" ], Arg.Unit (fun () ->
        OpambinConfig.enabled =:= true ;
        need_saving := true;
      ),
    Ezcmd.info
      "enable binary packages";

    [ "disable" ], Arg.Unit (fun () ->
        OpambinConfig.enabled =:= false ;
        need_saving := true;
      ),
    Ezcmd.info
      "disable binary packages";

    [ "all-switches" ], Arg.Unit (fun () ->
        OpambinConfig.all_switches =:= true ;
        need_saving := true ;
      ),
    Ezcmd.info "Activate on all switches, except protected switches";

    [ "not-all-switches" ], Arg.Unit (fun () ->
        OpambinConfig.all_switches =:= false ;
        need_saving := true ),
    Ezcmd.info "Activate only on switches specified with --switches";

    [ "switches" ], Arg.String (fun s ->
        modify_list_of_switches OpambinConfig.switches s ;
        need_saving := true;
      ),
    Ezcmd.info "With --not-all-switches, specify which switches \
                (comma-separated) should create/use binary \
                packages. '-' means none, 'SWITCH' or '+SWITCH' means \
                add SWITCH to the list, `-SWITCH` means remove SWITCH \
                from the list. A glob regexp can also be used for \
                SWITCH.";

    [ "protected-switches" ], Arg.String (fun s ->
        modify_list_of_switches OpambinConfig.protected_switches s ;
        need_saving := true;
      ),
    Ezcmd.info "With --all-switches, specify which switches \
                (comma-separated) should NOT create/use binary \
                packages. '-' means none, 'SWITCH' or '+SWITCH' means \
                add SWITCH to the list, `-SWITCH` means remove SWITCH \
                from the list. A glob regexp can also be used for \
                SWITCH.";

  ];
  cmd_man = [];
  cmd_doc = "configure options";
}
