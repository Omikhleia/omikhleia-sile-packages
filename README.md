# omikhleia-sile-packages
Packages and classes for the SILE typesetter

I wanted to give a try to the [SILE](https://github.com/sile-typesetter/sile) typesetting system. If I had to typeset a book, however, the current version of SILE (0.10.15 at the initial time of writing) lacks many supporting packages for the sort of things I usually write. Here is my attempt at providing packages or classes that would fit my needs.

Some of the things I may (or not) provide here:
- [X] epigraphs

  The **epigraph** package is inspired (loosely) from the LaTeX package by the same name, with a minimal set of useful features.

- [X] Common shorthands and abbreviations: **abbr** package. This package defines a few shorthands
  and abbreviations that its author often uses in articles or book chapters
- [X] Native superscripts and subscripts: **textsubsuper** package.
- [X] Some printer's ornaments: **couyards** package.
- [ ] Quotations - the default "quote" package in SILE doesn't do the job for me.
- [X] Labels and reference: **omirefs** package.
- [ ] Proper page masters a.k.a an extended book template for print.
- [ ] Side notes (a.k.a margin notes).
- [ ] Figures (with captions, etc.).
- [X] Colophons - circle-shape paragraphs with an ornamental decoration.

  The **colophon** package works but requires a specific version of the line breaking algorithm
  not provided here (submitted for core inclusion in SILE).

- [X] Poetry: **omipoetry** package.

- [X] Paragraph boxes: **parbox** package - as a building block for other more advance
  concepts.

- [X] Tables: **ptable** package - decently complex tables with spanning cells, etc.

- [X] XML TEI dictionaries 

  The **teidict** package and the **teibook** class are intended for processing XML TEI P4 dictionaries.
  They supports a decent subset of the [TEI P4](https://tei-c.org/Vault/P4/doc/html/) "Print Dictionaries"
  specification, and define an appropriate layout for such dictionaries (entries on two columns, with
  running page headers, etc.).

- [X] Temporary command redefinition (save and restore): **redefine** package.
- [X] Styles (IN PROGRESS): **styles** package.