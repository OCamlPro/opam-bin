
Commands
========

You can use :code:`opam-bin` to list all available commands, and
:code:`opam-bin COMMAND --help` for usage of a specific command.

opam-bin clean
--------------
clear all packages and archives from the cache and store

opam-bin config
---------------
configure options

opam-bin help
-------------
display help about opam-bin and opam-bin commands

opam-bin install
----------------
install in opam

opam-bin list
-------------
List binary packages created on this computer

opam-bin push
-------------
push binary packages to the remote server

opam-bin search
---------------
Search binary packages

opam-bin uninstall
------------------
un-install from opam config

OPAM Hooks
----------

* opam-bin pre-build:
  Backup the sources before building the package

* opam-bin wrap-build:
  Exec or not build commands

* opam-bin pre-install:
  Install cached binary archives if available

* opam-bin wrap-install
  Exec or not install commands

* opam-bin pre-remove:
  Remove binary install artefacts

