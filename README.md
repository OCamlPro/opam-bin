Opam-Binary
===========

opam-binary is a simple framework to use `opam` with binary packages.
The framework is composed of:

* A set of repositories containing binary packages. These repositories
  will only work for people using the same distribution on the same
  architecture. You will need to select carefully the right one if
  you want to use them. These repositories are provided by external
  contributors.

* A source repository containing relocatable packages. Relocatable
  packages are needed because binary packages will be installed in
  different directories by different users. The repository is
  available here: https://github.com/ocamlpro/opam-repository-relocatable
  Check the README.md file there for more information.

* A tool called `opam-bin` to create binary packages, available here:
  https://github.com/ocamlpro/opam-bin

If you only want to use binary packages and not create them, you will
only need to access the binary repositories in the first item.

Author: Fabrice LE FESSANT <fabrice.le_fessant@origin-labs.com>
  OCamlPro SAS & Origin Labs SAS

Binary packages
---------------

Binary packages created by `opam-bin` follow the following convention:

* The binary package created from package $NAME.$VERSION is called
  $NAME.$VERSION+bin+$HASH, where $HASH is a unique hash. This hash
  is used because dependencies between binary packages are strict and
  cannot be changed.
* An alias package called $NAME+bin.$VERSION is also generated, pointing
  to $NAME.$VERSION+bin+$HASH. You can use it to install
  the corresponding binary package. For example:
  ```
  $ opam install ocamlfind+bin
  ```

Creating binary packages
------------------------

First, add the repository of relocatable binaries:

```
$ opam repo add relocatable --all --set-default https://github.com/OCamlPro/opam-repository-relocatable --rank 1
```

```
$ opam repo remove default --all --set-default
```

When installing packages, you should check that, if a version of the package
is available in the relocatable repository, it is the one selected by OPAM.

You will also need the `opam-bin` tool:
```
$ opam install opam-bin
```

Now, to configure `opam` to use `opam-bin`, just use:

```
$ opam-bin install
```

After theses steps, `opam-bin` will be used everytime you install a
package in opam. `opam-bin` will create binary archives from source
archive in $HOME/.opam/opam-bin/store/`, and use them if you want to
reinstall a package.

Let's try:
```
$ opam switch create 4.07.1
```
Once done, you should find something like this:
```
$ ls ~/.opam/opam-bin/store/archives
base-bigarray.base+bin+86eb2f6a-bin.tar.gz
base-threads.base+bin+c6706ce5-bin.tar.gz
base-unix.base+bin+5d163660-bin.tar.gz
ocaml.4.07.1+bin+f58f0d4d-bin.tar.gz
ocaml-base-compiler.4.07.1+bin+4b29d581-bin.tar.gz
ocaml-config.1+bin+a54c7990-bin.tar.gz
```

We can try these packages in another switch:
```
$ opam update
$ opam switch list-available
# Listing available compilers from repositories: local-bin, default
# Name              # Version           # Synopsis
ocaml-base-compiler 4.07.1+bin+4b29d581 Official release 4.10.0
$ opam switch create 4.07.1+bin+4b29d581
```

If you want to share the binary packages, you will want to copy
`$HOME/.opam/opam-bin/store` on a website. The `opam` files created by
`opam-bin` should contain the correct URL to that website. For example,
you can use:
```
opam-bin config --base-url https://www.my-opam-site.io/debian9
```

and then rsync your binary packages there:
```
cd $HOME/.opam/opam-bin/store
rsync -auv . webmaster@www.my-opam-site.io:/var/www/debian9/.
```
After these steps, the OPAM repository of binary packages will
be available at:
```
https://www.my-opam-site.io/debian9/repo
```
and the archives at:
```
https://www.my-opam-site.io/debian9/archives
```

To stop using `opam-bin`, use:

```
opam-bin uninstall
```

Or you can just disable it:
```
opam-bin config --disable
```
and later re-enable it:
```
opam-bin config --enable
```

Dependencies
------------

`opam-bin` expects GNU tar to be installed and available in the PATH.
It requires the HOME environment variable to localize opam files.
