(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let config_filename = OpambinGlobals.config_file
let config = EzConfig.create_config_file
    ( EzFile.Abstract.of_string config_filename )

let () =
  try
    EzConfig.load config
  with _ ->
    Printf.eprintf "No configuration file.\n%!"

let save () =
  EzConfig.save_with_help config;
  Printf.eprintf "%s config saved in %s .\n%!"
    OpambinGlobals.command OpambinGlobals.config_file

let base_url = EzConfig.create_option config
    [ "base_url" ]
    [
      "The `base url` of the website where the archives folder will be stored";
      "if you want to share your binary packages.";
      Printf.sprintf
        "Locally, the archives folder is stored in $HOME/.opam/%s/store ."
        OpambinGlobals.command ;
    ]
    EzConfig.string_option
    "/change-this-option"

let rsync_url = EzConfig.create_option config
    [ "rsync_url" ]
    [
      Printf.sprintf
        "This is the argument passed to rsync when calling `%s push`."
        OpambinGlobals.command ;
      "The directory should exist on the remote server.";
    ]
    (EzConfig.option_option EzConfig.string_option)
    None

let create_enabled = EzConfig.create_option config
    [ "create_enabled" ]
    [ "Whether we produce binary packages after installing source packages" ]
    EzConfig.bool_option
    true

let cache_enabled = EzConfig.create_option config
    [ "cache_enabled" ]
    [ "Whether we use a binary package when available instead of building";
      "the corresponding source package."
    ]
    EzConfig.bool_option
    false (* Not yet ready *)
