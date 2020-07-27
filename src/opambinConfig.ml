(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzConfig.OP

let config_filename = OpambinGlobals.config_file
let config = EzConfig.create_config_file
    ( EzFile.Abstract.of_string config_filename )

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

let reloc_repo_url = EzConfig.create_option config
    [ "reloc_repo_url" ]
    [
      "The URL of the relocatable repository that will be set as 'default'"
    ]
    EzConfig.string_option
    "git@github.com:OCamlPro/opam-repository-relocatable"

let enabled = EzConfig.create_option config
    [ "enabled" ]
    [ "Whether we do something or not" ]
    EzConfig.bool_option
    true

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
    true

let all_switches = EzConfig.create_option config
    [ "all_switches" ]
    [ "Whether we use a binary package for all switches. The config variable" ;
      "`switches` will only be used if this variable is false";
    ]
    EzConfig.bool_option
    true

let switches = EzConfig.create_option config
    [ "switches" ]
    [ "This list of switches (or regexp such as '*bin') for which" ;
      "creating/caching binary packages should be used" ]
    ( EzConfig.list_option EzConfig.string_option )
    []

let protected_switches = EzConfig.create_option config
    [ "protected_switches" ]
    [ "This list of switches (or regexp such as '*bin') for which" ;
      "creating/caching binary packages should NOT be used" ]
    ( EzConfig.list_option EzConfig.string_option )
    []

let current_version = 1
(* This option should be used in the future to automatically upgrade
   configuration *)
let version = EzConfig.create_option config
    [ "version" ]
    [ "Version of the configuration file" ]
    EzConfig.int_option
    current_version

let () =
  try
    EzConfig.load config
  with _ ->
    Printf.eprintf "No configuration file.\n%!"

let () =
  if !!version < current_version then begin
    version =:= current_version ;
    save ()
  end
