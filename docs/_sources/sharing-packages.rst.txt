
Sharing Packages
================

Private Sharing
---------------

:code:`opam-bin` provides a simple way to share the binary packages
with other users and computers: it automatically creates an
:code:`opam` repository with the binary packages that are created. The
repository is located in :code:`~/.opam/_opam-bin/store/repo` and the
corresponding archives are in
:code:`~/.opam/_opam-bin/store/archives`.

By sharing the directory :code:`~/.opam/_opam-bin/store/` with other
computers, you can simply reuse your binary packages. Here is such an
example session::

  opam-bin clean
  opam switch create 4.07.1
  opam install alt-ergo -y
  rsync -auv --delete ~/.opam/_opam-bin/store other-computer:/tmp/
  rsync -auv --delete ~/.opam/_opam-bin/cache other-computer:/tmp/
  ssh other-computer
  $ opam remote set-url default --all --set-default file:///tmp/store/repo
  $ opam switch create --empty
  $ opam install alt-ergo+bin

Note that we also add to share :code:`~/.opam/_opam-bin/cache` on the
other computer, because without specific configuration, the :code:`url
{ src: }` field in generated :code:`opam` files will not provide the
correct path to the archive. Fortunately, :code:`opam` is able to use
the cache to find the archives.

Public Sharing
--------------

If you want to share your binary packages on a public repository, it
requires almost no additional work: you only need to specify the URL
of your web-server in an option::

  opam-bin config --base-url http://my.server.com/opam-bin

This command will not only change the configuration for newly created
packages, but also modify already generated binary packages to use
this URL for the :code:`url { src: }` field.

After this command, the repository is expected to be copied in
:code:`http://my.server.com/opam-bin/repo`, while archives are
expected to be available in
:code:`http://my.server.com/opam-bin/archives`.

:code:`opam-bin` also provides a simple way to copy the repository on
the remote server. You first need to specify where the files should be
copied, and then use the :code:`opam-bin push` command::

  opam-bin config --rsync-url my.server.com:/var/www/opam-bin
  opam-bin push



