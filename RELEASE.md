How to release a new version
============================

Suppose you want to releave version 0.10.0:

* edit src/opambinGlobals.ml and change `version` to "0.10.0"
* commit:
```
git commit -a -m "version 0.10.0"
```
* push:
```
git push
```
* Go to github.com and merge
* Draft a new release:
   v0.10.0
   Version 0.10.0
* Go in opam-bin-repository
  ./scripts/new-opam-bin.sh 0.10.0
* Commit and push
  git commit -a -m "add opam-bin.0.10.0"
  git push
* You may also want to create a new binary archive for this version
