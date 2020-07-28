
Basic Concepts
==============

:code:`opam-bin` is a simple framework to use :code:`opam` with binary packages.
The framework is composed of:

* A set of repositories containing binary packages. These repositories
  will only work for people using the same distribution on the same
  architecture. You will need to select carefully the right one if
  you want to use them. These repositories are provided by external
  contributors.

* A source repository containing relocatable packages. Relocatable
  packages are needed because binary packages will be installed in
  different directories by different users. The repository is
  available here:
  `https://github.com/ocamlpro/opam-repository-relocatable <https://github.com/ocamlpro/opam-repository-relocatable>`__

* A tool called :code:`opam-bin` to create and use binary packages, available here:
  `https://github.com/ocamlpro/opam-bin <https://github.com/ocamlpro/opam-bin>`__

If you only want to use a repository of binary packages and not create
them, you will only need to access one of the binary repositories in
the first item, without the need for :code:`opam-bin`.
If you want to develop with a cache of binary packages, or to create
repositories of binary packages, then you need to install :code:`opam-bin`.

Binary packages
---------------

Binary packages created by :code:`opam-bin` follow the following convention:

* The binary package created from package :code:`$NAME.$VERSION` is called
  :code:`$NAME.$VERSION+bin+$HASH`, where $HASH is a unique hash. This hash
  is used because dependencies between binary packages are strict and
  cannot be changed.
* An alias package called :code:`$NAME+bin.$VERSION` is also generated, pointing
  to :code:`$NAME.$VERSION+bin+$HASH`. You can use it to install
  the corresponding binary package. For example::

    $ opam install ocamlfind+bin

When :code:`opam-bin` is installed and you ask to install a package
:code:`NAME.VERSION`, OPAM may decide to install the source package instead
of the binary package. OPAM will always select the source package if
you have a :code:`"NAME" { = VERSION }` dependencies asking for the package.

HOWEVER, :code:`opam-bin` will detect if there is a corresponding binary
package, and if it is the case, it will install the binary package
instead of compiling the package (:code:`opam` will still show you the build
steps, but these build steps will actually not be executed).

Relocatable packages
--------------------

Binary packages have to be relocatable to be installed in many
different locations. Most OCaml packages are relocatable, but some of
them are not. For example, :code:`ocaml-base-compiler`,
:code:`ocaml-variants`, :code:`ocamlfind`, :code:`ocamlbuild`, etc.
If you want to create binary packages, you should only use relocatable
packages.

For this reason, we provide a specific :code:`opam` repository
containing modified versions of these packages.  This repository is
available in the project:

`https://github.com/OCamlPro/opam-repository-relocatable/ <https://github.com/OCamlPro/opam-repository-relocatable/>`__

It contains a fork of the official :code:`opam` repository, where
packages known as non-relocatable have been removed, and replaced
with some relocatable versions (in the :code:`packages/relocatable/`
directory).

Currently, it contains the following modified packages:

* apron.20160125/
* menhir.20181113/
* mlgmpidl.1.2.9/
* ocaml-base-compiler.4.07.1/
* ocaml-base-compiler.4.09.1/
* ocamlbuild.0.12.1/
* ocaml-config.1/
* ocamlfind.1.8.0/
* ocamlfind.1.8.1/
* ocaml-variants.4.09.1+flambda/

File Structure
--------------

:code:`opam-bin` creates the following file structure in the
:code:`$HOME/.opam/` directory (or :code:`OPAMROOT`):

* :code:`~/.opam/`
  
  * :code:`plugins/opam-bin/`
    
    * :code:`opam-bin.exe` This file is the executable of
      :code:`opam-bin` used in :code:`opam` wrappers.
    * :code:`opam-bin.log` This file is an internal log of
      :code:`opam-bin` used for debugging its behavior.
    * :code:`cache/` This directory contains a cache of the archives
      of the binary packages created locally. It is necessary as the
      URLs in the :code:`opam` files are not correct before the
      archives have been uploaded to their final location.
    * :code:`store/` This directory contains the files that have to be
      published to share binary packages between users/computers.

      * :code:`archives/` This directory contains all the archives of
        the binary packages that have been created locally.
      * :code:`repo/` This directory contains an :code:`opam`
        repository that exposes the binary packages locally
        created. It is used locally by :code:`opam`, and can be shared
        with other users/computers.

  * :code:`SWITCH/`

    * :code:`etc/opam-bin/packages/` This directory contains, for every
      binary package that has been installed or built in the switch, its
      binary version. 
