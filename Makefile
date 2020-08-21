all:
	dune build
	cp -f _build/default/main/opambin.exe opam-bin

build-deps:
	opam install --deps-only .

init:
	git submodule init
	git submodule update

html:
	sphinx-build rtd docs

view:
	xdg-open file://$$(pwd)/docs/index.html
