(lang dune 2.0)
(name opam-bin)
(allow_approximate_merlin)

(generate_opam_files true)

(source (github ocamlpro/opam-bin))
(license GPL-3.0-or-later)
(authors
 "Fabrice Le Fessant <fabrice.le_fessant@ocamlpro.com>")
(maintainers "Fabrice Le Fessant <fabrice.le_fessant@ocamlpro.com>")

(package
 (name opam-bin)
 (synopsis "Cache binary files locally or remotely")
 (documentation "https://ocamlpro.github.io/opam-bin/doc")
 (depends
  (ocplib-json-typed (>= 0.7.0))
  (ezjsonm (>= 1.0.0))
  (ez-cmdliner (>= 0.1.0))
  (ez-config (>= 0.1.0))
  (re (>= 1.0))
  (opam-file-format (>= 0.0))
  )
  )
