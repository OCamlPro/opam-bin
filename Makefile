all:
	dune build
	cp -f _build/default/src/opambin.exe opam-bin

build-deps:
	opam install --deps-only .

init:
	git submodule init
	git submodule update
