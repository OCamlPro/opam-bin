
## Hooks

* pre-session

* pre-build
* wrap-build
* pre-install
* wrap-install
* post-install

* pre-remove
* wrap-remove

* post-session

## File map at work

cache/: cache of binary archives
  md5/
    <AB>/
      <ABHHHHH*>
config : configuration
config.old : previous configuration
opam-bin.exe* : executable
opam-bin.info : summary log file
opam-bin.log : pure log file
patches/ : checkout of patches
  patches/
    <PACKAGE>/
      <VERSION>.patch
share/: sharing of files by hardlinks to this directory
 <A>/
   <B>/
     <C>/
       <ABCHHH*>.share
store/
  archive/
    <PACKAGE>+bin+<CHECKSUM>-bin.tar.gz
  repo/
    repo
    version
    packages/
      <PACKAGE>/
        <PACKAGE>.<VERSION>+bin+<HASH>/
	  opam


## Sources files

globals.ml
config.ml
misc.ml
share.ml
versionCompare.ml
version.mlt

commandClean.ml
commandConfig.ml
commandInfo.ml
commandInstall.ml
commandList.ml
commandPostInstall.ml
commandPostSession.ml
commandPreBuild.ml
commandPreInstall.ml
commandPreRemove.ml
commandPreSession.ml
commandPull.ml
commandPush.ml
commandSearch.ml
commandShare.ml
commandUninstall.ml
commandWrapBuild.ml
commandWrapInstall.ml

main.ml
